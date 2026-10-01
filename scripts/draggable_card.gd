class_name DraggableCard
extends Control

signal drop_requested(card: DraggableCard, global_drop_position: Vector2)
signal drag_started(card: DraggableCard)
signal drag_updated(card: DraggableCard, global_mouse_position: Vector2)
signal hover_changed(card: DraggableCard, hovered: bool)
signal motion_done(token: int)

var card_data: Dictionary = {}
var home_position := Vector2.ZERO
var dragging := false
var has_dragged := false
var interaction_enabled := true
var rest_scale := Vector2.ONE
var drag_offset := Vector2.ZERO
var press_position := Vector2.ZERO
var motion_tween: Tween
var _motion_token := 0
var _entrance_active := false

@onready var name_label: Label = %NameLabel
@onready var type_label: Label = %TypeLabel
@onready var cost_label: Label = %CostLabel
@onready var description_label: Label = %DescriptionLabel
@onready var artwork: TextureRect = %Artwork
@onready var faction_badge: CardFactionBadge = %FactionBadge
@onready var name_plate: Panel = $NamePlate


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pivot_offset = size * 0.5


func setup(data: Dictionary) -> void:
	card_data = data
	if not is_node_ready():
		await ready
	name_label.text = str(data.get("name", "未命名"))
	var faction := str(data.get("faction", ""))
	faction_badge.setup(faction)
	type_label.text = "反击" if data.get("subtype") == "counter" else str(data.get("type", "卡牌"))
	cost_label.text = str(data.get("cost", 0))
	var art_path := "res://cards/art/%s.png" % str(data.get("base_id", data.get("id", "")))
	artwork.texture = load(art_path) if ResourceLoader.exists(art_path) else null
	artwork.visible = artwork.texture != null
	var full_description := str(data.get("description", ""))
	name_label.visible = true
	name_plate.visible = artwork.visible
	if artwork.visible:
		name_label.position = name_plate.position
		name_label.size = name_plate.size
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_label.add_theme_color_override("font_color", Color("#f0e3c1"))
		name_label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.014, 0.95))
		name_label.add_theme_constant_override("outline_size", 3)
		name_label.add_theme_font_size_override("font_size", 18)
	else:
		name_label.position = Vector2(10, 37)
		name_label.size = Vector2(122, 25)
		type_label.position = Vector2(10, 62)
	type_label.visible = true
	if artwork.visible:
		type_label.position = Vector2(10, 36)
		type_label.add_theme_color_override("font_color", Color("#e3c98e"))
		type_label.add_theme_color_override("font_outline_color", Color(0.02, 0.018, 0.014, 0.95))
		type_label.add_theme_constant_override("outline_size", 3)
		type_label.add_theme_font_size_override("font_size", 13)
	description_label.visible = not artwork.visible
	description_label.text = full_description.left(18)
	if full_description.length() > 18:
		description_label.text += "…"
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_update_special_fields(data)
	tooltip_text = "%s · %s · %s · %s费\n%s" % [name_label.text, faction_badge.badge_label.text, type_label.text, cost_label.text, full_description]


func _update_special_fields(_data: Dictionary) -> void:
	pass


func set_displayed_cost(value: int, is_discounted: bool = false) -> void:
	if not cost_label or not is_instance_valid(cost_label):
		return
	cost_label.text = str(value)
	if is_discounted:
		cost_label.add_theme_color_override("font_color", Color("#83e6a4"))
	else:
		cost_label.remove_theme_color_override("font_color")


func set_home(target: Vector2, animated := true) -> void:
	home_position = target
	if dragging:
		return
	if _entrance_active:
		return
	if animated:
		_animate_local_position(target)
	else:
		_kill_motion_tween()
		position = target


func set_rest_scale(value: Vector2) -> void:
	rest_scale = value
	scale = value


