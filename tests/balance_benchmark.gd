extends SceneTree

# Paired seeds and one target policy for both versions; does not alter the live AI.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := int(args[0]) if args.size() > 0 else 6000
	var games := int(args[1]) if args.size() > 1 else 200
	var mode := str(args[2]).to_lower() if args.size() > 2 else "paired"
	if mode == "current":
		for count in [2, 3, 4]:
			var result := run_current_batch(count, first_seed, games)
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
static func run_current_batch(count: int, first_seed: int, games: int) -> Dictionary:
	var ai := AiController.new()
	var rounds_total := 0
	var completed := 0
	var timeouts := 0
	var errors := 0
	var winners := {}
	var first_faction_samples := {}
	var first_faction_wins := {}
	var never_main_players := 0
	for seed_value in range(first_seed, first_seed + games):
		var g := CardRules.new()
		g.start(count, seed_value)
		var first_faction := []
		for p in range(count): first_faction.append("")
		var steps := 0
		var error_text := ""
		while g.winner < 0 and steps < 2400:
			var slot := int(g.pending.get("slot", g.current))
			var action := ai.choose_rules_action(g, slot)
			if action.is_empty():
				error_text = "AI empty"
				break
			error_text = g.submit(slot, action)
			if not error_text.is_empty(): break
			for p in range(count):
				if first_faction[p].is_empty() and not g.players[p].main.is_empty():
					first_faction[p] = str(g.players[p].main.get("faction", ""))
					if first_faction[p].is_empty(): first_faction[p] = "中立"
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
		for p in range(count):
			if first_faction[p].is_empty():
				never_main_players += 1
				continue
			first_faction_samples[first_faction[p]] = int(first_faction_samples.get(first_faction[p], 0)) + 1
			if g.winner == p:
				first_faction_wins[first_faction[p]] = int(first_faction_wins.get(first_faction[p], 0)) + 1
		g.dispose()
	return {
		"mode":"current",
		"count":count,
		"games":games,
		"completed":completed,
		"timeouts":timeouts,
		"errors":errors,
		"completion_rate":float(completed) / float(games) if games > 0 else 0.0,
		"avg_rounds":float(rounds_total) / float(completed) if completed > 0 else -1.0,
		"winners":winners,
		"first_equipped_faction_samples":first_faction_samples,
		"first_equipped_faction_wins":first_faction_wins,
		"never_main_players":never_main_players
	}
