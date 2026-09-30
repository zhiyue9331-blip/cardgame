class_name TableSurface
extends Control

## A quiet, opaque play surface that keeps the card table readable over the lobby artwork.
signal audio_enabled_changed(enabled: bool)

var audio_enabled := true
var active_slot := -1
var local_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_table()
	_setup_sound_control()
	queue_redraw()


func _setup_sound_control() -> void:
	var preferences := ConfigFile.new()
	preferences.load("user://presentation.cfg")
	audio_enabled = bool(preferences.get_value("audio", "enabled", true))
	var button := Button.new()
	button.name = "SoundToggle"
	button.z_index = 1
	button.position = Vector2(1590, 31)
	button.size = Vector2(148, 44)
	button.toggle_mode = true
	button.button_pressed = audio_enabled
	button.text = "音效 · 开" if audio_enabled else "音效 · 关"
	button.tooltip_text = "开启或关闭战斗音效"
	add_child(button)
	button.toggled.connect(func(enabled: bool) -> void:
		audio_enabled = enabled
		button.text = "音效 · 开" if enabled else "音效 · 关"
		preferences.load("user://presentation.cfg")
		preferences.set_value("audio", "enabled", enabled)
		preferences.save("user://presentation.cfg")
		audio_enabled_changed.emit(enabled)
	)


func _panel(fill: Color, line: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_table() -> void:
	var board := get_parent() as Control
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("#e8e3d5"))
	theme.set_color("font_color", "Button", Color("#e8e3d5"))
	theme.set_color("font_hover_color", "Button", Color("#fff2cf"))
	theme.set_color("font_pressed_color", "Button", Color("#fff2cf"))
	theme.set_color("font_disabled_color", "Button", Color("#7a8e8a"))
	theme.set_stylebox("normal", "Button", _panel(Color("#183433"), Color("#49625b"), 7))
	theme.set_stylebox("hover", "Button", _panel(Color("#254742"), Color("#c9ad70"), 7))
	theme.set_stylebox("pressed", "Button", _panel(Color("#394b38"), Color("#d9be82"), 7))
	theme.set_stylebox("disabled", "Button", _panel(Color("#152b2a"), Color("#2b4641"), 7))
	var focus := _panel(Color.TRANSPARENT, Color("#e4cc93"), 7)
	theme.set_stylebox("focus", "Button", focus)
	board.theme = theme
	for path in ["Header", "PlayerArea", "LogPanel", "DiscardPopup"]:
		board.get_node(path).add_theme_stylebox_override("panel", _panel(Color("#0c2223"), Color("#36524b")))
	# The opponent cards themselves form the upper row; a second enclosing box is unnecessary.
	board.get_node("OpponentArea").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for path in ["CenterArea/PrepareZone", "CenterArea/DeckZone", "CenterArea/DiscardZone", "PlayerArea/MainEquipment", "PlayerArea/SubEquipment"]:
		var style := _panel(Color("#102a2a"), Color("#776b49"), 9)
		style.shadow_color = Color(0, 0, 0, 0.2)
		style.shadow_size = 7
		board.get_node(path).add_theme_stylebox_override("panel", style)
	board.get_node("PlayerArea/EndTurnButton").add_theme_stylebox_override("normal", _panel(Color("#655833"), Color("#c9ad70"), 9))
	board.get_node("PlayerArea/EndTurnButton").add_theme_font_size_override("font_size", 21)
	var guide := Label.new()
	guide.position = Vector2(1285, 454)
	guide.size = Vector2(425, 130)
	guide.text = "出牌指引\n\n装备牌 → 主 / 副装备槽\n攻击 / 效果 → 玩家头像"
	guide.add_theme_color_override("font_color", Color("#8fa69b"))
	guide.add_theme_font_size_override("font_size", 18)
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guide)
	var mark := Label.new()
	mark.z_index = 1
	mark.position = Vector2(125, 39)
	mark.text = "◆  对 局"
	mark.add_theme_color_override("font_color", Color("#c9ad70"))
	mark.add_theme_font_size_override("font_size", 18)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(mark)

func update_turn(is_local_active: bool, active_opponent_index: int) -> void:
	local_active = is_local_active
	active_slot = active_opponent_index
	var cards := get_node_or_null("../OpponentArea/OpponentContent/OpponentCards")
	if cards:
		var index := 0
		for panel in cards.get_children():
			if not panel.is_queued_for_deletion():
				panel.set_turn_active(index == active_opponent_index)
				index += 1
	var head := get_node("../PlayerArea/SelfTargetHead") as PanelContainer
	head.add_theme_stylebox_override("panel", _panel(Color("#193733") if local_active else Color("#102a2a"), Color("#d7ba76") if local_active else Color("#49625b")))
	queue_redraw()

func _draw() -> void:
	var surface_size := size
	# Deep ink green makes the active table feel like a physical felt surface.
	draw_rect(Rect2(Vector2.ZERO, surface_size), Color("#071b1c"), true)
	draw_rect(Rect2(24, 20, size.x - 48, size.y - 40), Color("#0b2928"), true)
	draw_rect(Rect2(42, 36, size.x - 84, size.y - 72), Color("#153936"), false, 1.0)
	var center := Vector2(size.x * 0.5, size.y * 0.47)
	var radius := minf(size.x * 0.25, size.y * 0.18)
	draw_arc(center, radius, 0.0, TAU, 96, Color(0.82, 0.67, 0.36, 0.16), 1.0)
	draw_arc(center, radius * 0.72, 0.0, TAU, 96, Color(0.82, 0.67, 0.36, 0.10), 1.0)
	var diamond := PackedVector2Array([center + Vector2(0, -radius * 0.54), center + Vector2(radius * 0.54, 0), center + Vector2(0, radius * 0.54), center + Vector2(-radius * 0.54, 0), center + Vector2(0, -radius * 0.54)])
	draw_polyline(diamond, Color(0.88, 0.73, 0.42, 0.18), 1.0, true)
	# Small corner ornaments establish a frame without adding another heavy panel.
	var gold := Color(0.88, 0.73, 0.42, 0.46)
	for corner in [Vector2(44, 38), Vector2(size.x - 44, 38), Vector2(44, size.y - 38), Vector2(size.x - 44, size.y - 38)]:
		var sx := 1.0 if corner.x < size.x * 0.5 else -1.0
		var sy := 1.0 if corner.y < size.y * 0.5 else -1.0
		draw_line(corner, corner + Vector2(24 * sx, 0), gold, 1.0)
		draw_line(corner, corner + Vector2(0, 18 * sy), gold, 1.0)
	if active_slot >= 0:
		draw_arc(center, radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * 0.18, 24, Color(0.93, 0.78, 0.42, 0.48), 2.0)
