class_name DropZone
extends PanelContainer

@export var accepted_card_type := ""
@export var zone_title := "区域"

@onready var title_label: Label = $Content/ZoneTitle
@onready var content_label: Label = $Content/ZoneContent
var _empty_art: EmptyCardSlot


func _ready() -> void:
	title_label.text = zone_title
	if accepted_card_type == "装备牌":
		_empty_art = EmptyCardSlot.new()
		_empty_art.name = "EmptySlotArt"
		_empty_art.slot_kind = "main" if zone_title == "主装备" else "sub"
		add_child(_empty_art)
		move_child(_empty_art, 0)
		_empty_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		title_label.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_label.get_parent().alignment = BoxContainer.ALIGNMENT_BEGIN
		title_label.get_parent().add_theme_constant_override("separation", 0)
		title_label.get_parent().z_index = 1


func accepts(card_data: Dictionary) -> bool:
	return accepted_card_type.is_empty() or String(card_data.get("type", "")) == accepted_card_type


func contains_global_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func set_content(text: String) -> void:
	content_label.text = "" if _empty_art else text
	if _empty_art:
		_empty_art.visible = text == "—"


func pulse(success := true) -> void:
	var original := modulate
	var flash := Color("#9fe3b1") if success else Color("#ef8d8d")
	var tween := create_tween()
	tween.tween_property(self, "modulate", flash, 0.08)
	tween.tween_property(self, "modulate", original, 0.2)
