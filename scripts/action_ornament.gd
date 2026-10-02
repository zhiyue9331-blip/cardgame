extends Control

const EMPTY_SLOT := preload("res://assets/ui/empty-card-slot.png")

## 桌面镶铜铭牌、计划空槽与沙漏；装饰不接收鼠标输入。
var kind := "prepare"
var occupied := false
var highlighted := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var gold := Color("#ae8c55") if not highlighted else Color("#e8c56e")
	if kind in ["prepare", "header"]:
		var w := size.x
		var h := size.y
		var rim := PackedVector2Array([Vector2(18, 2), Vector2(w - 18, 2), Vector2(w - 4, 14), Vector2(w - 4, h - 14), Vector2(w - 18, h - 2), Vector2(18, h - 2), Vector2(4, h - 14), Vector2(4, 14), Vector2(18, 2)])
		draw_colored_polygon(rim, Color("#100e0cea"))
		draw_polyline(rim, gold, 1.5, true)
		for x in [10.0, w - 10.0]:
			var y := h * 0.5
			draw_colored_polygon(PackedVector2Array([Vector2(x, y - 4), Vector2(x + 4, y), Vector2(x, y + 4), Vector2(x - 4, y)]), gold)
		return
	# Low contrast tray outline with short reinforced corners.
	var tray := Rect2(3, 29, size.x - 6, size.y - 32)
	draw_style_box(_tray_style(), tray)
	for corner in [tray.position, Vector2(tray.end.x, tray.position.y), tray.end, Vector2(tray.position.x, tray.end.y)]:
		var direction := Vector2(1 if corner.x == tray.position.x else -1, 1 if corner.y == tray.position.y else -1)
		draw_line(corner, corner + Vector2(12 * direction.x, 0), gold, 1.5, true)
		draw_line(corner, corner + Vector2(0, 12 * direction.y), gold, 1.5, true)
	if not occupied:
		var slot := Rect2(14, 39, 98, 130)
		draw_texture_rect(EMPTY_SLOT, slot, false, Color(1, 1, 1, 0.85))
	# Brass hourglass, drawn inside a small inset counter tile.
	var c := Vector2(200, 74)
	draw_style_box(_tray_style(), Rect2(c - Vector2(29, 24), Vector2(58, 52)))
	for y in [-17.0, 17.0]:
		draw_line(c + Vector2(-16, y), c + Vector2(16, y), gold, 2, true)
	var glass := PackedVector2Array([c + Vector2(-12, -13), c + Vector2(12, -13), c + Vector2(9, -7), c + Vector2(-9, 7), c + Vector2(-12, 13), c + Vector2(12, 13), c + Vector2(9, 7), c + Vector2(-9, -7), c + Vector2(-12, -13)])
	draw_polyline(glass, gold, 1.5, true)
	if occupied:
		draw_colored_polygon(PackedVector2Array([c + Vector2(-7, -11), c + Vector2(7, -11), c + Vector2(0, -3)]), Color("#d4ad69"))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, 11), c + Vector2(8, 11), c + Vector2(0, 5)]), Color("#d4ad69"))

func _tray_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#100e0c88")
	style.border_color = Color("#68543899")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style
