class_name BufferCardChip
extends PanelContainer


func setup(data: Dictionary, chip_width: float = 70.0) -> void:
	custom_minimum_size = Vector2(chip_width, 70)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#d7e7ec")
	style.border_color = Color("#82b6d8")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 3
	style.content_margin_right = 3
	add_theme_stylebox_override("panel", style)
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	var artwork := TextureRect.new()
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var art_path := "res://cards/art/%s.png" % str(data.get("base_id", data.get("id", "")))
	artwork.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	artwork.visible = artwork.texture != null
	content.add_child(artwork)
	artwork.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var has_art := artwork.texture != null
	var name_strip := ColorRect.new()
	name_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_strip.color = Color(0.04, 0.07, 0.1, 0.76)
	name_strip.visible = has_art
	content.add_child(name_strip)
	name_strip.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_strip.offset_top = -22.0
	var name_label := Label.new()
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = str(data.get("name", "牌"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	name_label.add_theme_color_override("font_color", Color.WHITE if has_art else Color("#17202b"))
	name_label.add_theme_font_size_override("font_size", 9 if has_art else 11)
	name_label.z_index = 1
	if has_art:
		name_strip.add_child(name_label)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	else:
		content.add_child(name_label)
		name_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tooltip_text = "%s · %s · %s费\n%s" % [name_label.text, str(data.get("faction", "中立")), str(data.get("cost", 0)), str(data.get("description", ""))]


func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#172636")
	style.border_color = Color("#d9b65d")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	var label := Label.new()
	label.custom_minimum_size.x = 340
	label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_font_size_override("font_size", 16)
	label.text = for_text
	panel.add_child(label)
	return panel
