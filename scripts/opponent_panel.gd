class_name OpponentPanel
extends PanelContainer

var target_id := 1
var turn_active := false

@onready var target_head: PanelContainer = %TargetHead
@onready var player_name: Label = %PlayerName
@onready var hp_label: Label = %HpLabel
@onready var equipment_title: Label = $Margin/Root/Equipment/Title
@onready var main_equipment: Label = %MainEquipmentText
@onready var sub_equipment: Label = %SubEquipmentText
@onready var main_art: TextureRect = %MainEquipmentArt
@onready var sub_art: TextureRect = %SubEquipmentArt
@onready var main_slot: PanelContainer = %MainSlot
@onready var sub_slot: PanelContainer = %SubSlot
@onready var buffer_cards: HBoxContainer = %BufferCards
@onready var hand_count: Label = %HandCount
@onready var cost_pips: Control = %CostPips


func setup(state: Dictionary) -> void:
	target_id = int(state.get("id", 1))
	update_state(state)

func set_turn_active(active: bool) -> void:
	turn_active = active
	queue_redraw()

func _draw() -> void:
	if turn_active:
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color(0.92, 0.76, 0.39, 0.92), false, 2.0)


func update_state(state: Dictionary) -> void:
	var eliminated := bool(state.get("eliminated", false))
	player_name.text = "%s%s" % [str(state.get("name", "玩家 %d" % (int(state.get("id", 1)) + 1))), "（已淘汰）" if eliminated else ""]
	hp_label.text = "真血 %d / 12" % int(state.get("hp", 12))
	if eliminated:
		hp_label.add_theme_color_override("font_color", Color("#ef765f"))
	var resonance: String = ["未共鸣", "共鸣", "深度共鸣"][clampi(int(state.get("resonance", 0)), 0, 2)]
	equipment_title.text = "装备 · %s" % resonance
	_update_equipment_slot(main_slot, main_art, main_equipment, state.get("main_equipment", {}), "主", resonance)
	_update_equipment_slot(sub_slot, sub_art, sub_equipment, state.get("sub_equipment", {}), "副", "")
	hand_count.text = str(int(state.get("hand", 0)))
	cost_pips.tooltip_text = "反击次数已用" if bool(state.get("counter_used", false)) else "反击次数可用"
	cost_pips.set_count(int(state.get("cost", 0)))
	_rebuild_buffer_cards(state.get("buffer_cards", []))


func head_center() -> Vector2:
	return target_head.get_global_rect().get_center()


func pulse_target() -> void:
	var original := target_head.modulate
	var tween := create_tween()
	tween.tween_property(target_head, "modulate", Color("#8df0ad"), 0.08)
	tween.tween_property(target_head, "modulate", original, 0.22)


func _equipment_name(data: Variant) -> String:
	if data is Dictionary and not data.is_empty():
		return str(data.get("name", "装备"))
	return "空"


func _update_equipment_slot(slot: PanelContainer, art: TextureRect, label: Label, data: Variant, slot_name: String, suffix: String) -> void:
	var occupied: bool = data is Dictionary and not data.is_empty()
	label.text = "%s：%s" % [slot_name, _equipment_name(data)]
	art.texture = null
	if occupied:
		var base_id := str(data.get("base_id", data.get("id", "")))
		var art_path := "res://cards/art/%s.png" % base_id
		if not base_id.is_empty() and ResourceLoader.exists(art_path):
			art.texture = load(art_path)
		var description := str(data.get("description", data.get("effect", "")))
		slot.tooltip_text = "%s%s\n%s" % [_equipment_name(data), " · " + suffix if not suffix.is_empty() else "", description]
	else:
		slot.tooltip_text = "%s装备槽为空" % slot_name


func _rebuild_buffer_cards(cards: Variant) -> void:
	for child in buffer_cards.get_children():
		child.queue_free()
	if not cards is Array or cards.is_empty():
		var empty := Label.new()
		empty.text = "—"
		empty.add_theme_color_override("font_color", Color("#7890a3"))
		buffer_cards.add_child(empty)
		return
	for data in cards:
		var card_back := BufferCardChip.new()
		card_back.setup(data, 43.0)
		buffer_cards.add_child(card_back)
