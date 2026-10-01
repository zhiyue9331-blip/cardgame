extends SceneTree

# Paired seeds and one target policy for both versions; does not alter the live AI.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := int(args[0]) if args.size() > 0 else 6000
	var games := int(args[1]) if args.size() > 1 else 200
	var mode := str(args[2]).to_lower() if args.size() > 2 else "paired"
	var override := str(args[3]).to_lower() if args.size() > 3 else ""
	var only_count := int(args[4]) if args.size() > 4 else 0
	var star_finale_cost2 := override in ["star_finale_cost2", "star_finale=2", "star-final2"]
	var duel_first_draw1 := override in ["duel_first_draw1", "duel-first-draw1", "firstdraw1"]
	var duel_first_draw0 := override in ["duel_first_draw0", "duel-first-draw0", "firstdraw0"]
	var duel_legacy_draw2 := override in ["duel_legacy_draw2", "duel-legacy-draw2", "legacy_draw2"]
	if mode == "current":
		var counts := [2, 3, 4] if only_count <= 0 else [only_count]
		for count in counts:
			var result := run_current_batch(count, first_seed, games, star_finale_cost2, duel_first_draw1, duel_first_draw0, duel_legacy_draw2)
			print(JSON.stringify(result))
			if int(result.get("errors", 0)) > 0 or int(result.get("timeouts", 0)) > 0:
				quit(1)
				return
		quit(0)
		return
	for count in [2, 3, 4]:
		for variant in [false, true]:
			var result := run_batch(count, first_seed, games, variant)
			print(JSON.stringify(result))
			if result.has("error") or result.get("rows", []).any(func(row): return int(row[2]) < 0):
				quit(1)
				return
	quit(0)

static func run_batch(count: int, first_seed: int, games: int, variant: bool) -> Dictionary:
	var ai := AiController.new()
	var rows := []
	for seed_value in range(first_seed, first_seed + games):
		var g := CardRules.new()
		g.start(count, seed_value)
		# Only copied instances are changed, never CardDatabase.CARDS.
		var cards: Array = g.deck.duplicate()
		for p in g.players: cards.append_array(p.hand)
		for card in cards:
			if card.base_id == "forge_blade": card.attack = 1 if variant else 2
			if card.base_id == "echo_focus": card.cost = 1 if variant else 2
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_value ^ 0x175EA
		var first := []
		for p in range(count): first.append("")
		var starter := g.current
		var steps := 0
		while g.winner < 0 and steps < 2400:
			var slot := int(g.pending.get("slot", g.current))
			var action := ai.choose_rules_action(g, slot)
			if action.is_empty():
				g.dispose()
				return {"error":"AI empty", "seed":seed_value, "count":count}
			if g.pending.is_empty() and action.has("target_slot") and int(action.target_slot) != slot:
				var candidates := []
				var min_hp := 99
				for other in g.legal_actions(slot):
					if other.type != action.type or other.get("card_id", "") != action.get("card_id", "") or other.get("options", {}) != action.get("options", {}): continue
					if not other.has("target_slot") or int(other.target_slot) == slot: continue
					var hp := int(g.players[int(other.target_slot)].hp)
					if hp < min_hp:
						min_hp = hp
						candidates.clear()
					if hp == min_hp: candidates.append(other)
				if not candidates.is_empty(): action = candidates[rng.randi_range(0, candidates.size() - 1)]
			var error := g.submit(slot, action)
			if not error.is_empty():
				g.dispose()
				return {"error":error, "seed":seed_value, "count":count}
			for p in range(count):
				if first[p].is_empty() and not g.players[p].main.is_empty():
					first[p] = str(g.players[p].main.get("faction", ""))
					if first[p].is_empty(): first[p] = "中立"
			steps += 1
		rows.append([seed_value, starter, g.winner, g.round_number, steps, first])
		g.dispose()
	return {"count":count, "variant":variant, "rows":rows}

