extends Node

## Rules choice and effect branch UI extracted from GameController.
## The host supplies state and handles action_requested; this node owns no game logic.

signal action_requested(action: Dictionary)
signal effect_branch_closed

var panel: PanelContainer
var title: Label
var hint: Label
var buttons: VBoxContainer
var footer: VBoxContainer
var effect_panel: PanelContainer
var selected_card_ids: Array[String] = []
var public_inspection: PanelContainer
var public_inspection_text: Label
var public_inspection_cards: HBoxContainer

var _board: Control
var _pending: Dictionary = {}
var _inspected: Array = []
var _local_slot := 0
var _busy := false
var _card_nodes: Dictionary = {}
var _choice_scroll: ScrollContainer

func _input(event: InputEvent) -> void:
	if panel == null or not panel.is_visible_in_tree() or not event is InputEventMouseButton: return
	if not event.pressed or event.button_index not in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]: return
	var point: Vector2 = _choice_scroll.get_global_transform_with_canvas().affine_inverse() * event.position
	if not Rect2(Vector2.ZERO, _choice_scroll.size).has_point(point): return
	# Handle the list's wheel before card buttons/tooltips process GUI input.
	var bar := _choice_scroll.get_v_scroll_bar()
	var direction := 1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1
	bar.value += direction * 60.0 * event.factor
	get_viewport().set_input_as_handled()


func setup(board: Control) -> void:
	_board = board
	if panel != null and is_instance_valid(panel):
		return
	panel = PanelContainer.new()
	panel.name = "RulesChoicePanel"
	panel.visible = false
	panel.z_index = 180
	panel.position = Vector2(570, 270)
	panel.size = Vector2(780, 390)
	var choice_style := StyleBoxFlat.new()
	choice_style.bg_color = Color("#102425")
	choice_style.border_color = Color("#a48d5d")
	choice_style.set_border_width_all(1)
	choice_style.set_corner_radius_all(12)
	choice_style.shadow_color = Color(0, 0, 0, 0.45)
	choice_style.shadow_size = 20
	choice_style.content_margin_left = 16
	choice_style.content_margin_right = 16
	choice_style.content_margin_top = 14
	choice_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", choice_style)
	_board.add_child(panel)
	panel.minimum_size_changed.connect(_fit_choice_panel)
	public_inspection = PanelContainer.new()
	public_inspection.visible = false
	public_inspection.position = Vector2(570, 390)
	public_inspection.size = Vector2(780, 188)
	public_inspection.z_index = 120
	public_inspection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	public_inspection.add_theme_stylebox_override("panel", choice_style)
	_board.add_child(public_inspection)
	var public_box := VBoxContainer.new()
	public_box.add_theme_constant_override("separation", 4)
	public_inspection.add_child(public_box)
	public_inspection_text = Label.new()
	public_inspection_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_inspection_text.add_theme_font_size_override("font_size", 20)
	public_inspection_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	public_box.add_child(public_inspection_text)
	public_inspection_cards = HBoxContainer.new()
	public_inspection_cards.add_theme_constant_override("separation", 10)
	public_inspection_cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	public_box.add_child(public_inspection_cards)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)
	title = Label.new()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.add_theme_font_size_override("font_size", 22)
	content.add_child(title)
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)
	var choice_scroll := ScrollContainer.new()
	_choice_scroll = choice_scroll
	choice_scroll.custom_minimum_size = Vector2(0, 190)
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_bar := choice_scroll.get_v_scroll_bar()
	scroll_bar.custom_minimum_size.x = 18
	var scroll_track := StyleBoxFlat.new()
	scroll_track.bg_color = Color("#0a1d20")
	scroll_track.set_corner_radius_all(6)
	scroll_track.content_margin_left = 9
	scroll_track.content_margin_right = 9
	scroll_bar.add_theme_stylebox_override("scroll", scroll_track)
	var scroll_thumb := StyleBoxFlat.new()
	scroll_thumb.bg_color = Color("#b8a16b")
	scroll_thumb.set_corner_radius_all(6)
	scroll_bar.add_theme_stylebox_override("grabber", scroll_thumb)
	scroll_bar.add_theme_stylebox_override("grabber_highlight", scroll_thumb)
	scroll_bar.add_theme_stylebox_override("grabber_pressed", scroll_thumb)
	content.add_child(choice_scroll)
	buttons = VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 5)
	choice_scroll.add_child(buttons)
	footer = VBoxContainer.new()
	content.add_child(footer)


