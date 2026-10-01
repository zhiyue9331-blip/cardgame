extends SceneTree

func _init() -> void: call_deferred("run")

func wait_for(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 4000
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await process_frame
	return false

func run() -> void:
	var scene := load("res://main.tscn") as PackedScene
	var games: Array[GameController] = []
	for title in ["Server", "Client"]:
		var container := Node.new()
		container.name = title
		root.add_child(container)
		set_multiplayer(SceneMultiplayer.new(), container.get_path())
		var game := scene.instantiate() as GameController
		container.add_child(game)
		games.append(game)
	await process_frame
	var host := games[0]
	var client := games[1]
	assert(host.network_session.host_room(37462, "房主", 2) == OK)
	assert(client.network_session.join_room("127.0.0.1", 37462, "访客") == OK)
	assert(await wait_for(func(): return host.network_session.players.size() == 2))
	assert(host.network_session.host_start_game())
	assert(await wait_for(func(): return host.online_game and client.online_game))
	assert(host.rules_engine.players == client.rules_engine.players)
	# Both peers start this regression from the same public planning fixture.
	for game in games:
		var rules := game.rules_engine
		rules.current = 0
		rules.players[0].main = CardDatabase.find_card("scheme_lamp")
		rules.players[0].sub = CardDatabase.find_card("scheme_hourglass")
		rules.players[0].hand.assign([CardDatabase.find_card("scheme_supply"), CardDatabase.find_card("scheme_detonate")])
		rules.players[0].cost = 3
		rules.players[1].hand.clear()
		game._sync_from_rules_engine()
	var planned_actions: Array[Dictionary] = [
		{"type":"plan", "card_id":"scheme_supply"},
		{"type":"cancel_plan"},
		{"type":"end_turn"},
		{"type":"end_turn"},
		{"type":"plan", "card_id":"scheme_detonate"},
		{"type":"end_turn"},
		{"type":"end_turn"},
		{"type":"choose", "option":"1", "card_ids":[]},
	]
	var ai := AiController.new()
	var steps := 0
	var manual_buffer_checked := false
	while steps < 90 and host.rules_engine.winner < 0:
		var slot: int = host.rules_engine.pending.get("slot", host.rules_engine.current)
		var action: Dictionary = planned_actions[steps] if steps < planned_actions.size() else ai.choose_rules_action(host.rules_engine, slot)
		if steps == 1:
			assert(host.rules_engine.players[0].plan.base_id == "scheme_supply")
		if steps == 2:
			assert(host.rules_engine.players[0].plan.is_empty() and host.rules_engine.players[0].plan_used)
			assert(not host.rules_engine.validate_action(0, {"type":"plan", "card_id":"scheme_detonate"}).is_empty())
		if steps == 7:
			assert(host.rules_engine.pending.kind == "plan_target" and int(host.rules_engine.players[0].cost) == 3)
			assert(not host.rules_engine.validate_action(0, {"type":"swap_equipment"}).is_empty())
		assert(not action.is_empty())
		if slot == 1 and host.rules_engine.pending.get("kind", "") == "buffer" and not manual_buffer_checked:
			client._rules_submit({"type":"choose", "card_ids":[], "option":""})
			manual_buffer_checked = true
		else:
			games[slot]._rules_submit(action)
		steps += 1
		assert(await wait_for(func(): return client._game_session.last_sequence == steps and host._game_session.last_sequence == steps))
		assert(host.rules_engine.players == client.rules_engine.players)
		assert(host.rules_engine.deck == client.rules_engine.deck)
		assert(host.rules_engine.discard == client.rules_engine.discard)
		assert(host.rules_engine.pending == client.rules_engine.pending)
		assert(host.rules_engine.resolving == client.rules_engine.resolving)
		assert(host.rules_engine.inspected == client.rules_engine.inspected)
		await process_frame
	assert(manual_buffer_checked)
	client.network_session.close_room(false)
	host.network_session.close_room(false)
	for game in games:
		game.rules_engine.dispose()
		game.queue_free()
	await process_frame
	print("RULES_ONLINE_TEST_OK replicated_actions=%d" % steps)
	quit(0)

