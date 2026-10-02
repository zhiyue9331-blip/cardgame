class_name ResonanceSeal
extends Control

const SEAL := preload("res://assets/ui/resonance-seal.png")
const FACTION_COLORS := {
	"铸锋": Color("#f1a155"), "回响": Color("#55d4d0"),
	"血契": Color("#ed596e"), "星序": Color("#a58aff"),
	"归骸": Color("#a2c0cc"), "围猎": Color("#9acb64"),
	"伏谋": Color("#efc56b"),
}
var faction := ""
var level := 0
var _time := 0.0

static func tint_for(system: String, resonance: int) -> Color:
	return FACTION_COLORS.get(system, Color("#dedede")) if resonance > 0 else Color("#dedede")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)
	set_process(level == 2)

func setup(system: String, resonance: int) -> void:
	faction = system
	level = clampi(resonance, 0, 2) if not system.is_empty() else 0
	set_process(level == 2 and is_visible_in_tree())
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(level == 2 and is_visible_in_tree())

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	var side := minf(size.x, size.y)
	var radius := side * 0.35
	var tint := tint_for(faction, level)
	if level > 0:
		var breath := 0.5 + 0.5 * sin(_time * 2.2) if level == 2 else 0.35
		for layer in range(6, 0, -1):
			draw_arc(center, radius + layer * side * 0.014, 0, TAU, 64, Color(tint, (0.035 + breath * 0.018) * (7 - layer)), 1.5, true)
		if level == 2:
			for index in range(3):
				var angle := _time * 0.38 + TAU * index / 3.0
				draw_arc(center, side * 0.44, angle, angle + 0.9, 24, Color(tint, 0.45 + breath * 0.3), 1.2, true)
			for index in range(7):
				var angle := -_time * 0.26 + TAU * index / 7.0
				var point := center + Vector2.from_angle(angle) * side * (0.42 + 0.025 * sin(_time + index))
				draw_circle(point, side * 0.018, Color(tint, 0.1))
				draw_circle(point, maxf(0.7, side * 0.007), Color(tint.lightened(0.55), 0.8))
	draw_texture_rect(SEAL, Rect2(center - Vector2.ONE * side * 0.42, Vector2.ONE * side * 0.84), false, tint)
