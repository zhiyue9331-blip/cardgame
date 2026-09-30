class_name DropZone
extends PanelContainer

@export var accepted_card_type := ""
@export var zone_title := "区域"

@onready var title_label: Label = $Content/ZoneTitle
@onready var content_label: Label = $Content/ZoneContent


func _ready() -> void:
	title_label.text = zone_title


func accepts(card_data: Dictionary) -> bool:
	return accepted_card_type.is_empty() or String(card_data.get("type", "")) == accepted_card_type


func contains_global_point(point: Vector2) -> bool:
	return get_global_rect().has_point(point)


func set_content(text: String) -> void:
	content_label.text = text


func pulse(success := true) -> void:
	var original := modulate
	var flash := Color("#9fe3b1") if success else Color("#ef8d8d")
	var tween := create_tween()
	tween.tween_property(self, "modulate", flash, 0.08)
	tween.tween_property(self, "modulate", original, 0.2)
