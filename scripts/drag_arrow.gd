class_name DragArrow
extends Control

var active := false
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var arrow_color := Color("#83e6a4")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_arrow(global_from: Vector2, global_to: Vector2, color := Color("#83e6a4")) -> void:
	active = true
	from_point = get_global_transform().affine_inverse() * global_from
	to_point = get_global_transform().affine_inverse() * global_to
	arrow_color = color
	queue_redraw()


func hide_arrow() -> void:
	active = false
	queue_redraw()


func _draw() -> void:
	if not active or from_point.distance_to(to_point) < 30.0:
		return
	var delta := to_point - from_point
	var normal := Vector2(-delta.y, delta.x).normalized()
	var bend := minf(115.0, delta.length() * 0.2)
	var control := (from_point + to_point) * 0.5 + normal * bend
	var points := PackedVector2Array()
	for index in range(25):
		var t := float(index) / 24.0
		var point := pow(1.0 - t, 2.0) * from_point + 2.0 * (1.0 - t) * t * control + pow(t, 2.0) * to_point
		points.append(point)
	draw_polyline(points, Color(arrow_color, 0.12), 16.0, true)
	draw_polyline(points, Color(0.01, 0.04, 0.03, 0.88), 7.0, true)
	draw_polyline(points, arrow_color, 3.0, true)
	for index in range(2, points.size() - 4, 4):
		draw_circle(points[index], 2.5, arrow_color.lightened(0.18))
	draw_arc(to_point, 20.0, 0.0, TAU, 40, Color(arrow_color, 0.6), 1.5, true)
	var direction := (to_point - points[points.size() - 3]).normalized()
	var side := Vector2(-direction.y, direction.x)
	var head := PackedVector2Array([
		to_point,
		to_point - direction * 34.0 + side * 18.0,
		to_point - direction * 25.0,
		to_point - direction * 34.0 - side * 18.0
	])
	draw_colored_polygon(head, arrow_color)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), Color("#173527"), 3.0, true)
