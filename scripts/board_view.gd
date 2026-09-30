class_name BoardView
extends Node

## 棋盘节点与卡牌显示；只接收显示数据，通过信号转交交互。
signal hand_drop_requested(card: DraggableCard, position: Vector2)
signal hand_drag_started(card: DraggableCard)
signal hand_drag_updated(card: DraggableCard, position: Vector2)
signal equipment_drop_requested(card: DraggableCard, position: Vector2)
signal equipment_drag_started(card: DraggableCard)
signal equipment_drag_updated(card: DraggableCard, position: Vector2)

const EQUIPMENT_CARD_SCENE := preload("res://cards/equipment_card.tscn")
const EFFECT_CARD_SCENE := preload("res://cards/effect_card.tscn")
const OPPONENT_PANEL_SCENE := preload("res://ui/opponent_panel.tscn")
const CARD_THUMBNAIL_SCENE := preload("res://ui/card_thumbnail.tscn")

var hand_zone: HandZone
var deck_zone: PileZone
var equipped_layer: Control
var discard_card_flow: HFlowContainer
var opponent_cards: HBoxContainer
var my_buffer_cards: HBoxContainer
var log_entry_list: VBoxContainer
var resonance_mark: Label
var detail_parent: Control
var opponent_panels: Array[Node] = []
var _card_detail_panel: PanelContainer
var _card_detail_label: Label
var _hovered_card: DraggableCard

func setup(controls: Dictionary) -> void:
	hand_zone = controls.hand_zone
	deck_zone = controls.deck_zone
	equipped_layer = controls.equipped_layer
	discard_card_flow = controls.discard_card_flow
	opponent_cards = controls.opponent_cards
	my_buffer_cards = controls.my_buffer_cards
	log_entry_list = controls.log_entry_list
	resonance_mark = controls.resonance_mark
	detail_parent = controls.detail_parent
	_build_card_detail_panel()


func create_card(card_data: Dictionary) -> void:
	var scene: PackedScene = EQUIPMENT_CARD_SCENE if card_data.get("type") == "装备牌" else EFFECT_CARD_SCENE
	var card := scene.instantiate() as DraggableCard
	card.drop_requested.connect(hand_drop_requested.emit)
	card.drag_started.connect(hand_drag_started.emit)
	card.drag_updated.connect(hand_drag_updated.emit)
	card.hover_changed.connect(_on_card_hover_changed)
	hand_zone.add_card(card, deck_zone.get_global_rect().get_center())
	card.setup(card_data)


func clear_board() -> void:
	hand_zone.clear_cards()
	_hovered_card = null
	_card_detail_panel.hide()
	opponent_panels.clear()
	for container in [equipped_layer, opponent_cards, my_buffer_cards, log_entry_list, discard_card_flow]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()