func return_home() -> void:
	dragging = false
	z_index = 0
	var tween := _start_motion(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", home_position, 0.28)
	tween.tween_property(self, "scale", rest_scale, 0.22)
	tween.tween_property(self, "rotation", 0.0, 0.12)


func set_interaction_enabled(value: bool, hover_when_disabled := false) -> void:
	interaction_enabled = value
	mouse_filter = Control.MOUSE_FILTER_STOP if value or hover_when_disabled else Control.MOUSE_FILTER_IGNORE
	modulate = Color.WHITE if value or hover_when_disabled else Color(0.38, 0.41, 0.43, 0.76)


func animate_to_global(target: Vector2, shrink := true) -> void:
	dragging = false
	z_index = 100
	var tween := _start_motion(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target - size * 0.5, 0.25)
	tween.tween_property(self, "rotation", 0.0, 0.18)
	if shrink:
		tween.tween_property(self, "scale", Vector2(0.35, 0.35), 0.25)
		tween.tween_property(self, "modulate:a", 0.0, 0.22)
	var token := _motion_token
	var completed_token: int = await motion_done
	if completed_token != token:
		return


func play_enter_animation() -> void:
	var tween := _start_motion(true)
	var token := _motion_token
	_entrance_active = true
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", home_position, 0.28)
	tween.tween_property(self, "scale", rest_scale, 0.28)
	tween.tween_property(self, "modulate:a", 1.0, 0.16)
	tween.finished.connect(func() -> void:
		if token == _motion_token:
			_entrance_active = false
	)


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			has_dragged = false
			press_position = event.global_position
			drag_offset = event.global_position - global_position
			# Hide the hover detail while the pointer is being used to drag.  The
			# release path restores it for a genuine click, preserving inspection.
			hover_changed.emit(self, false)
			z_index = 100
			var tween := _start_motion(true)
			tween.tween_property(self, "scale", rest_scale * 1.08, 0.1)
			tween.tween_property(self, "rotation", deg_to_rad(-2.0), 0.1)
			drag_started.emit(self)
			accept_event()
		else:
			dragging = false
			var clicked := not has_dragged
			drop_requested.emit(self, event.global_position)
			if clicked:
				hover_changed.emit(self, true)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.global_position.distance_to(press_position) > 12.0:
			has_dragged = true
		global_position = event.global_position - drag_offset
		drag_updated.emit(self, event.global_position)
		accept_event()


func _on_mouse_entered() -> void:
	if dragging:
		return
	hover_changed.emit(self, true)
	motion_tween = _start_motion(true)
	motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "position:y", home_position.y - 18.0, 0.14)
	motion_tween.tween_property(self, "scale", rest_scale * 1.04, 0.14)
	z_index = 10


func _on_mouse_exited() -> void:
	hover_changed.emit(self, false)
	if dragging:
		return
	z_index = 0
	var tween := _start_motion(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", home_position, 0.22)
	tween.tween_property(self, "scale", rest_scale, 0.12)


func _animate_local_position(target: Vector2) -> void:
	motion_tween = _start_motion(true)
	motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "position", target, 0.22)
	motion_tween.tween_property(self, "scale", rest_scale, 0.16)
	motion_tween.tween_property(self, "rotation", 0.0, 0.12)


func _start_motion(parallel := false) -> Tween:
	_kill_motion_tween()
	var token := _motion_token
	var tween := create_tween()
	motion_tween = tween
	if parallel:
		tween.set_parallel(true)
	tween.finished.connect(func() -> void:
		motion_done.emit(token)
		if motion_tween == tween and token == _motion_token:
			motion_tween = null
	)
	return tween


func _kill_motion_tween() -> void:
	_motion_token += 1
	var was_running := motion_tween != null and motion_tween.is_valid() and motion_tween.is_running()
	if motion_tween and motion_tween.is_valid():
		motion_tween.kill()
	if was_running:
		motion_done.emit(_motion_token)
	motion_tween = null
	if _entrance_active:
		_entrance_active = false
		modulate.a = 1.0
