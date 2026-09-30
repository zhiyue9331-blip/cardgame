class_name PileZone
extends PanelContainer

signal pile_pressed

@export var pile_title := "牌堆"

@onready var title_label: Label = $PileContent/PileTitle
@onready var count_label: Label = $PileContent/PileCount
@onready var top_label: Label = $PileContent/TopCard
@onready var button: Button = $PileButton
var top_art: TextureRect


func _ready() -> void:
	title_label.text = pile_title
	button.pressed.connect(func() -> void: pile_pressed.emit())
	top_art = TextureRect.new()
	top_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_label.add_child(top_art)
	top_art.visible = false
	top_label.resized.connect(queue_redraw)
	queue_redraw()


func update_pile(count: int, top_card_name := "CARD BACK", top_card: Dictionary = {}) -> void:
	count_label.text = str(count)
	top_label.text = top_card_name
	var art_path := "res://cards/art/%s.png" % str(top_card.get("base_id", top_card.get("id", "")))
	top_art.texture = load(art_path) if not top_card.is_empty() and ResourceLoader.exists(art_path) else null
	top_art.visible = top_art.texture != null
	if top_art.visible:
		top_label.text = ""
	elif top_card.is_empty():
		top_label.text = "" if pile_title == "牌堆" else "—"
	if not top_card.is_empty():
		button.tooltip_text = "%s\n%s" % [top_card_name, str(top_card.get("description", ""))]
	elif pile_title == "弃牌区":
		button.tooltip_text = "查看弃牌"
	elif pile_title == "牌堆":
		button.tooltip_text = "公共抽牌（1费抽2张）\n与整备二选一"
	queue_redraw()


func pulse() -> void:
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.1)
	tween.chain().tween_property(self, "scale", Vector2.ONE, 0.16)

func _draw() -> void:
	# Geometric card backs keep the pile legible at a glance without placeholder copy.
	if pile_title != "牌堆":
		return
	var center := get_global_transform().affine_inverse() * top_label.get_global_rect().get_center()
	var card := Rect2(center - Vector2(29, 34), Vector2(58, 68))
	for offset in [Vector2(-7, -7), Vector2(-3, -3)]:
		var offset_card := Rect2(card.position + offset, card.size)
		draw_rect(offset_card, Color("#102c2d"), true)
		draw_rect(offset_card, Color(0.82, 0.67, 0.36, 0.48), false, 1.0)
	draw_rect(card, Color("#173f3d"), true)
	draw_rect(card, Color(0.91, 0.75, 0.40, 0.78), false, 1.0)
	var c := card.get_center()
	var diamond := PackedVector2Array([c + Vector2(0, -22), c + Vector2(21, 0), c + Vector2(0, 22), c + Vector2(-21, 0), c + Vector2(0, -22)])
	draw_polyline(diamond, Color(0.91, 0.75, 0.40, 0.72), 1.0, true)
	draw_circle(c, 4.0, Color(0.91, 0.75, 0.40, 0.72))
