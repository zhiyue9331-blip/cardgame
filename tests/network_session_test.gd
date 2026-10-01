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
	var survivor_root := Node.new()
	survivor_root.name = "Survivor"
	root.add_child(survivor_root)

	var server_api := SceneMultiplayer.new()
	var client_api := SceneMultiplayer.new()
	var survivor_api := SceneMultiplayer.new()
	set_multiplayer(server_api, server_root.get_path())
	set_multiplayer(client_api, client_root.get_path())
	set_multiplayer(survivor_api, survivor_root.get_path())

	var server := NetworkSession.new()
	server.name = "NetworkSession"
	server_root.add_child(server)
	var client := NetworkSession.new()
	client.name = "NetworkSession"
	client_root.add_child(client)
	var survivor := NetworkSession.new()
	survivor.name = "NetworkSession"
	survivor_root.add_child(survivor)
	await process_frame

	assert(server.host_room(TEST_PORT, "房主", 3) == OK)
	assert(client.join_room("127.0.0.1", TEST_PORT, "客人") == OK)
	assert(survivor.join_room("127.0.0.1", TEST_PORT, "幸存者") == OK)
	assert(await _wait_until(func() -> bool: return server.players.size() == 3 and client.players.size() == 3 and survivor.players.size() == 3, 4.0))
	assert(server.players[0].name == "房主")
	assert(server.players[1].name == "客人")
	assert(server.players[2].name == "幸存者")

	var start_count := [0]
	server.game_started.connect(func(_seed: int, _players: Array[Dictionary]) -> void: start_count[0] += 1)
	client.game_started.connect(func(_seed: int, _players: Array[Dictionary]) -> void: start_count[0] += 1)
	survivor.game_started.connect(func(_seed: int, _players: Array[Dictionary]) -> void: start_count[0] += 1)
	assert(server.host_start_game())
	assert(await _wait_until(func() -> bool: return start_count[0] == 3, 4.0))
	assert(server.game_in_progress and client.game_in_progress and survivor.game_in_progress)
	assert(not server.can_start_game())
	var abort_signals := [0, 0]
	server.room_closed.connect(func() -> void: abort_signals[0] += 1)
	survivor.room_closed.connect(func() -> void: abort_signals[1] += 1)

	var received_count := [0]
	server.action_requested.connect(func(_sender: int, action: Dictionary) -> void: server.accept_action(action))
	server.action_received.connect(func(_action: Dictionary) -> void: received_count[0] += 1)
	client.action_received.connect(func(_action: Dictionary) -> void: received_count[0] += 1)
	survivor.action_received.connect(func(_action: Dictionary) -> void: received_count[0] += 1)
	client.submit_action({"type": "end_turn"})
	assert(await _wait_until(func() -> bool: return received_count[0] == 3, 4.0))

	# An unregistered peer disconnect must not abort the active match.
	server._on_peer_disconnected(9999)
	assert(server.game_in_progress)

	# A real registered peer disconnect aborts the match on the host and the
	# still-connected survivor, while the remaining roster stays available.
	client.close_room(false)
	assert(await _wait_until(func() -> bool:
		return not server.game_in_progress and not survivor.game_in_progress and abort_signals[0] == 1 and abort_signals[1] == 1,
		4.0))
	assert(server.is_host() and server.players.size() == 2)
	assert(survivor.players.size() == 2)

	# The preserved room can start a new game with the remaining two players.
	assert(server.host_start_game())
	assert(await _wait_until(func() -> bool: return start_count[0] == 5, 4.0))
	assert(server.game_in_progress and survivor.game_in_progress)

	server.close_room(false)
	survivor.close_room(false)
	print("NETWORK_SESSION_TEST_OK players=3 actions=%d disconnect_abort=true restart=true" % received_count[0])
	quit(0)


func _wait_until(condition: Callable, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call():
			return true
		await process_frame
	return condition.call()
