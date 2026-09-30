extends Button


func _ready() -> void:
	flat = true
	mouse_entered.connect(func() -> void:
		modulate = Color("#fff0b6")
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		modulate = Color.WHITE
		queue_redraw()
	)


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	draw_circle(center, radius, Color("#183248"))
	draw_arc(center, radius, 0.0, TAU, 40, Color("#e1b75b"), 2.5, true)
	for index in range(3):
		var y := center.y - 8.0 + index * 8.0
		draw_line(Vector2(center.x - 11.0, y), Vector2(center.x + 11.0, y), Color("#edf4fb"), 2.5, true)
