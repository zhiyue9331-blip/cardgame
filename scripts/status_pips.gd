class_name StatusPips
extends Control

const GEM := preload("res://assets/ui/cost-pip-gem.png")
@export var capacity := 3
@export var show_count := false

@export var count := 0:
	set(value):
		count = maxi(0, value)
		queue_redraw()

@export var pip_color := Color("#c59a4c")
@export var pip_radius := 5.5
@export var pip_gap := 15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	queue_redraw()


func set_count(value: int) -> void:
	count = value


func _draw() -> void:
	var radius := pip_radius
	var gap := pip_gap
	for index in range(maxi(capacity, count)):
		var column := index % 8
		var row := index / 8
		var center := Vector2(radius + 3.0 + column * gap, radius + 3.0 + row * gap)
		var active := index < count
		if active:
			for layer in range(4, 0, -1):
				draw_circle(center, radius + layer, Color(pip_color, 0.035))
		draw_circle(center + Vector2(0, 1), radius + 1, Color(0, 0, 0, 0.5))
		draw_texture_rect(GEM, Rect2(center - Vector2.ONE * (radius + 2), Vector2.ONE * (radius + 2) * 2), false, Color.WHITE if active else Color("#514d44"))
		if not active:
			draw_circle(center, radius * 0.57, Color("#101317ed"))
	if show_count:
		draw_string(ThemeDB.fallback_font, Vector2(0, pip_radius * 2 + 28), "费用 %d/%d" % [count, maxi(capacity, count)], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#c8b99b"))
