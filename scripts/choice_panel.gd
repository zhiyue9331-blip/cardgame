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

var _board: Control
var _pending: Dictionary = {}
var _inspected: Array = []
var _local_slot := 0
var _busy := false


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
	public_inspection = PanelContainer.new()
	public_inspection.visible = false
	public_inspection.position = Vector2(570, 390)
	public_inspection.size = Vector2(780, 130)
	public_inspection.z_index = 120
	public_inspection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	public_inspection.add_theme_stylebox_override("panel", choice_style)
	_board.add_child(public_inspection)
	public_inspection_text = Label.new()
	public_inspection_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	public_inspection_text.add_theme_font_size_override("font_size", 20)
	public_inspection_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	public_inspection.add_child(public_inspection_text)

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
	choice_scroll.custom_minimum_size = Vector2(0, 190)
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(choice_scroll)
	buttons = VBoxContainer.new()
	buttons.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_theme_constant_override("separation", 5)
	choice_scroll.add_child(buttons)
	footer = VBoxContainer.new()
	content.add_child(footer)


func render(pending: Dictionary, inspected: Array, local_slot: int, busy: bool) -> void:
	_pending = pending
	_inspected = inspected
	_local_slot = local_slot
	_busy = busy
	if panel == null or not is_instance_valid(panel):
		return
	_clear(footer)
	_clear(buttons)
	public_inspection.hide()
	if pending.is_empty():
		panel.visible = false
		return
	if int(pending.get("slot", -1)) != local_slot:
		# 本地玩家无需操作时由顶部状态栏说明当前等待对象，避免遮挡棋盘。
		panel.visible = false
		if not inspected.is_empty():
			var names: PackedStringArray = []
			for card in inspected: names.append(str(card.get("name", "卡牌")))
			public_inspection_text.text = "玩家 %d · 公开检视\n%s\n正在完成选牌 / 排序" % [int(pending.slot) + 1, "、".join(names)]
			public_inspection.show()
		return
	panel.visible = true
	title.text = str(pending.get("title", "请选择"))
	var pending_kind := str(pending.get("kind", ""))
	hint.visible = true
	hint.text = str(pending.get("hint", "完成选择后继续结算"))
	if pending_kind == "buffer":
		hint.text = "缓冲：用手牌抵消伤害；每张牌抵消1点，未抵消部分扣除真血。"
	elif pending_kind == "counter":
		hint.text = "反击在受到攻击或效果时触发，不占自己的回合；反击会消耗1费用。"
	if not _inspected.is_empty():
		var names: PackedStringArray = []
		for revealed in _inspected:
			names.append(str(revealed.name))
		hint.text += "\n公开检视：" + "、".join(names)
	var cards: Array = pending.get("cards", [])
	if not cards.is_empty():
		for card in cards:
			var card_button := Button.new()
			var card_id := str(card.get("id", ""))
			var faction := str(card.get("faction", ""))
			var order_mark := "%d. " % (selected_card_ids.find(card_id) + 1) if card_id in selected_card_ids else ""
			card_button.text = "%s%s%s · %s" % [order_mark, "✓ " if card_id in selected_card_ids else "", str(card.get("name", card_id)), faction]
			card_button.add_theme_font_size_override("font_size", 20)
			card_button.custom_minimum_size.y = 42
			card_button.tooltip_text = str(card.get("description", card.get("effect", "")))
			card_button.disabled = busy
			card_button.toggle_mode = true
			card_button.button_pressed = card_id in selected_card_ids
			card_button.pressed.connect(toggle_card.bind(card_id))
			buttons.add_child(card_button)
		var count_label := Label.new()
		if str(pending.get("kind", "")) == "buffer":
			count_label.text = "已选 %d 张 · 最多可缓冲 %d 点（可选 0 张承担伤害）" % [selected_card_ids.size(), int(pending.get("max", cards.size()))]
		else:
			count_label.text = "已选 %d 张（要求 %d～%d，按点击顺序提交）" % [selected_card_ids.size(), int(pending.get("min", 0)), int(pending.get("max", cards.size()))]
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		footer.add_child(count_label)
		var confirm := Button.new()
		confirm.text = "确认缓冲" if str(pending.get("kind", "")) == "buffer" else "确认选择"
		confirm.custom_minimum_size.y = 44
		confirm.add_theme_font_size_override("font_size", 20)
		confirm.disabled = selected_card_ids.size() < int(pending.get("min", 0)) or busy
		confirm.pressed.connect(_confirm_cards)
		footer.add_child(confirm)
		return
	for option in pending.get("options", []):
		var button := Button.new()
		button.text = str(option.get("label", option.get("id", "选择")))
		button.disabled = busy
		button.pressed.connect(choose_option.bind(str(option.get("id", ""))))
		buttons.add_child(button)


func open_effect_branch(data: Dictionary, base_action: Dictionary, enhanced_action: Dictionary, legal_actions: Array = [], resonating: bool = false) -> void:
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
	var effect_hint := Label.new()
	effect_hint.text = "共鸣强化需要额外代价，请选择本次打出的分支。" if resonating else "这张牌可以支付额外代价，请选择本次分支。"
	effect_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect_hint.add_theme_color_override("font_color", Color("#d7e4ee"))
	box.add_child(effect_hint)
	for action in [base_action, enhanced_action]:
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
	for legal in legal_actions:
		if str(legal.get("type", "")) != "effect":
			continue
		if str(legal.get("card_id", "")) != str(action.get("card_id", "")):
			continue
		if int(legal.get("target_slot", -1)) != int(action.get("target_slot", -2)):
			continue
		var same_upgrade := bool(legal.get("options", {}).get("enhanced", false)) == bool(action.get("options", {}).get("enhanced", false))
		if same_upgrade:
			return str(legal.get("label", "使用"))
	return "使用"


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
	elif selected_card_ids.size() < maximum:
		selected_card_ids.append(card_id)
	render(_pending, _inspected, _local_slot, _busy)


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
