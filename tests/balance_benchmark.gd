extends SceneTree

# Paired seeds and one target policy for both versions; does not alter the live AI.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var first_seed := int(args[0]) if args.size() > 0 else 6000
	var games := int(args[1]) if args.size() > 1 else 200
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