func _build_card_detail_panel() -> void:
	_card_detail_panel = PanelContainer.new()
	_card_detail_panel.position = Vector2(1060, 28)
	_card_detail_panel.size = Vector2(510, 234)
	_card_detail_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#102425")
	style.border_color = Color("#a48d5d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 12
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_card_detail_panel.add_theme_stylebox_override("panel", style)
	_card_detail_label = Label.new()
	_card_detail_label.custom_minimum_size = Vector2(474, 200)
	_card_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_detail_label.add_theme_color_override("font_color", Color.WHITE)
	_card_detail_label.add_theme_font_size_override("font_size", 18)
	_card_detail_panel.add_child(_card_detail_label)
	detail_parent.add_child(_card_detail_panel)
	_card_detail_panel.visible = false


func _on_card_hover_changed(card: DraggableCard, hovered: bool) -> void:
	if hovered:
		_hovered_card = card
		var data := card.card_data
		_card_detail_label.text = "%s\n\n%s" % [str(data.get("name", "")), str(data.get("description", ""))]
		_card_detail_panel.visible = true
	elif _hovered_card == card:
		_hovered_card = null
		_card_detail_panel.visible = false


func ensure_equipped_card(current: DraggableCard, data: Dictionary, slot: String) -> DraggableCard:
	if data.is_empty():
		if is_instance_valid(current):
			current.queue_free()
		return null
	if is_instance_valid(current) and current.card_data.get("id") == data.get("id"):
		current.set_meta("equipment_slot", slot)
		current.set_home(_equipment_home(slot), true)
		current.set_interaction_enabled(true)
		return current
	if is_instance_valid(current):
		current.queue_free()
	var equipped := EQUIPMENT_CARD_SCENE.instantiate() as DraggableCard
	equipped_layer.add_child(equipped)
	equipped.setup(data)
	equipped.set_meta("equipment_slot", slot)
	equipped.set_rest_scale(Vector2(0.6, 0.6))
	equipped.set_home(_equipment_home(slot), false)
	equipped.drop_requested.connect(equipment_drop_requested.emit)
	equipped.drag_started.connect(equipment_drag_started.emit)
	equipped.drag_updated.connect(equipment_drag_updated.emit)
	equipped.hover_changed.connect(_on_card_hover_changed)
	equipped.set_interaction_enabled(true)
	return equipped


func _equipment_home(slot: String) -> Vector2:
	var center := Vector2(470.0, 82.0) if slot == "main" else Vector2(670.0, 82.0)
	return center - Vector2(71.0, 94.0)


func refresh_discard(discard: Array) -> void:
	for child in discard_card_flow.get_children():
		discard_card_flow.remove_child(child)
		child.queue_free()
	for data in discard:
		var thumbnail := CARD_THUMBNAIL_SCENE.instantiate() as CardThumbnail
		discard_card_flow.add_child(thumbnail)
		thumbnail.setup(data)


func render_opponents(opponents: Array) -> void:
	for index in range(mini(opponent_panels.size(), opponents.size())):
		opponent_panels[index].update_state(opponents[index])


func rebuild_opponents(opponents: Array) -> void:
	for child in opponent_cards.get_children():
		opponent_cards.remove_child(child)
		child.queue_free()
	opponent_panels.clear()
	for state in opponents:
		var panel: Node = OPPONENT_PANEL_SCENE.instantiate()
		opponent_cards.add_child(panel)
		panel.setup(state)
		opponent_panels.append(panel)


func render_buffer(my_buffer: Array) -> void:
	for child in my_buffer_cards.get_children():
		my_buffer_cards.remove_child(child)
		child.queue_free()
	for data in my_buffer:
		var card_chip := BufferCardChip.new()
		card_chip.setup(data)
		my_buffer_cards.add_child(card_chip)


func add_game_log(message: String) -> void:
	if not message.begins_with("玩家"):
		return
	var label := Label.new()
	label.custom_minimum_size = Vector2(0, 34)
	label.text = message
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", Color("#d7e2ea"))
	label.add_theme_font_size_override("font_size", 17)
	log_entry_list.add_child(label)
	_trim_log_entries()


func _trim_log_entries() -> void:
	while log_entry_list.get_child_count() > 30:
		var oldest := log_entry_list.get_child(0)
		log_entry_list.remove_child(oldest)
		oldest.queue_free()


func render_resonance(faction: String, level: int) -> void:
	var clamped := clampi(level, 0, 2)
	var marks: PackedStringArray = ["○○", "●○", "●●"]
	var words: PackedStringArray = ["未共鸣", "共鸣", "深度共鸣"]
	var colors: Array[Color] = [Color("#7890a3"), Color("#efb26a"), Color("#8df0ad")]
	var mark := marks[clamped]
	var word := words[clamped]
	resonance_mark.visible = true
	resonance_mark.text = "%s  %s" % [mark, word] if faction.is_empty() else "%s  %s · %s" % [mark, faction, word]
	resonance_mark.add_theme_color_override("font_color", colors[clamped])
	if faction.is_empty():
		resonance_mark.tooltip_text = "没有主装备，当前未共鸣。"
	else:
		resonance_mark.tooltip_text = "主装备为%s。副装备与缓冲区中，不同名的同体系牌达到 1 张为共鸣，达到 2 张为深度共鸣。" % faction
