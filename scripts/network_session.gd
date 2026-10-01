class_name NetworkSession
extends Node

signal status_changed(message: String, is_error: bool)
signal roster_changed(players: Array[Dictionary])
signal game_started(game_seed: int, players: Array[Dictionary])
signal action_requested(sender_peer_id: int, action: Dictionary)
signal action_received(action: Dictionary)
signal room_closed()

const HOST_PEER_ID := 1
const DEFAULT_PORT := 7000

var mode := "offline"
var local_player_name := "玩家"
var room_capacity := 2
var players: Array[Dictionary] = []
var game_in_progress := false
var _next_action_sequence := 1


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_room(port: int, player_name: String, capacity: int) -> Error:
	close_room(false)
	local_player_name = _sanitize_name(player_name)
	room_capacity = clampi(capacity, 2, 4)
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(port, room_capacity - 1)
	if error != OK:
		status_changed.emit("创建房间失败：%s" % error_string(error), true)
		return error
	multiplayer.multiplayer_peer = peer
	mode = "host"
	game_in_progress = false
	players = [{"peer_id": HOST_PEER_ID, "slot": 0, "name": local_player_name}]
	_next_action_sequence = 1
	status_changed.emit("房间已创建，端口 %d；等待其他玩家加入。" % port, false)
	roster_changed.emit(players.duplicate(true))
	return OK


func join_room(address: String, port: int, player_name: String) -> Error:
	close_room(false)
	local_player_name = _sanitize_name(player_name)
	var target := address.strip_edges()
	if target.is_empty():
		target = "127.0.0.1"
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(target, port)
	if error != OK:
		status_changed.emit("加入房间失败：%s" % error_string(error), true)
		return error
	multiplayer.multiplayer_peer = peer
	mode = "client"
	game_in_progress = false
	players.clear()
	status_changed.emit("正在连接 %s:%d…" % [target, port], false)
	return OK


func close_room(emit_signal := true) -> void:
	var had_room := mode != "offline"
	var current_peer := multiplayer.multiplayer_peer
	if current_peer != null:
		current_peer.close()
		multiplayer.multiplayer_peer = null
	mode = "offline"
	game_in_progress = false
	players.clear()
	_next_action_sequence = 1
	if had_room:
		status_changed.emit("已离开联机房间。", false)
		roster_changed.emit(players.duplicate(true))
		if emit_signal:
			room_closed.emit()


func is_online() -> bool:
	return mode in ["host", "client"]


func is_host() -> bool:
	return mode == "host"


func local_peer_id() -> int:
	if not is_online():
		return HOST_PEER_ID
	return multiplayer.get_unique_id()


func local_slot() -> int:
	return slot_for_peer(local_peer_id())


func slot_for_peer(peer_id: int) -> int:
	for player in players:
		if int(player.get("peer_id", 0)) == peer_id:
			return int(player.get("slot", -1))
	return -1


func player_name_for_slot(slot: int) -> String:
	for player in players:
		if int(player.get("slot", -1)) == slot:
			return str(player.get("name", "玩家 %d" % (slot + 1)))
	return "玩家 %d" % (slot + 1)


func can_start_game() -> bool:
	return is_host() and not game_in_progress and players.size() >= 2


func can_restart_game() -> bool:
	# 对局结束（game_in_progress 仍为 true）后，房主可重开一局。
	return is_host() and game_in_progress and players.size() >= 2


func host_start_game() -> bool:
	if not can_start_game() and not can_restart_game():
		status_changed.emit("至少需要 2 名玩家才能开始联机游戏。", true)
		return false
	var game_seed := int(Time.get_unix_time_from_system()) ^ Time.get_ticks_msec()
	var snapshot := players.duplicate(true)
	for index in range(snapshot.size()): snapshot[index].slot = index
	game_in_progress = true
	_receive_start_game.rpc(game_seed, snapshot)
	return true


func submit_action(action: Dictionary) -> void:
	if not is_online():
		return
	var payload := action.duplicate(true)
	payload["actor_slot"] = local_slot()
	if is_host():
		action_requested.emit(HOST_PEER_ID, payload)
	else:
		_request_action.rpc_id(HOST_PEER_ID, payload)