func render(pending: Dictionary, inspected: Array, local_slot: int, busy: bool) -> void:
	var same_choice := pending == _pending
	_pending = pending
	_inspected = inspected
	_local_slot = local_slot
	_busy = busy
	if panel == null or not is_instance_valid(panel):
		return
	var scroll_position := Vector2i(_choice_scroll.scroll_horizontal, _choice_scroll.scroll_vertical) if same_choice else Vector2i.ZERO
	_clear(footer)
	_clear(buttons)
	_clear(public_inspection_cards)
	_choice_scroll.set_deferred("scroll_horizontal", scroll_position.x)
	_choice_scroll.set_deferred("scroll_vertical", scroll_position.y)
	_card_nodes.clear()
	public_inspection.hide()
	if pending.is_empty():
		panel.visible = false
		return
	if int(pending.get("slot", -1)) != local_slot:
		# 本地玩家无需操作时由顶部状态栏说明当前等待对象，避免遮挡棋盘。
		panel.visible = false
		var visible_cards: Array = inspected
		if visible_cards.is_empty() and str(pending.get("kind", "")) in ["inspect_pick", "prepare_pick"]:
			visible_cards = pending.get("cards", [])
		if not visible_cards.is_empty():
			var names: PackedStringArray = []
			for card in visible_cards: names.append(str(card.get("name", "卡牌")))
			public_inspection_text.text = "玩家 %d · 公开检视：%s" % [int(pending.slot) + 1, "、".join(names)]
			for card in visible_cards:
				var preview := _make_card_preview(card, Vector2(112, 122))
				public_inspection_cards.add_child(preview)
				_card_nodes[str(card.get("id", ""))] = preview
			public_inspection.show()
		return
	panel.visible = true
	title.text = str(pending.get("title", "请选择"))
	var pending_kind := str(pending.get("kind", ""))
	var art_cards := pending_kind == "prepare_pick" or (pending_kind not in ["buffer", "counter"] and not _inspected.is_empty())
	_fit_choice_panel()
	hint.visible = true
	hint.text = str(pending.get("hint", "完成选择后继续结算"))
	if pending_kind == "buffer":
		hint.text = "缓冲：用手牌抵消伤害；每张牌抵消1点，未抵消部分扣除真血。"
	elif pending_kind == "counter":
		hint.text = "反击在受到攻击或效果时触发，不占自己的回合；反击会消耗1费用。"
	elif pending_kind == "plan_target":
		hint.text = "计划兑现：请选择当前仍存活的合法目标，选择后继续结算。"
	if not _inspected.is_empty():
		var names: PackedStringArray = []
		for revealed in _inspected:
			names.append(str(revealed.name))
		hint.text += "\n公开检视：" + "、".join(names)
	var cards: Array = pending.get("cards", [])
	if not cards.is_empty():
		if not art_cards:
			var card_list := GridContainer.new()
			card_list.columns = 2
			card_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			card_list.add_theme_constant_override("h_separation", 8)
			card_list.add_theme_constant_override("v_separation", 5)
			buttons.add_child(card_list)
			for card in cards:
				var card_button := _make_compact_choice_card(card, busy)
				var card_id := str(card.get("id", ""))
				card_button.button_pressed = card_id in selected_card_ids
				card_button.pressed.connect(toggle_card.bind(card_id))
				card_list.add_child(card_button)
				_card_nodes[card_id] = card_button
			var count_label := _make_count_label(pending, cards)
			footer.add_child(count_label)
			var confirm := _make_confirm_button(pending, busy)
			footer.add_child(confirm)
			return
		var card_row := GridContainer.new()
		card_row.columns = 3
		card_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_row.add_theme_constant_override("h_separation", 10)
		card_row.add_theme_constant_override("v_separation", 10)
		buttons.add_child(card_row)
		for card in cards:
			var card_button := _make_choice_card(card, busy)
			var card_id := str(card.get("id", ""))
			card_button.tooltip_text = str(card.get("description", card.get("effect", "")))
			card_button.button_pressed = card_id in selected_card_ids
			card_button.pressed.connect(toggle_card.bind(card_id))
			card_row.add_child(card_button)
			_card_nodes[card_id] = card_button
		footer.add_child(_make_count_label(pending, cards))
		footer.add_child(_make_confirm_button(pending, busy))
		return
	for option in pending.get("options", []):
		var button := Button.new()
		button.text = str(option.get("label", option.get("id", "选择")))
		button.disabled = busy
		button.pressed.connect(choose_option.bind(str(option.get("id", ""))))
		buttons.add_child(button)


func _fit_choice_panel() -> void:
	var kind := str(_pending.get("kind", ""))
	var art_cards := kind == "prepare_pick" or (kind not in ["buffer", "counter"] and not _inspected.is_empty())
	var height := 490.0 if not _pending.get("cards", []).is_empty() else 390.0
	if art_cards:
		var rows := ceili(_pending.get("cards", []).size() / 3.0)
		height = clampf(180.0 + rows * 198.0, 490.0, 760.0)
	panel.size = Vector2(780, height)
	panel.position = (_board.size - panel.size) * 0.5


