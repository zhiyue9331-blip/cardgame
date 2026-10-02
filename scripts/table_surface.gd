class_name TableSurface
extends Control

signal audio_enabled_changed(enabled: bool)

const TABLE_ART := preload("res://assets/ui/astral-table.png")
const GOLD := Color("#c6a56c")
const BRIGHT_GOLD := Color("#e8c56e")
const INK := Color("#101318f0")
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
	button.position = Vector2(1590, 26)
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
	style.shadow_color = Color(0, 0, 0, 0.4)
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
			var fill := Color("#1a1c22")
			var line := Color("#695943")
			if state == "hover":
				fill = Color("#2d2822")
				line = GOLD
			elif state == "pressed":
				fill = Color("#453724")
				line = Color("#efd29a")
			elif state == "disabled":
				fill = Color("#14161be0")
				line = Color("#323034")
			theme.set_stylebox(state, kind, _panel(fill, line))
		var focus := _panel(Color.TRANSPARENT, Color("#edd6a2"))
		focus.shadow_size = 0
		theme.set_stylebox("focus", kind, focus)
	theme.set_stylebox("panel", "PopupMenu", _panel(Color("#14161c"), GOLD))
	theme.set_color("font_color", "PopupMenu", Color("#ede0c5"))
	theme.set_font_size("font_size", "PopupMenu", 22)
	theme.set_stylebox("panel", "TooltipPanel", _panel(Color("#0e1117f5"), GOLD))
	theme.set_color("font_color", "TooltipLabel", Color("#f6ead2"))
	theme.set_font_size("font_size", "TooltipLabel", 22)
	board.theme = theme

	# The phase plaque shares the cut-corner copper treatment.
	var header := _panel(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	header.set_border_width_all(0)
	header.content_margin_left = 24
	header.content_margin_right = 24
	header.content_margin_top = 4
	header.content_margin_bottom = 4
	header.shadow_color = Color(0, 0, 0, 0.65)
	header.shadow_size = 0
	board.get_node("Header").add_theme_stylebox_override("panel", header)
	var header_ornament := preload("res://scripts/action_ornament.gd").new()
	header_ornament.kind = "header"
	board.get_node("Header").add_child(header_ornament)
	header_ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_ornament.show_behind_parent = true
	var header_label := board.get_node("Header/HeaderText") as Label
	header_label.clip_text = true
	header_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	header_label.add_theme_font_size_override("font_size", 24)
	header_label.add_theme_color_override("font_color", Color("#faecd2"))

	# Opponent Area: Transparent container so tabletop stone & engravings show through
	board.get_node("OpponentArea").add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# Center Area: Piles sit directly on the tabletop
	board.get_node("CenterArea/DeckZone").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	board.get_node("CenterArea/DiscardZone").add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# Right-side public action plaque above the end-turn button.
	var prep_style := _panel(Color.TRANSPARENT, Color.TRANSPARENT, 0)
	prep_style.shadow_size = 0
	prep_style.content_margin_left = 18
	prep_style.content_margin_right = 18
	prep_style.content_margin_top = 8
	prep_style.content_margin_bottom = 8
	var prep := board.get_node("PlayerArea/PrepareZone") as DropZone
	prep.add_theme_stylebox_override("panel", prep_style)
	var ornament := preload("res://scripts/action_ornament.gd").new()
	prep.add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.show_behind_parent = true
	prep.mouse_entered.connect(func(): ornament.highlighted = true; ornament.queue_redraw())
	prep.mouse_exited.connect(func(): ornament.highlighted = false; ornament.queue_redraw())
	var prep_title := board.get_node("PlayerArea/PrepareZone/Content/ZoneTitle") as Label
	prep_title.add_theme_font_size_override("font_size", 24)
	prep_title.add_theme_color_override("font_color", BRIGHT_GOLD)
	var prep_content := board.get_node("PlayerArea/PrepareZone/Content/ZoneContent") as Label
	prep_content.add_theme_font_size_override("font_size", 17)
	prep_content.add_theme_color_override("font_color", Color("#c4b79e"))

	# Keep the table continuous behind equipment, hand and status.
	board.get_node("PlayerArea").add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# Player Head: Astrolabe medallion
	var self_head := board.get_node("PlayerArea/SelfTargetHead") as PanelContainer
	self_head.add_theme_stylebox_override("panel", _self_head_style(false))
	var p_title := self_head.get_node("Content/PlayerTitle") as Label
	p_title.add_theme_color_override("font_color", Color("#faebd2"))
	var p_hp := self_head.get_node("Content/VitalRow/PlayerHp") as Label
	p_hp.add_theme_color_override("font_color", Color("#ea5d4d"))
	p_hp.add_theme_font_size_override("font_size", 40)
	p_title.clip_text = true
	p_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

	# Equipment & Buffer Slots
	for path in ["PlayerArea/MainEquipment", "PlayerArea/SubEquipment", "PlayerArea/BufferZone"]:
		var node := board.get_node(path)
		node.add_theme_stylebox_override("panel", _panel(Color("#0b0e13d4"), Color("#6f5938"), 6))
		if path != "PlayerArea/BufferZone":
			var slot_style := _panel(Color.TRANSPARENT, Color.TRANSPARENT, 0)
			slot_style.shadow_size = 0
			node.add_theme_stylebox_override("panel", slot_style)
		var title := node.get_node("Content/ZoneTitle") if node.has_node("Content/ZoneTitle") else node.get_node("PileContent/PileTitle")
		title.add_theme_font_size_override("font_size", 20)
		title.add_theme_color_override("font_color", GOLD)

	var buffer := board.get_node("PlayerArea/BufferZone")
	var buffer_style := _panel(Color("#0b0e1338"), Color.TRANSPARENT, 0)
	buffer_style.shadow_size = 0
	buffer_style.content_margin_left = 4
	buffer_style.content_margin_right = 4
	buffer_style.content_margin_top = 3
	buffer_style.content_margin_bottom = 3
	buffer.add_theme_stylebox_override("panel", buffer_style)
	buffer.get_node("Content").add_theme_constant_override("separation", 0)
	buffer.get_node("Content/ZoneTitle").add_theme_font_size_override("font_size", 19)
	buffer.get_node("Content/ZoneContent").add_theme_font_size_override("font_size", 17)

	# The button script draws its physical face and enabled-only breathing glow.
	var end := board.get_node("PlayerArea/EndTurnButton") as Button
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		end.add_theme_stylebox_override(state, StyleBoxEmpty.new())
		end.add_theme_color_override("font_color" if state == "normal" else "font_%s_color" % state, Color.TRANSPARENT)
	end.add_theme_color_override("font_focus_color", Color.TRANSPARENT)
	end.add_theme_font_size_override("font_size", 28)

	for path in ["LogPanel", "DiscardPopup"]:
		board.get_node(path).add_theme_stylebox_override("panel", _panel(INK, Color("#786348")))

	var root := board.get_parent() as Control
	root.get_node("Background").texture = TABLE_ART
	root.get_node("Dim").color = Color(0.02, 0.025, 0.04, 0.18)
	_style_lobby(root)

func _style_lobby(root: Control) -> void:
	var lobby := root.get_node("Lobby") as Control
	lobby.theme = get_parent().theme
	var panel := lobby.get_node("Panel") as PanelContainer
	var style := _panel(Color("#0d1015f4"), Color("#a78a57"), 14)
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
	head.add_theme_stylebox_override("panel", _self_head_style(local_active))
	queue_redraw()

func _self_head_style(active: bool) -> StyleBoxFlat:
	var style := _panel(Color("#0d101548"), Color.TRANSPARENT, 0)
	style.set_border_width_all(0)
	style.border_width_bottom = 1
	style.border_color = Color("#e8c56e88") if active else Color("#6f593844")
	style.shadow_size = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _draw() -> void:
	draw_texture_rect(TABLE_ART, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.04, 0.12))

	# Warm Candlelight Ambiance in 4 corners
	var corners := [Vector2.ZERO, Vector2(size.x, 0), Vector2(0, size.y), Vector2(size.x, size.y)]
	for c in corners:
		draw_circle(c, 280.0, Color(1.0, 0.70, 0.22, 0.04))
		draw_circle(c, 180.0, Color(1.0, 0.78, 0.30, 0.06))
		draw_circle(c, 90.0, Color(1.0, 0.88, 0.42, 0.09))

	# Brass Astronomical Astrolabe Engravings around center table
	var center := Vector2(960.0, 528.0)
	var brass_dim := Color(0.85, 0.68, 0.36, 0.14)
	var brass_mid := Color(0.90, 0.74, 0.42, 0.22)
	var brass_bright := Color(0.96, 0.82, 0.48, 0.32)

	# Concentric circles
	var radii := [80.0, 140.0, 215.0, 310.0, 420.0, 540.0]
	for r in radii:
		draw_arc(center, r, 0.0, TAU, 96, brass_dim, 1.0, true)

	# Sub-arcs with higher brightness
	draw_arc(center, 215.0, 0.0, TAU, 96, brass_mid, 1.2, true)
	draw_arc(center, 310.0, 0.0, TAU, 96, brass_mid, 1.2, true)

	# Celestial Coordinate axes
	draw_line(center - Vector2(580, 0), center + Vector2(580, 0), brass_dim, 1.0, true)
	draw_line(center - Vector2(0, 260), center + Vector2(0, 260), brass_dim, 1.0, true)

	# 8-Point Compass Star Rays with tick marks
	for index in range(16):
		var angle := TAU * index / 16.0
		var dir := Vector2.from_angle(angle)
		var is_major := index % 2 == 0
		var r_start := 205.0 if is_major else 210.0
		var r_end := 225.0 if is_major else 220.0
		draw_line(center + dir * r_start, center + dir * r_end, brass_bright, 1.2, true)
		if is_major and index % 4 == 0:
			draw_circle(center + dir * 310.0, 3.0, brass_bright)

	# Player territory brass dividing rim line
	var line_y := 603.0
	if local_active:
		draw_line(Vector2(100, line_y), Vector2(size.x - 100, line_y), Color(0.96, 0.82, 0.44, 0.22), 4.0, true)
		draw_line(Vector2(100, line_y), Vector2(size.x - 100, line_y), Color(0.96, 0.82, 0.44, 0.85), 1.5, true)
		var mid_x := size.x * 0.5
		var diamond := PackedVector2Array([
			Vector2(mid_x, line_y - 6),
			Vector2(mid_x + 8, line_y),
			Vector2(mid_x, line_y + 6),
			Vector2(mid_x - 8, line_y)
		])
		draw_colored_polygon(diamond, Color(0.96, 0.82, 0.44, 0.9))
	else:
		draw_line(Vector2(100, line_y), Vector2(size.x - 100, line_y), Color(0.65, 0.52, 0.30, 0.35), 1.0, true)