func accept_action(action: Dictionary) -> void:
	if not is_host():
		return
	var accepted := action.duplicate(true)
	accepted["sequence"] = _next_action_sequence
	_next_action_sequence += 1
	_receive_action.rpc(accepted)


func reject_action(sender_peer_id: int, reason: String) -> void:
	if not is_host():
		return
	if sender_peer_id == HOST_PEER_ID:
		_receive_rejection(reason)
	else:
		_receive_rejection.rpc_id(sender_peer_id, reason)


func _on_peer_connected(peer_id: int) -> void:
	if is_host():
		status_changed.emit("玩家 %d 已连接，正在登记…" % peer_id, false)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	var removed_name := "玩家 %d" % peer_id
	var registered := false
	for index in range(players.size() - 1, -1, -1):
		if int(players[index].get("peer_id", 0)) == peer_id:
			removed_name = str(players[index].get("name", removed_name))
			players.remove_at(index)
			registered = true
			break
	# Rejected or half-connected peers never entered the roster and must not
	# interrupt an active match.
	if not registered:
		return
	_broadcast_roster()
	if game_in_progress:
		_abort_game.rpc("联机对局已中止：%s 已断开连接，请房主重新开始。" % removed_name)
	else:
		status_changed.emit("%s 已断开连接。" % removed_name, true)


func _on_connected_to_server() -> void:
	status_changed.emit("连接成功，正在加入房间…", false)
	_register_player.rpc_id(HOST_PEER_ID, local_player_name)


func _on_connection_failed() -> void:
	status_changed.emit("连接失败，请检查 IP、端口和防火墙。", true)
	close_room(false)
	roster_changed.emit(players.duplicate(true))


func _on_server_disconnected() -> void:
	status_changed.emit("与房主的连接已断开。", true)
	close_room(false)
	roster_changed.emit(players.duplicate(true))
	room_closed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _register_player(requested_name: String) -> void:
	if not is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if slot_for_peer(sender_id) >= 0:
		return
	if game_in_progress:
		_receive_rejection.rpc_id(sender_id, "牌局已经开始，暂时不能加入。")
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return
	if players.size() >= room_capacity:
		_receive_rejection.rpc_id(sender_id, "房间已满。")
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)
		return
	var used_slots: Array[int] = []
	for player in players:
		used_slots.append(int(player.get("slot", -1)))
	var free_slot := 0
	while free_slot in used_slots:
		free_slot += 1
	players.append({
		"peer_id": sender_id,
		"slot": free_slot,
		"name": _sanitize_name(requested_name)
	})
	players.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.slot) < int(b.slot))
	status_changed.emit("%s 加入了房间。" % _sanitize_name(requested_name), false)
	_broadcast_roster()


func _broadcast_roster() -> void:
	if not is_host():
		return
	_receive_roster.rpc(players.duplicate(true), room_capacity)


@rpc("authority", "call_local", "reliable")
func _receive_roster(snapshot: Array, capacity: int) -> void:
	players.clear()
	for item in snapshot:
		if item is Dictionary:
			players.append((item as Dictionary).duplicate(true))
	room_capacity = capacity
	status_changed.emit("房间人数：%d / %d" % [players.size(), room_capacity], false)
	roster_changed.emit(players.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _receive_start_game(game_seed: int, roster: Array) -> void:
	game_in_progress = true
	players.clear()
	for item in roster:
		if item is Dictionary:
			players.append((item as Dictionary).duplicate(true))
	game_started.emit(game_seed, players.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _abort_game(message: String) -> void:
	if not game_in_progress:
		return
	game_in_progress = false
	status_changed.emit(message, true)
	room_closed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _request_action(action: Dictionary) -> void:
	if not is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	if slot_for_peer(sender_id) != int(action.get("actor_slot", -1)):
		reject_action(sender_id, "操作身份校验失败。")
		return
	action_requested.emit(sender_id, action.duplicate(true))


@rpc("authority", "call_local", "reliable")
func _receive_action(action: Dictionary) -> void:
	action_received.emit(action.duplicate(true))


@rpc("authority", "call_remote", "reliable")
func _receive_rejection(reason: String) -> void:
	status_changed.emit("操作未执行：%s" % reason, true)


func _sanitize_name(value: String) -> String:
	var result := value.strip_edges()
	if result.is_empty():
		result = "玩家"
	return result.left(16)
