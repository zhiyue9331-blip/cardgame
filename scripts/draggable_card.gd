class_name DraggableCard
extends Control

signal drop_requested(card: DraggableCard, global_drop_position: Vector2)
signal drag_started(card: DraggableCard)
signal drag_updated(card: DraggableCard, global_mouse_position: Vector2)
signal hover_changed(card: DraggableCard, hovered: bool)

var card_data: Dictionary = {}
var home_position := Vector2.ZERO
var dragging := false
var has_dragged := false
var interaction_enabled := true
var rest_scale := Vector2.ONE
var drag_offset := Vector2.ZERO
var press_position := Vector2.ZERO
var motion_tween: Tween

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
		name_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		name_label.position = Vector2(10, 37)
		name_label.size = Vector2(122, 25)
		type_label.position = Vector2(10, 62)
	type_label.visible = not artwork.visible
	description_label.visible = not artwork.visible
	description_label.text = full_description.left(18)
	if full_description.length() > 18:
		description_label.text += "…"
	description_label.max_lines_visible = 2
	description_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_update_special_fields(data)


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
	if animated:
		_animate_local_position(target)
	else:
		position = target


func set_rest_scale(value: Vector2) -> void:
	rest_scale = value
	scale = value


func return_home() -> void:
	dragging = false
	z_index = 0
	rotation = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", home_position, 0.28)
	tween.tween_property(self, "scale", rest_scale, 0.22)
	var shake := create_tween()
	shake.tween_property(self, "rotation", deg_to_rad(-3.0), 0.05)
	shake.tween_property(self, "rotation", deg_to_rad(3.0), 0.08)
	shake.tween_property(self, "rotation", 0.0, 0.06)


func set_interaction_enabled(value: bool, hover_when_disabled := false) -> void:
	interaction_enabled = value
	mouse_filter = Control.MOUSE_FILTER_STOP if value or hover_when_disabled else Control.MOUSE_FILTER_IGNORE
	modulate = Color.WHITE if value or hover_when_disabled else Color(0.38, 0.41, 0.43, 0.76)


func animate_to_global(target: Vector2, shrink := true) -> void:
	dragging = false
	z_index = 100
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target - size * 0.5, 0.25)
	tween.tween_property(self, "rotation", 0.0, 0.18)
	if shrink:
		tween.tween_property(self, "scale", Vector2(0.35, 0.35), 0.25)
		tween.tween_property(self, "modulate:a", 0.0, 0.22)
	await tween.finished


func _gui_input(event: InputEvent) -> void:
	if not interaction_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			has_dragged = false
			press_position = event.global_position
			drag_offset = event.global_position - global_position
			z_index = 100
			_kill_motion_tween()
			var tween := create_tween().set_parallel(true)
			tween.tween_property(self, "scale", rest_scale * 1.08, 0.1)
			tween.tween_property(self, "rotation", deg_to_rad(-2.0), 0.1)
			drag_started.emit(self)
			accept_event()
		else:
			dragging = false
			drop_requested.emit(self, event.global_position)
			accept_event()
	elif event is InputEventMouseMotion and dragging:
		if event.global_position.distance_to(press_position) > 12.0:
			has_dragged = true
		global_position = event.global_position - drag_offset
		drag_updated.emit(self, event.global_position)
		accept_event()


func _on_mouse_entered() -> void:
	hover_changed.emit(self, true)
	if dragging:
		return
	_kill_motion_tween()
	motion_tween = create_tween().set_parallel(true)
	motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "position:y", home_position.y - 18.0, 0.14)
	motion_tween.tween_property(self, "scale", rest_scale * 1.04, 0.14)
	z_index = 10


func _on_mouse_exited() -> void:
	hover_changed.emit(self, false)
	if dragging:
		return
	z_index = 0
	_animate_local_position(home_position)
	var tween := create_tween()
	tween.tween_property(self, "scale", rest_scale, 0.12)


func _animate_local_position(target: Vector2) -> void:
	_kill_motion_tween()
	motion_tween = create_tween()
	motion_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(self, "position", target, 0.22)


func _kill_motion_tween() -> void:
	if motion_tween and motion_tween.is_valid():
		motion_tween.kill()