func _make_choice_card(card: Dictionary, busy: bool) -> Button:
	var card_button := Button.new()
	card_button.custom_minimum_size = Vector2(142, 188)
	card_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_button.toggle_mode = true
	card_button.disabled = busy
	card_button.add_theme_font_size_override("font_size", 17)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 4)
	card_button.add_child(box)
	card_button.set_meta("card_data", card)
	box.add_child(_make_card_preview(card, Vector2(132, 150)))
	var name_label := Label.new()
	var card_id := str(card.get("id", ""))
	var order_mark := "%d. " % (selected_card_ids.find(card_id) + 1) if card_id in selected_card_ids else ""
	name_label.text = "%s%s%s" % [order_mark, "✓ " if card_id in selected_card_ids else "", str(card.get("name", card.get("id", "卡牌")))]
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(name_label)
	card_button.set_meta("selection_label", name_label)
	return card_button


func _make_compact_choice_card(card: Dictionary, busy: bool) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(0, 94)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.toggle_mode = true
	button.disabled = busy
	button.set_meta("card_data", card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	button.add_child(row)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_right = -4
	var preview := BufferCardChip.new()
	preview.setup(card, 70)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	button.tooltip_text = preview.tooltip_text
	var info := VBoxContainer.new()
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)
	var label := Label.new()
	var id := str(card.get("id", ""))
	var order_mark := "%d. ✓ " % (selected_card_ids.find(id) + 1) if id in selected_card_ids else ""
	label.text = order_mark + str(card.get("name", id))
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", 19)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(label)
	button.set_meta("selection_label", label)
	var fields := Label.new()
	var faction := str(card.get("faction", ""))
	var card_type := "反击" if card.get("subtype") == "counter" else str(card.get("type", "卡牌"))
	fields.text = "%s · %s · %s费" % [faction if not faction.is_empty() else "中立", card_type, str(card.get("cost", 0))]
	fields.add_theme_font_size_override("font_size", 14)
	fields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(fields)
	var detail := Label.new()
	detail.text = "ATK %d  DEF %d · " % [int(card.get("attack", 0)), int(card.get("defense", 0))] if card.get("type") == "装备牌" else ""
	detail.text += str(card.get("description", card.get("effect", "")))
	detail.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	detail.max_lines_visible = 2
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.add_theme_font_size_override("font_size", 14)
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_child(detail)
	return button


func card_global_center(card_id: String) -> Vector2:
	var card_node: Control = _card_nodes.get(card_id)
	if is_instance_valid(card_node): return card_node.get_global_rect().get_center()
	return Vector2.ZERO


func _make_count_label(pending: Dictionary, cards: Array) -> Label:
	var count_label := Label.new()
	if str(pending.get("kind", "")) == "buffer":
		count_label.text = "已选 %d 张 · 最多可缓冲 %d 点（可选 0 张承担伤害）" % [selected_card_ids.size(), int(pending.get("max", cards.size()))]
	else:
		count_label.text = "已选 %d 张（要求 %d～%d，按点击顺序提交）" % [selected_card_ids.size(), int(pending.get("min", 0)), int(pending.get("max", cards.size()))]
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return count_label


func _make_confirm_button(pending: Dictionary, busy: bool) -> Button:
	var confirm := Button.new()
	confirm.text = "确认缓冲" if str(pending.get("kind", "")) == "buffer" else "确认选择"
	confirm.custom_minimum_size.y = 44
	confirm.add_theme_font_size_override("font_size", 20)
	confirm.disabled = selected_card_ids.size() < int(pending.get("min", 0)) or busy
	confirm.pressed.connect(_confirm_cards)
	return confirm


func _make_card_preview(card: Dictionary, preview_size: Vector2) -> Control:
	var preview := (preload("res://ui/card_thumbnail.tscn") as PackedScene).instantiate() as CardThumbnail
	preview.custom_minimum_size = preview_size
	preview.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.setup(card)
	return preview


