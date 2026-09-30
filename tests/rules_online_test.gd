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
	var ai := AiController.new()
	var steps := 0
	while steps < 90 and host.rules_engine.winner < 0:
		var slot: int = host.rules_engine.pending.get("slot", host.rules_engine.current)
		var action := ai.choose_rules_action(host.rules_engine, slot)
		assert(not action.is_empty())
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
	client.network_session.close_room(false)
	host.network_session.close_room(false)
	for game in games:
		game.rules_engine.dispose()
		game.queue_free()
	await process_frame
	print("RULES_ONLINE_TEST_OK replicated_actions=%d" % steps)
	quit(0)

