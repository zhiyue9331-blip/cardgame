class_name StatusPips
extends Control

@export var count := 0:
	set(value):
		count = maxi(0, value)
		queue_redraw()

@export var pip_color := Color("#c59a4c")
@export var pip_radius := 5.5
@export var pip_gap := 15.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func set_count(value: int) -> void:
	count = value


func _draw() -> void:
	var radius := pip_radius
	var gap := pip_gap
	for index in range(count):
		var column := index % 8
		var row := index / 8
		var center := Vector2(radius + 2.0 + column * gap, radius + 2.0 + row * gap)
		draw_circle(center + Vector2(1.5, 2.0), radius, Color(0, 0, 0, 0.38))
		draw_circle(center, radius + 1.0, Color("#4a3520"))
		draw_circle(center, radius, pip_color)
		draw_circle(center - Vector2(2.0, 2.0), 2.0, pip_color.lightened(0.42))