func open_effect_branch(data: Dictionary, base_action: Dictionary, enhanced_action: Dictionary, legal_actions: Array = [], resonating: bool = false, plan_actions: Array = []) -> void:
	close_effect_branch()
	if _board == null:
		return
	effect_panel = PanelContainer.new()
	effect_panel.name = "EffectBranchPanel"
	effect_panel.z_index = 190
	effect_panel.position = Vector2(520, 300)
	effect_panel.custom_minimum_size = Vector2(880, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102425")
	style.border_color = Color("#a48d5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 20
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	effect_panel.add_theme_stylebox_override("panel", style)
	_board.add_child(effect_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	effect_panel.add_child(box)
	var effect_title := Label.new()
	effect_title.text = str(data.get("name", "效果牌"))
	effect_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_title.add_theme_font_size_override("font_size", 24)
	effect_title.add_theme_color_override("font_color", Color("#efd9a0"))
	box.add_child(effect_title)
	box.add_child(_make_card_preview(data, Vector2(142, 170)))
	var effect_hint := Label.new()
	if not plan_actions.is_empty():
		effect_hint.text = "立即使用，或支付牌面费用筹划，在下个自己的回合兑现。"
	else:
		effect_hint.text = "共鸣强化需要额外代价，请选择本次打出的分支。" if resonating else "这张牌可以支付额外代价，请选择本次分支。"
	effect_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_hint.add_theme_color_override("font_color", Color("#d7e4ee"))
	box.add_child(effect_hint)
	var branch_actions: Array = []
	for action in [base_action, enhanced_action] + plan_actions:
		if not action.is_empty():
			branch_actions.append(action)
	for action in branch_actions:
		var button := Button.new()
		button.text = effect_action_label(action, legal_actions)
		button.custom_minimum_size = Vector2(820, 46)
		button.add_theme_font_size_override("font_size", 20)
		button.pressed.connect(_submit_effect.bind(action.duplicate(true)))
		box.add_child(button)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.custom_minimum_size.y = 40
	cancel.pressed.connect(close_effect_branch)
	box.add_child(cancel)


func effect_action_label(action: Dictionary, legal_actions: Array) -> String:
	var action_type := str(action.get("type", "effect"))
	for legal in legal_actions:
		if str(legal.get("type", "")) != action_type:
			continue
		if str(legal.get("card_id", "")) != str(action.get("card_id", "")):
			continue
		if action_type == "effect" and int(legal.get("target_slot", -1)) != int(action.get("target_slot", -2)):
			continue
		var same_upgrade := bool(legal.get("options", {}).get("enhanced", false)) == bool(action.get("options", {}).get("enhanced", false))
		if same_upgrade:
			return str(legal.get("label", "筹划" if action_type == "plan" else "使用"))
	return "筹划" if action_type == "plan" else "使用"


func close_effect_branch() -> void:
	if effect_panel != null and is_instance_valid(effect_panel):
		effect_panel.queue_free()
		effect_panel = null
		effect_branch_closed.emit()


func reset() -> void:
	close_effect_branch()
	selected_card_ids.clear()
	render({}, [], _local_slot, false)


func toggle_card(card_id: String) -> void:
	var maximum := int(_pending.get("max", 1))
	if card_id in selected_card_ids:
		selected_card_ids.erase(card_id)
	elif maximum == 1:
		selected_card_ids.clear()
		selected_card_ids.append(card_id)
	elif selected_card_ids.size() < maximum:
		selected_card_ids.append(card_id)
	# 保留正在点击的按钮和滚动区域，避免重建控件打断鼠标操作。
	for id in _card_nodes:
		var button := _card_nodes[id] as Button
		if not button: continue
		var card: Dictionary = button.get_meta("card_data")
		var order_mark := "%d. ✓ " % (selected_card_ids.find(id) + 1) if id in selected_card_ids else ""
		button.set_pressed_no_signal(id in selected_card_ids)
		if button.has_meta("selection_label"):
			var label: Label = button.get_meta("selection_label")
			label.text = order_mark + str(card.get("name", id))
		else:
			button.text = "%s%s · %s" % [order_mark, str(card.get("name", id)), str(card.get("faction", ""))]
	var count_label := footer.get_child(0) as Label
	if _pending.get("kind", "") == "buffer":
		count_label.text = "已选 %d 张 · 最多可缓冲 %d 点（可选 0 张承担伤害）" % [selected_card_ids.size(), int(_pending.get("max", 1))]
	else:
		count_label.text = "已选 %d 张（要求 %d～%d，按点击顺序提交）" % [selected_card_ids.size(), int(_pending.get("min", 0)), maximum]
	(footer.get_child(1) as Button).disabled = selected_card_ids.size() < int(_pending.get("min", 0)) or _busy


func _confirm_cards() -> void:
	var ids := selected_card_ids.duplicate()
	selected_card_ids.clear()
	action_requested.emit({"type": "choose", "card_ids": ids, "option": ""})


func choose_option(option_id: String) -> void:
	selected_card_ids.clear()
	action_requested.emit({"type": "choose", "option": option_id, "card_ids": []})


func _submit_effect(action: Dictionary) -> void:
	close_effect_branch()
	var clean := action.duplicate(true)
	clean.erase("label")
	clean.erase("description")
	clean.erase("disabled")
	action_requested.emit(clean)


func _clear(container: Container) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()
