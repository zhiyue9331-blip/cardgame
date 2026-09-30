extends SceneTree

func _init() -> void:
	call_deferred("run")

func state(g: CardRules) -> Array:
	return [g.players, g.deck, g.discard, g.resolving, g.inspected, g.pending, g.current, g.winner, g.round_number]

func conservation(g: CardRules, expected: int) -> bool:
	var cards: Array = g.deck + g.discard + g.resolving + g.inspected
	for p in g.players:
		cards += p.hand + p.buffer
		if not p.main.is_empty(): cards.append(p.main)
		if not p.sub.is_empty(): cards.append(p.sub)
	var ids: Dictionary = {}
	for c in cards:
		if c.is_empty() or ids.has(c.id):
			push_error("Duplicate/empty card: " + str(c))
			return false
		ids[c.id] = true
	if cards.size() != expected:
		push_error("Card count %d expected%d" % [cards.size(), expected])
		return false
	return true

func run() -> void:
	var ai := AiController.new()
	var games := 0
	var total_steps := 0
	var all_actions: Dictionary = {}
	for count in [2, 4]:
		for seed_value in [31, 76, 109]:
			var g := CardRules.new()
			var replica := CardRules.new()
			g.start(count, seed_value)
			replica.start(count, seed_value)
			var expected := 54 if count == 2 else 102
			var step := 0
			var counters := 0
			var resonance_players: Dictionary = {}
			while g.winner < 0 and step < 1800:
				step += 1
				var slot := int(g.pending.get("slot", g.current))
				var action := ai.choose_rules_action(g, slot)
				if action.is_empty():
					push_error("AI cannot act: " + str(g.pending))
					quit(1)
					return
				if g.pending.get("kind") == "counter" and not action.get("card_ids", []).is_empty(): counters += 1
				var error := g.submit(slot, action)
				if not error.is_empty():
					push_error("AI rejected: %s action=%s pending=%s" % [error, action, g.pending])
					quit(1)
					return
				if not replica.submit(slot, action).is_empty() or state(g) != state(replica):
					push_error("Replica desync count%d seed%d step%d" % [count, seed_value, step])
					quit(1)
					return
				if not conservation(g, expected):
					push_error("Conservation count%d seed%d step%d %s" % [count, seed_value, step, action])
					quit(1)
					return
				all_actions[str(action.type)] = int(all_actions.get(str(action.type), 0)) + 1
				for who in range(count):
					if g.resonance(who, str(g.players[who].main.get("faction", ""))) > 0 and not resonance_players.has(who): resonance_players[who] = g.round_number
			if g.winner < 0:
				push_error("Playtest did not finish count%d seed%d round%d" % [count, seed_value, g.round_number])
				quit(1)
				return
			games += 1
			total_steps += step
			print("PLAYTEST players=%d seed=%d winner=%d rounds=%d steps=%d counters=%d first_resonance=%s" % [count, seed_value, g.winner + 1, g.round_number, step, counters, resonance_players])
	print("CARD_PLAYTEST_OK games=%d actions=%d kinds=%s" % [games, total_steps, all_actions])
	quit(0)
