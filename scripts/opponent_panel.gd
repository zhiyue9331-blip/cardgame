class_name OpponentPanel
extends PanelContainer

const CARD_BACK_SCRIPT := preload("res://scripts/card_back.gd")
const HAND_CARD_SIZE := Vector2(76, 104)

var target_id := 1
var turn_active := false
var eliminated := false
var faction_tint := Color("#c6a56c")

@onready var target_head: PanelContainer = %TargetHead
@onready var player_name: Label = %PlayerName
@onready var hp_label: Label = %HpLabel
@onready var equipment_title: Label = $Margin/Root/TopRow/Equipment/Title
@onready var main_equipment: Label = %MainEquipmentText
@onready var sub_equipment: Label = %SubEquipmentText
@onready var main_stats: Label = %MainEquipmentStats
@onready var sub_stats: Label = %SubEquipmentStats
@onready var main_art: TextureRect = %MainEquipmentArt
@onready var sub_art: TextureRect = %SubEquipmentArt
@onready var main_slot: PanelContainer = %MainSlot
@onready var sub_slot: PanelContainer = %SubSlot
@onready var buffer_cards: HBoxContainer = %BufferCards
@onready var hand_count: Label = %HandCount
@onready var hand_cards: Control = %HandCards
@onready var cost_pips: Control = %CostPips


func _ready() -> void:
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	target_head.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for slot in [main_slot, sub_slot]:
		slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	player_name.clip_text = true
	player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Keep the fan below equipment within this seat, above the table background.
	hand_cards.z_index = 0
	hand_cards.get_parent().move_child(hand_cards, 0)
	hand_cards.resized.connect(_layout_hand_cards)


func setup(state: Dictionary) -> void:
	target_id = int(state.get("id", 1))
	update_state(state)

func set_turn_active(active: bool) -> void:
	turn_active = active
	queue_redraw()

func _draw() -> void:
	var gold := Color(0.72, 0.58, 0.32, 0.3)
	draw_line(Vector2(14, size.y - 2), Vector2(size.x - 14, size.y - 2), gold, 1.0, true)
	if turn_active:
		var portrait := target_head.get_node("HeadContent/Portrait") as Control
		var center := get_global_transform().affine_inverse() * portrait.get_global_rect().get_center()
		draw_arc(center, 33, 0, TAU, 64, Color("#e8c56e"), 1.5, true)
		draw_arc(center, 36, 0, TAU, 64, Color(0.96, 0.82, 0.42, 0.25), 4.0, true)


func update_state(state: Dictionary) -> void:
	eliminated = bool(state.get("eliminated", false))
	modulate = Color(0.58, 0.62, 0.64) if eliminated else Color.WHITE
	player_name.text = "%s%s" % [str(state.get("name", "玩家 %d" % (int(state.get("id", 1)) + 1))), "（已淘汰）" if eliminated else ""]
	player_name.tooltip_text = player_name.text
	var hp := int(state.get("hp", 12))
	hp_label.text = str(hp)
	hp_label.tooltip_text = "真血 %d / 12" % hp
	hp_label.add_theme_color_override("font_color", Color("#ff605b") if hp <= 3 else Color("#e96663"))
	var resonance: String = ["未共鸣", "共鸣", "深度共鸣"][clampi(int(state.get("resonance", 0)), 0, 2)]
	var faction := str(state.get("main_equipment", {}).get("faction", ""))
	var level := clampi(int(state.get("resonance", 0)), 0, 2)
	faction_tint = ResonanceSeal.tint_for(faction, level)
	var portrait := target_head.get_node("HeadContent/Portrait") as ResonanceSeal
	portrait.setup(faction, level)
	equipment_title.add_theme_color_override("font_color", faction_tint)
	queue_redraw()
	var plan: Dictionary = state.get("plan", {}) if state.get("plan", {}) is Dictionary else {}
	if plan.is_empty():
		equipment_title.text = "%s · %s" % [faction, resonance] if not faction.is_empty() else resonance
		equipment_title.tooltip_text = "公开装备共鸣：%s" % resonance
	else:
		var plan_name := str(plan.get("name", plan.get("card_id", "计划牌")))
		equipment_title.text = "%s · %s · 筹划：%s" % [faction if not faction.is_empty() else "装备", resonance, plan_name]
		equipment_title.tooltip_text = "公开计划：%s\n下个自己的回合兑现\n%s" % [plan_name, str(plan.get("description", plan.get("effect", "")))]
	_update_equipment_slot(main_slot, main_art, main_equipment, main_stats, state.get("main_equipment", {}), "主", resonance)
	_update_equipment_slot(sub_slot, sub_art, sub_equipment, sub_stats, state.get("sub_equipment", {}), "副", "")
	var count := int(state.get("hand", 0))
	hand_count.text = "%d 张" % count
	_update_hand_cards(count)
	cost_pips.tooltip_text = "剩余费用 %d · %s" % [int(state.get("cost", 0)), "反击次数已用" if bool(state.get("counter_used", false)) else "反击次数可用"]
	target_head.get_node("HeadContent/CostLabel").text = "费用 · 反击已用" if bool(state.get("counter_used", false)) else "费用 · 可反击"
	cost_pips.set_count(int(state.get("cost", 0)))
	_rebuild_buffer_cards(state.get("buffer_cards", []))


