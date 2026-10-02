class_name LobbyController
extends Node

signal offline_start_requested
signal roster_changed(roster: Array[Dictionary])

var controls: Dictionary = {}
var network_session: NetworkSession
var online_roster: Array[Dictionary] = []


func setup(control_nodes: Dictionary, session: NetworkSession) -> void:
	controls = control_nodes
	network_session = session
	var network_mode: OptionButton = controls.network_mode
	network_mode.add_item("单机游戏", 0)
	network_mode.add_item("创建联机房间", 1)
	network_mode.add_item("加入联机房间", 2)
	var player_count: OptionButton = controls.player_count_selector
	player_count.add_item("2 人", 2)
	player_count.add_item("3 人", 3)
	player_count.add_item("4 人", 4)
	var preferences := ConfigFile.new()
	var saved_name := ""
	if preferences.load("user://presentation.cfg") == OK:
		saved_name = str(preferences.get_value("player", "name", "")).strip_edges()
	controls.player_name_input.text = saved_name if not saved_name.is_empty() else ("玩家%d" % randi_range(100, 999))
	controls.player_name_input.text_changed.connect(func(new_text: String) -> void:
		_save_player_name(new_text))
	network_mode.item_selected.connect(_on_network_mode_selected)
	controls.start_button.pressed.connect(_on_start_pressed)
	controls.connection_button.pressed.connect(_on_connection_pressed)
	controls.leave_room_button.pressed.connect(_leave_online_room)
	network_session.status_changed.connect(_on_network_status_changed)
	network_session.roster_changed.connect(_on_network_roster_changed)
	update_controls()


func _on_network_mode_selected(_index: int) -> void:
	if network_session.is_online():
		network_session.close_room()
	update_controls()


func _on_connection_pressed() -> void:
	_save_player_name()
	var network_mode: OptionButton = controls.network_mode
	var selected_mode: int = network_mode.get_selected_id()
	if selected_mode == 1:
		network_session.host_room(int(controls.server_port.value), controls.player_name_input.text, controls.player_count_selector.get_selected_id())
	elif selected_mode == 2:
		network_session.join_room(controls.server_address.text, int(controls.server_port.value), controls.player_name_input.text)
	update_controls()


func _leave_online_room() -> void:
	network_session.close_room()
	update_controls()


func _on_network_status_changed(message: String, is_error: bool) -> void:
	controls.room_status.text = message
	controls.room_status.add_theme_color_override("font_color", Color("#ef8b78") if is_error else Color("#a9c9dd"))
	update_controls(false)


func _on_network_roster_changed(roster: Array[Dictionary]) -> void:
	online_roster = roster.duplicate(true)
	var names: PackedStringArray = []
	for player in online_roster:
		names.append("%d. %s" % [int(player.get("slot", 0)) + 1, str(player.get("name", "玩家"))])
	controls.room_players.text = "  ·  ".join(names)
	update_controls(false)
	roster_changed.emit(online_roster.duplicate(true))


func update_controls(reset_status := true) -> void:
	var selected_mode: int = controls.network_mode.get_selected_id()
	var connected := network_session.is_online()
	controls.server_address.visible = selected_mode == 2
	controls.server_port.visible = selected_mode != 0
	controls.connection_button.visible = selected_mode != 0 and not connected
	controls.connection_button.text = "创建房间" if selected_mode == 1 else "加入房间"
	controls.leave_room_button.visible = connected
	controls.player_count_selector.disabled = connected or selected_mode == 2
	controls.player_name_input.editable = not connected
	controls.network_mode.disabled = connected
	controls.start_button.visible = selected_mode == 0 or (connected and network_session.is_host())
	controls.start_button.disabled = connected and not network_session.can_start_game()
	controls.start_button.text = "开始单机游戏" if selected_mode == 0 else "房主开始游戏"
	if reset_status:
		if selected_mode == 0:
			controls.room_status.text = "单机模式"
			controls.room_players.text = ""
		elif not connected:
			controls.room_status.text = "设置昵称、地址和端口后连接"
			controls.room_players.text = ""


func _on_start_pressed() -> void:
	_save_player_name()
	if controls.network_mode.get_selected_id() == 0:
		offline_start_requested.emit()
	elif network_session.is_host():
		network_session.host_start_game()


func _save_player_name(value: String = "") -> void:
	var name_text: String = value.strip_edges() if not value.is_empty() else controls.player_name_input.text.strip_edges()
	if not name_text.is_empty():
		var preferences := ConfigFile.new()
		preferences.load("user://presentation.cfg")
		preferences.set_value("player", "name", name_text.left(16))
		preferences.save("user://presentation.cfg")
