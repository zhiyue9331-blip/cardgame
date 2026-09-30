extends SceneTree

const TEST_PORT := 37461


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var server_root := Node.new()
	server_root.name = "Server"
	root.add_child(server_root)
	var client_root := Node.new()
	client_root.name = "Client"
	root.add_child(client_root)

	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	set_multiplayer(server_api, server_root.get_path())
	set_multiplayer(client_api, client_root.get_path())

	var server := NetworkSession.new()
	server.name = "NetworkSession"
	server_root.add_child(server)
	var client := NetworkSession.new()
	client.name = "NetworkSession"
	client_root.add_child(client)
	await process_frame

	assert(server.host_room(TEST_PORT, "房主", 2) == OK)
	assert(client.join_room("127.0.0.1", TEST_PORT, "客人") == OK)
	assert(await _wait_until(func() -> bool: return server.players.size() == 2 and client.players.size() == 2, 4.0))
	assert(server.players[0].name == "房主")
	assert(server.players[1].name == "客人")

	var start_count := [0]
	server.game_started.connect(func(_seed: int, _players: Array[Dictionary]) -> void: start_count[0] += 1)
	client.game_started.connect(func(_seed: int, _players: Array[Dictionary]) -> void: start_count[0] += 1)
	assert(server.host_start_game())
	assert(await _wait_until(func() -> bool: return start_count[0] == 2, 4.0))
	assert(server.game_in_progress and client.game_in_progress)
	assert(not server.can_start_game())

	var received_count := [0]
	server.action_requested.connect(func(_sender: int, action: Dictionary) -> void: server.accept_action(action))
	server.action_received.connect(func(_action: Dictionary) -> void: received_count[0] += 1)
	client.action_received.connect(func(_action: Dictionary) -> void: received_count[0] += 1)
	client.submit_action({"type": "end_turn"})
	assert(await _wait_until(func() -> bool: return received_count[0] == 2, 4.0))

	client.close_room(false)
	server.close_room(false)
	print("NETWORK_SESSION_TEST_OK players=2 actions=%d" % received_count[0])
	quit(0)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return condition.call()
