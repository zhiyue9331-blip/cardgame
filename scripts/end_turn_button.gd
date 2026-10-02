class_name EndTurnButton
extends Button

## Native Button interaction with a cut-corner brass face.
var _time := 0.0
var _hovered := false

func _ready() -> void:
	mouse_entered.connect(func(): _hovered = true; queue_redraw())
	mouse_exited.connect(func(): _hovered = false; queue_redraw())
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	resized.connect(queue_redraw)
	set_available(not disabled)

func set_available(available: bool) -> void:
	disabled = not available
	set_process(available and is_visible_in_tree())
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(not disabled and is_visible_in_tree())

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _rim(inset: float) -> PackedVector2Array:
	var x := inset
	var y := inset
	var w := size.x - inset
	var h := size.y - inset
	var cut := 17.0
	return PackedVector2Array([Vector2(x + cut, y), Vector2(w - cut, y), Vector2(w, y + cut), Vector2(w, h - cut), Vector2(w - cut, h), Vector2(x + cut, h), Vector2(x, h - cut), Vector2(x, y + cut), Vector2(x + cut, y)])

func _draw() -> void:
	var bright := not disabled
	var breath := 0.55 + sin(_time * 2.0) * 0.15
	var gold := Color("#efca77") if bright else Color("#766347")
	var outer := _rim(3)
	if bright:
		for layer in range(5, 0, -1):
			draw_polyline(outer, Color(Color("#ffbf49"), breath * 0.025), 2.0 + layer * 3.0, true)
	var fill := Color("#8c551f") if bright else Color("#292217")
	if bright and (_hovered or has_focus()): fill = Color("#b27327")
	if bright and is_pressed(): fill = Color("#63401b")
	draw_colored_polygon(outer, fill)
	draw_polyline(outer, gold, 2.0, true)
	draw_polyline(_rim(8), Color(gold, 0.6), 1.0, true)
	for x in [12.0, size.x - 12.0]:
		var c := Vector2(x, size.y * 0.5)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)]), gold)
	var font := get_theme_font("font")
	var font_size := get_theme_font_size("font_size")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline := (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var ink := Color("#fff3d9") if bright else Color("#968467")
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
