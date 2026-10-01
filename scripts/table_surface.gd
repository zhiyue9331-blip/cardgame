class_name TableSurface
extends Control

signal audio_enabled_changed(enabled: bool)

const TABLE_ART := preload("res://assets/ui/astral-table.png")
const GOLD := Color("#c6a56c")
const INK := Color("#16191fe8")
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
		audio_enabled_changed.emit(enabled))

func _panel(fill: Color, line: Color, radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = line
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.3)
	style.shadow_size = 6
	return style

func _style_table() -> void:
	var board := get_parent() as Control
	var theme := Theme.new()
	theme.default_font_size = 22
	for kind in ["Label", "Button", "OptionButton", "LineEdit", "CheckButton"]:
		theme.set_color("font_color", kind, Color("#ede0c5"))
		theme.set_color("font_hover_color", kind, Color("#fff0ce"))
		theme.set_color("font_pressed_color", kind, Color("#fff0ce"))
		theme.set_color("font_disabled_color", kind, Color("#797776"))
		if kind == "Label":
			continue
		for state in ["normal", "hover", "pressed", "disabled"]:
			var fill := Color("#202129")
			var line := Color("#695943")
			if state == "hover":
				fill = Color("#35302a")
				line = GOLD
			elif state == "pressed":
				fill = Color("#51412a")
				line = Color("#efd29a")
			elif state == "disabled":
				fill = Color("#16181de0")
				line = Color("#393638")
			theme.set_stylebox(state, kind, _panel(fill, line))
		var focus := _panel(Color.TRANSPARENT, Color("#edd6a2"))
		focus.shadow_size = 0
		theme.set_stylebox("focus", kind, focus)
	theme.set_stylebox("panel", "PopupMenu", _panel(Color("#181a20"), GOLD))
	theme.set_color("font_color", "PopupMenu", Color("#ede0c5"))
	theme.set_font_size("font_size", "PopupMenu", 22)
	theme.set_stylebox("panel", "TooltipPanel", _panel(Color("#11141cf5"), GOLD))
	theme.set_color("font_color", "TooltipLabel", Color("#f6ead2"))
	theme.set_font_size("font_size", "TooltipLabel", 22)
	board.theme = theme
	for path in ["Header", "LogPanel", "DiscardPopup"]:
		board.get_node(path).add_theme_stylebox_override("panel", _panel(INK, Color("#786348")))
	board.get_node("PlayerArea").add_theme_stylebox_override("panel", _panel(Color("#11141bcc"), Color("#786348"), 12))
	var header := _panel(Color("#12161bea"), Color("#786348"))
	header.content_margin_left = 180
	header.content_margin_right = 600
	board.get_node("Header").add_theme_stylebox_override("panel", header)
	var header_label := board.get_node("Header/HeaderText") as Label
	header_label.clip_text = true
	header_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_label.add_theme_font_size_override("font_size", 24)
	board.get_node("OpponentArea").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for path in ["CenterArea/PrepareZone", "CenterArea/DeckZone", "CenterArea/DiscardZone", "PlayerArea/MainEquipment", "PlayerArea/SubEquipment", "PlayerArea/BufferZone"]:
		var node := board.get_node(path)
		node.add_theme_stylebox_override("panel", _panel(Color("#151820d9"), Color("#8c724b")))
		var title := node.get_node("Content/ZoneTitle") if node.has_node("Content/ZoneTitle") else node.get_node("PileContent/PileTitle")
		title.add_theme_font_size_override("font_size", 22)
		title.add_theme_color_override("font_color", GOLD)
	var buffer := board.get_node("PlayerArea/BufferZone")
	var buffer_style := _panel(Color("#151820d9"), Color("#8c724b"))
	buffer_style.content_margin_top = 3
	buffer_style.content_margin_bottom = 3
	buffer.add_theme_stylebox_override("panel", buffer_style)
	buffer.get_node("Content").add_theme_constant_override("separation", 0)
	buffer.get_node("Content/ZoneTitle").add_theme_font_size_override("font_size", 20)
	buffer.get_node("Content/ZoneContent").add_theme_font_size_override("font_size", 18)
	var end := board.get_node("PlayerArea/EndTurnButton") as Button
	end.add_theme_stylebox_override("normal", _panel(Color("#73502d"), Color("#e4bd7b")))
	end.add_theme_stylebox_override("hover", _panel(Color("#956333"), Color("#ffe2a6")))
	end.add_theme_font_size_override("font_size", 26)
	add_child(_label("操作 / 拖放\n\n装备 → 主 / 副装备\n攻击 / 效果 → 玩家徽记", Vector2(1260, 455), Vector2(440, 135), 22, Color("#b4a68e")))
	add_child(_label("◆  对 局", Vector2(125, 39), Vector2(150, 32), 22, GOLD))
	var root := board.get_parent() as Control
	root.get_node("Background").texture = TABLE_ART
	root.get_node("Dim").color = Color(0.025, 0.035, 0.065, 0.27)
	_style_lobby(root)

func _label(value: String, at: Vector2, bounds: Vector2, font_size: int, tint: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.position = at
	label.size = bounds
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", tint)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 1
	return label

func _style_lobby(root: Control) -> void:
	var lobby := root.get_node("Lobby") as Control
	lobby.theme = get_parent().theme
	var panel := lobby.get_node("Panel") as PanelContainer
	var style := _panel(Color("#13171ef2"), Color("#a78a57"), 14)
	style.content_margin_left = 46
	style.content_margin_right = 46
	style.content_margin_top = 38
	style.content_margin_bottom = 38
	style.shadow_size = 22
	panel.add_theme_stylebox_override("panel", style)
	lobby.add_child(_label("共 鸣  ·  博 弈  ·  后 手", Vector2(190, 330), Vector2(760, 50), 24, GOLD))
	lobby.add_child(_label("卡牌对战", Vector2(180, 390), Vector2(850, 120), 88, Color("#f5e5c3")))
	lobby.add_child(_label("共用一副牌，走出自己的局。", Vector2(190, 535), Vector2(760, 65), 30, Color("#c8b99b")))
	lobby.add_child(_label("共享牌池   /   装备共鸣   /   伏谋筹划\n\n2—4 人 · 单机与联机", Vector2(190, 650), Vector2(790, 120), 24, Color("#b1a38c")))
	for child in panel.get_node("Content").get_children():
		if child is Label:
			child.add_theme_color_override("font_color", Color("#d4c3a4"))
			child.add_theme_font_size_override("font_size", 22)
		elif child is Button or child is LineEdit:
			child.add_theme_font_size_override("font_size", 24)
	panel.get_node("Content/Title").add_theme_font_size_override("font_size", 34)
	panel.get_node("Content/Title").text = "入 席"
	panel.get_node("Content/Hint").text = "共享牌池 · 七系共鸣 · 2—4 人对战"
	panel.get_node("Content/Hint").add_theme_font_size_override("font_size", 18)
	panel.get_node("Content/StartButton").add_theme_stylebox_override("normal", _panel(Color("#785632"), Color("#deb875")))

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
	head.add_theme_stylebox_override("panel", _panel(Color("#302720e8") if local_active else INK, Color("#e0b978") if local_active else Color("#786348"), 10))
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(TABLE_ART, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.025, 0.035, 0.065, 0.16))
	if local_active:
		draw_line(Vector2(125, 655), Vector2(size.x - 125, 655), Color(0.91, 0.74, 0.43, 0.65), 2.0, true)
