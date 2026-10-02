class_name DragArrow
extends Control

var active := false
var from_point := Vector2.ZERO
var to_point := Vector2.ZERO
var arrow_color := Color("#ffcf5c")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_arrow(global_from: Vector2, global_to: Vector2, color := Color("#ffcf5c")) -> void:
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
	# Warm golden bloom glow
	draw_polyline(points, Color(arrow_color, 0.22), 18.0, true)
	# Dark shadow underlay
	draw_polyline(points, Color(0.08, 0.06, 0.04, 0.85), 7.0, true)
	# Crisp core golden beam
	draw_polyline(points, arrow_color, 3.5, true)
	for index in range(2, points.size() - 4, 3):
		draw_circle(points[index], 2.8, arrow_color.lightened(0.35))
	draw_arc(to_point, 22.0, 0.0, TAU, 40, Color(arrow_color, 0.65), 1.5, true)
	var direction := (to_point - points[points.size() - 3]).normalized()
	var side := Vector2(-direction.y, direction.x)
	var head := PackedVector2Array([
		to_point,
		to_point - direction * 34.0 + side * 18.0,
		to_point - direction * 25.0,
		to_point - direction * 34.0 - side * 18.0
	])
	draw_colored_polygon(head, arrow_color)
	draw_polyline(PackedVector2Array([head[0], head[1], head[2], head[3], head[0]]), Color("#2b1e10"), 2.5, true)

	# Ornate parchment badge along the curve matching concept reference
	if delta.length() > 90.0:
		var mid_point := points[12] + normal * 14.0
		var badge_size := Vector2(110.0, 24.0)
		var badge_rect := Rect2(mid_point - badge_size * 0.5, badge_size)
		draw_rect(badge_rect, Color(0.10, 0.08, 0.06, 0.92), true)
		draw_rect(badge_rect, Color(0.85, 0.70, 0.38, 0.95), false, 1.2)
		var font := ThemeDB.fallback_font
		if font:
			draw_string(font, mid_point + Vector2(-42, 5), "选择攻击目标", HORIZONTAL_ALIGNMENT_CENTER, -1, 14, Color(0.98, 0.92, 0.80))