func head_center() -> Vector2:
	return target_head.get_global_rect().get_center()


func hand_center() -> Vector2:
	return hand_cards.get_global_rect().get_center()


func _update_hand_cards(count: int) -> void:
	hand_cards.tooltip_text = "手牌 %d 张" % count
	while hand_cards.get_child_count() > count:
		var card := hand_cards.get_child(hand_cards.get_child_count() - 1)
		hand_cards.remove_child(card)
		card.queue_free()
	while hand_cards.get_child_count() < count:
		var card := CARD_BACK_SCRIPT.new()
		card.size = HAND_CARD_SIZE
		card.pivot_offset = HAND_CARD_SIZE * 0.5
		hand_cards.add_child(card)
	_layout_hand_cards()


func _layout_hand_cards() -> void:
	var count := hand_cards.get_child_count()
	if count == 0:
		return
	var gap := minf(37.0, maxf(0.0, hand_cards.size.x - HAND_CARD_SIZE.x - 18.0) / maxf(1.0, count - 1.0))
	var start := (hand_cards.size.x - HAND_CARD_SIZE.x - gap * (count - 1)) * 0.5
	var middle := (count - 1) * 0.5
	for index in range(count):
		var card := hand_cards.get_child(index) as Control
		var spread := (index - middle) / maxf(1.0, middle)
		card.position = Vector2(start + index * gap, 8.0 + absf(spread) * 10.0)
		card.rotation = deg_to_rad(spread * 13.0)


func pulse_target() -> void:
	var original := target_head.modulate
	var tween := create_tween()
	tween.tween_property(target_head, "modulate", Color("#8df0ad"), 0.08)
	tween.tween_property(target_head, "modulate", original, 0.22)


func _equipment_name(data: Variant) -> String:
	if data is Dictionary and not data.is_empty():
		return str(data.get("name", "装备"))
	return "空"


