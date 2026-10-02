class_name EmptyCardSlot
extends Control

const SLOT := preload("res://assets/ui/empty-card-slot.png")
var slot_kind := "buffer"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

func setup(kind: String, bounds: Vector2 = Vector2(70, 90)) -> void:
	slot_kind = kind
	custom_minimum_size = bounds
	queue_redraw()

func _draw() -> void:
	var ratio := float(SLOT.get_width()) / SLOT.get_height()
	var height := minf(size.y, size.x / ratio)
	var bounds := Vector2(height * ratio, height)
	var rect := Rect2((size - bounds) * 0.5, bounds)
	draw_texture_rect(SLOT, rect, false, Color(1, 1, 1, 0.85))
	if slot_kind == "buffer":
		return
	var side := minf(bounds.x, bounds.y) * 0.3
	var center := size * 0.5
	draw_circle(center, side * 0.7, Color("#0d1014e8"))
	draw_arc(center, side * 0.72, 0, TAU, 40, Color("#685438"), 1.0, true)
	var ink := Color("#8c7755")
	if slot_kind == "main":
		draw_set_transform(center, -0.6, Vector2.ONE * side)
		draw_colored_polygon(PackedVector2Array([Vector2(-0.07, 0.16), Vector2(-0.07, -0.32), Vector2(0, -0.52), Vector2(0.07, -0.32), Vector2(0.07, 0.16)]), ink)
		draw_line(Vector2(-0.23, 0.16), Vector2(0.23, 0.16), ink, 0.065, true)
		draw_line(Vector2(0, 0.16), Vector2(0, 0.43), ink, 0.065, true)
		draw_set_transform(Vector2.ZERO)
	else:
		var shield := PackedVector2Array([Vector2(-0.35, -0.33), Vector2(0, -0.45), Vector2(0.35, -0.33), Vector2(0.29, 0.14), Vector2(0, 0.47), Vector2(-0.29, 0.14), Vector2(-0.35, -0.33)])
		for index in range(shield.size()):
			shield[index] = center + shield[index] * side
		draw_polyline(shield, ink, 1.4, true)
		draw_line(center + Vector2(0, -0.4) * side, center + Vector2(0, 0.34) * side, Color(ink, 0.55), 1, true)