# Current-mode sample: formal card values and formal AiController targeting.
# Unlike the historical paired mode above, this does not rewrite cards or targets.
static func run_current_batch(count: int, first_seed: int, games: int, star_finale_cost2: bool = false, duel_first_draw1: bool = false, duel_first_draw0: bool = false, duel_legacy_draw2: bool = false) -> Dictionary:
	var ai := AiController.new()
	var rows := []
	var rounds_total := 0
	var completed := 0
	var timeouts := 0
	var errors := 0
	var winners := {}
	var first_seat_wins := 0
	var first_elimination_round_total := 0
	var first_elimination_round_samples := 0
	var first_elimination_rounds := {}
	var action_counts := {"draw_two":0, "prepare":0}
	var dogpile_trigger_total := 0
	var first_faction_samples := {}
	var first_faction_wins := {}
	var first_resonance_round_total := {}
	var first_resonance_round_samples := {}
	var never_main_players := 0
	for seed_value in range(first_seed, first_seed + games):
		var g := CardRules.new()
		g.start(count, seed_value)
		if count == 2:
			var first_slot := g.current
			if duel_legacy_draw2:
				# Reproduce the old two-card first-player draw after start.
				for _i in range(2):
					if g.deck.is_empty(): break
					g.players[first_slot].hand.append(g.deck.pop_back())
			elif duel_first_draw1:
				# Benchmark-only one-card alternative under the new production start.
				if not g.deck.is_empty(): g.players[first_slot].hand.append(g.deck.pop_back())
			elif duel_first_draw0:
				# Explicit zero-card alias; current production already implements it.
				pass
		if star_finale_cost2:
			# Only copied card instances are changed; CardDatabase.CARDS stays intact.
			var cards: Array = g.deck.duplicate()
			for p in g.players: cards.append_array(p.hand)
			for card in cards:
				if str(card.get("base_id", "")) == "star_finale": card.cost = 2
		var starter := g.current
		var first_faction := []
		for p in range(count): first_faction.append("")
		var first_resonance_round := []
		for p in range(count): first_resonance_round.append(-1)
		var first_elimination_round := -1
		var steps := 0
		var error_text := ""
		while g.winner < 0 and steps < 2400:
			var slot := int(g.pending.get("slot", g.current))
			var action := ai.choose_rules_action(g, slot)
			if action.is_empty():
				error_text = "AI empty"
				break
			var round_before := g.round_number
			var alive_before := []
			for p in range(count): alive_before.append(g.alive(p))
			error_text = g.submit(slot, action)
			if not error_text.is_empty(): break
			var action_type := str(action.get("type", ""))
			if action_counts.has(action_type): action_counts[action_type] = int(action_counts[action_type]) + 1
			if first_elimination_round < 0:
				for p in range(count):
					if bool(alive_before[p]) and not g.alive(p):
						first_elimination_round = round_before
						break
			for p in range(count):
				if first_faction[p].is_empty() and not g.players[p].main.is_empty():
					first_faction[p] = str(g.players[p].main.get("faction", ""))
					if first_faction[p].is_empty(): first_faction[p] = "中立"
				if first_resonance_round[p] < 0 and not first_faction[p].is_empty() and first_faction[p] != "中立" and g.resonance(p, first_faction[p]) > 0:
					first_resonance_round[p] = round_before
			steps += 1
		if not error_text.is_empty():
			errors += 1
		elif g.winner < 0:
			timeouts += 1
		else:
			completed += 1
			rounds_total += g.round_number
			var winner_key := str(g.winner + 1)
			winners[winner_key] = int(winners.get(winner_key, 0)) + 1
			if g.winner == starter: first_seat_wins += 1
		if first_elimination_round >= 0:
			first_elimination_round_total += first_elimination_round
			first_elimination_round_samples += 1
			var elimination_key := str(first_elimination_round)
			first_elimination_rounds[elimination_key] = int(first_elimination_rounds.get(elimination_key, 0)) + 1
		for log_line in g.logs:
			if "触发集火衰减" in str(log_line): dogpile_trigger_total += 1
		for p in range(count):
			if first_faction[p].is_empty():
				never_main_players += 1
				continue
			first_faction_samples[first_faction[p]] = int(first_faction_samples.get(first_faction[p], 0)) + 1
			if g.winner == p:
				first_faction_wins[first_faction[p]] = int(first_faction_wins.get(first_faction[p], 0)) + 1
			if first_resonance_round[p] >= 0:
				var faction: String = str(first_faction[p])
				first_resonance_round_samples[faction] = int(first_resonance_round_samples.get(faction, 0)) + 1
				first_resonance_round_total[faction] = int(first_resonance_round_total.get(faction, 0)) + first_resonance_round[p]
		rows.append([seed_value, starter, g.winner, g.round_number, steps, first_faction.duplicate()])
		g.dispose()
	var first_resonance_round_avg := {}
	var first_equipped_faction_stats := {}
	for faction in first_faction_samples.keys():
		var resonance_samples := int(first_resonance_round_samples.get(faction, 0))
		var resonance_total := int(first_resonance_round_total.get(faction, 0))
		var resonance_avg := float(resonance_total) / float(resonance_samples) if resonance_samples > 0 else -1.0
		first_resonance_round_avg[faction] = resonance_avg
		first_equipped_faction_stats[faction] = {
			"samples":int(first_faction_samples.get(faction, 0)),
			"wins":int(first_faction_wins.get(faction, 0)),
			"first_resonance_samples":resonance_samples,
			"first_resonance_round_total":resonance_total,
			"first_resonance_round_avg":resonance_avg
		}
	var avg_action_counts := {}
	for action_type in action_counts.keys():
		avg_action_counts[action_type] = float(action_counts[action_type]) / float(completed) if completed > 0 else 0.0
	return {
		"mode":"current",
		"count":count,
		"star_finale_cost2":star_finale_cost2,
		"duel_first_draw1":duel_first_draw1,
		"duel_first_draw0":duel_first_draw0,
		"duel_legacy_draw2":duel_legacy_draw2,
		"games":games,
		"completed":completed,
		"timeouts":timeouts,
		"errors":errors,
		"completion_rate":float(completed) / float(games) if games > 0 else 0.0,
		"avg_rounds":float(rounds_total) / float(completed) if completed > 0 else -1.0,
		"winners":winners,
		"first_seat_wins":first_seat_wins,
		"first_seat_win_rate":float(first_seat_wins) / float(completed) if completed > 0 else 0.0,
		"first_elimination_round_samples":first_elimination_round_samples,
		"first_elimination_round_total":first_elimination_round_total,
		"first_elimination_round_avg":float(first_elimination_round_total) / float(first_elimination_round_samples) if first_elimination_round_samples > 0 else -1.0,
		"first_elimination_rounds":first_elimination_rounds,
		"action_counts":action_counts,
		"avg_action_counts":avg_action_counts,
		"dogpile_trigger_total":dogpile_trigger_total,
		"dogpile_trigger_avg":float(dogpile_trigger_total) / float(completed) if completed > 0 else 0.0,
		"first_equipped_faction_samples":first_faction_samples,
		"first_equipped_faction_wins":first_faction_wins,
		"first_equipped_faction_resonance_samples":first_resonance_round_samples,
		"first_equipped_faction_resonance_round_total":first_resonance_round_total,
		"first_equipped_faction_resonance_round_avg":first_resonance_round_avg,
		"first_equipped_faction_stats":first_equipped_faction_stats,
		"never_main_players":never_main_players,
		"rows":rows
	}