func _update_equipment_slot(slot: PanelContainer, art: TextureRect, label: Label, stats: Label, data: Variant, slot_name: String, suffix: String) -> void:
	var occupied: bool = data is Dictionary and not data.is_empty()
	var empty := slot.get_node_or_null("Content/EmptySlotArt") as EmptyCardSlot
	if empty == null:
		empty = EmptyCardSlot.new()
		empty.name = "EmptySlotArt"
		empty.slot_kind = "main" if slot_name == "主" else "sub"
		slot.get_node("Content").add_child(empty)
		slot.get_node("Content").move_child(empty, 0)
		empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	empty.visible = not occupied
	label.text = "%s：%s" % [slot_name, _equipment_name(data)]
	var faction := str(data.get("faction", "")) if occupied else ""
	var qualifier := "" if slot_name == "主" else "备用 · "
	stats.text = "%s%s · %s费\nATK %d  DEF %d" % [qualifier, faction if not faction.is_empty() else "中立", str(data.get("cost", 0)), int(data.get("attack", 0)), int(data.get("defense", 0))] if occupied else ""
	# Equipment stats get their own dark metal strip below the artwork.
	stats.visible = false
	var stats_strip := slot.get_node_or_null("Content/StatsStrip") as HBoxContainer
	if stats_strip == null:
		stats_strip = HBoxContainer.new()
		stats_strip.name = "StatsStrip"
		stats_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stats_strip.alignment = BoxContainer.ALIGNMENT_CENTER
		stats_strip.add_theme_constant_override("separation", 6)
		slot.get_node("Content").add_child(stats_strip)
		stats_strip.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		stats_strip.offset_top = -31
		stats_strip.offset_bottom = -3
		var strip_back := ColorRect.new()
		strip_back.name = "StatsPlate"
		strip_back.color = Color("#14120fec")
		strip_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.get_node("Content").add_child(strip_back)
		slot.get_node("Content").move_child(strip_back, stats_strip.get_index())
		strip_back.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		strip_back.offset_top = -32
		strip_back.offset_bottom = 0
		for stat in ["attack", "defense"]:
			var icon := TextureRect.new()
			icon.texture = preload("res://cards/art/sword_icon.svg") if stat == "attack" else preload("res://cards/art/shield_icon.svg")
			icon.custom_minimum_size = Vector2(22, 22)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			stats_strip.add_child(icon)
			var value := Label.new()
			value.name = stat
			value.mouse_filter = Control.MOUSE_FILTER_IGNORE
			value.add_theme_font_size_override("font_size", 21)
			value.add_theme_color_override("font_color", Color("#faecd2"))
			stats_strip.add_child(value)
	stats_strip.visible = occupied
	slot.get_node("Content/StatsPlate").visible = occupied
	if occupied:
		stats_strip.get_node("attack").text = str(data.get("attack", 0))
		stats_strip.get_node("defense").text = str(data.get("defense", 0))
	label.visible = true
	label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	label.offset_left = 3
	label.offset_right = -3
	label.offset_top = 5
	label.offset_bottom = 29
	label.text = _equipment_name(data) if occupied else "%s：空" % slot_name
	label.add_theme_font_size_override("font_size", 16)
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var name_plate := slot.get_node_or_null("Content/NamePlate") as ColorRect
	if name_plate == null:
		name_plate = ColorRect.new()
		name_plate.name = "NamePlate"
		name_plate.color = Color("#ead8b5ed")
		name_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.get_node("Content").add_child(name_plate)
		slot.get_node("Content").move_child(name_plate, label.get_index())
		name_plate.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		name_plate.offset_left = 3
		name_plate.offset_right = -3
		name_plate.offset_top = 5
		name_plate.offset_bottom = 29
	name_plate.visible = occupied
	label.add_theme_color_override("font_color", Color("#21190f") if occupied else Color("#c6a56c"))
	label.add_theme_constant_override("outline_size", 0)
	art.texture = null
	var card_frame := slot.get_node_or_null("Content/CardFrame") as TextureRect
	if card_frame == null:
		card_frame = TextureRect.new()
		card_frame.name = "CardFrame"
		card_frame.texture = preload("res://assets/ui/antique-card-frame.png")
		card_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		card_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.get_node("Content").add_child(card_frame)
		card_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_frame.visible = occupied
	if occupied:
		var base_id := str(data.get("base_id", data.get("id", "")))
		var art_path := "res://cards/art/%s.png" % base_id
		if not base_id.is_empty() and ResourceLoader.exists(art_path):
			art.texture = load(art_path)
		var description := str(data.get("description", data.get("effect", "")))
		slot.tooltip_text = "%s%s\n%s\n%s" % [_equipment_name(data), " · " + suffix if not suffix.is_empty() else "", stats.text, description]
	else:
		slot.tooltip_text = "%s装备槽为空" % slot_name


func _rebuild_buffer_cards(cards: Variant) -> void:
	for child in buffer_cards.get_children():
		buffer_cards.remove_child(child)
		child.queue_free()
	if not cards is Array:
		cards = []
	for data in cards:
		var card_back := BufferCardChip.new()
		card_back.setup(data, 64.0)
		buffer_cards.add_child(card_back)
	for index in range(cards.size(), 4):
		var empty := EmptyCardSlot.new()
		empty.setup("buffer", Vector2(64, 90))
		buffer_cards.add_child(empty)
