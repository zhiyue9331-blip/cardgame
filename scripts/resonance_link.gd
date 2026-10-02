class_name ResonanceLink
extends Control

## Public resonance contributors; visuals never touch game random state.
var level := 0
var _tint := Color("#c6a56c")
var _time := 0.0
var _sub_connected := false
var _buffer_indices: Array[int] = []
var _main_zone: Control
var _sub_zone: Control
var _buffer_cards: Control
var _badge: PanelContainer
var _label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge = PanelContainer.new()
	_badge.name = "ResonanceBadge"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.z_index = 6
	_badge.size = Vector2(118, 34)
	var style := StyleBoxEmpty.new()
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	_badge.add_theme_stylebox_override("panel", style)
	add_child(_badge)
	var ornament := preload("res://scripts/action_ornament.gd").new()
	ornament.kind = "header"
	_badge.add_child(ornament)
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.show_behind_parent = true
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	_badge.add_child(_label)
	set_process(false)
	visible = false

func configure(main_zone: Control, sub_zone: Control, buffer_cards: Control) -> void:
	_main_zone = main_zone
	_sub_zone = sub_zone
	_buffer_cards = buffer_cards

func update_state(faction: String, resonance: int, player: Dictionary) -> void:
	level = resonance
	_tint = ResonanceSeal.tint_for(faction, level)
	_buffer_indices.clear()
	var names := {str(player.get("main", {}).get("name", "")): true}
	var sub: Dictionary = player.get("sub", {})
	_sub_connected = sub.get("faction", "") == faction and not names.has(str(sub.get("name", "")))
	if _sub_connected: names[str(sub.name)] = true
	var buffer: Array = player.get("buffer", [])
	for index in range(buffer.size()):
		var card: Dictionary = buffer[index]
		if card.get("faction", "") == faction and not names.has(str(card.get("name", ""))):
			_buffer_indices.append(index)
			names[str(card.name)] = true
	visible = level > 0
	_label.text = "深度共鸣" if level == 2 else "共鸣"
	_label.add_theme_color_override("font_color", _tint)
	set_process(level == 2 and is_visible_in_tree())
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process(level == 2 and is_visible_in_tree())

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _rect(control: Control) -> Rect2:
	var transform := get_global_transform().affine_inverse()
	var rect := control.get_global_rect()
	return Rect2(transform * rect.position, transform.basis_xform(rect.size))

func _draw() -> void:
	if level == 0: return
	var main := _rect(_main_zone)
	var sub := _rect(_sub_zone)
	var center := Vector2((main.get_center().x + sub.get_center().x) * 0.5, main.position.y + 152)
	_badge.position = center - _badge.size * 0.5
	if _sub_connected:
		_link(Vector2(main.end.x - 12, center.y), Vector2(sub.position.x + 12, center.y), 0)
	for index in _buffer_indices:
		var target := _rect(_buffer_cards.get_child(index))
		_link(Vector2(main.end.x - 12, center.y + 6), Vector2(target.get_center().x, target.end.y - 10), 45)

func _link(from: Vector2, to: Vector2, bend: float) -> void:
	var points := PackedVector2Array()
	var control := (from + to) * 0.5 + Vector2(0, bend)
	for index in range(25):
		var t := index / 24.0
		points.append((1 - t) * (1 - t) * from + 2 * (1 - t) * t * control + t * t * to)
	var breath := 0.65 + 0.2 * sin(_time * 2.0) if level == 2 else 0.55
	draw_polyline(points, Color(_tint, breath * 0.17), 7, true)
	draw_polyline(points, Color(_tint, breath), 1.5, true)
	if level == 2:
		var t := fmod(_time * 0.24, 1.0)
		var spark := (1 - t) * (1 - t) * from + 2 * (1 - t) * t * control + t * t * to
		draw_circle(spark, 3, Color(_tint, 0.22))
		draw_circle(spark, 1.3, _tint.lightened(0.4))
