class_name PileZone
extends PanelContainer

signal pile_pressed
const CARD_BACK_TEXTURE := preload("res://assets/ui/astral-card-back.png")

@export var pile_title := "牌堆"

@onready var title_label: Label = $PileContent/PileTitle
@onready var count_label: Label = $PileContent/PileCount
@onready var top_label: Label = $PileContent/TopCard
@onready var button: Button = $PileButton
var top_art: TextureRect
var top_fields: Label
var art_frame: TextureRect
var _pile_count := 0
var count_badge: Panel
var _hovered := false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	title_label.text = "公共牌堆" if pile_title == "牌堆" else "弃牌区"
	title_label.add_theme_color_override("font_color", Color("#d8b672"))
	title_label.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(func() -> void: pile_pressed.emit())
	top_art = TextureRect.new()
	top_art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	top_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	top_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	top_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_label.add_child(top_art)
	top_art.visible = false
	art_frame = TextureRect.new()
	art_frame.name = "ArtFrame"
	art_frame.texture = preload("res://assets/ui/antique-card-frame.png")
	art_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_label.add_child(art_frame)
	art_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art_frame.visible = false
	top_fields = Label.new()
	top_fields.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_fields.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top_fields.add_theme_font_size_override("font_size", 12)
	top_fields.add_theme_color_override("font_color", Color.WHITE)
	top_fields.add_theme_color_override("font_outline_color", Color("#102425"))
	top_fields.add_theme_constant_override("outline_size", 3)
	top_label.add_child(top_fields)
	top_fields.position = Vector2(3, 5)
	top_fields.size = Vector2(90, 20)
	top_fields.visible = false
	top_label.resized.connect(queue_redraw)

	# Style count label as round brass medallion matching concept reference
	var count_style := StyleBoxFlat.new()
	count_style.bg_color = Color(0.12, 0.10, 0.08, 0.95)
	count_style.border_color = Color(0.88, 0.72, 0.38, 1.0)
	count_style.set_border_width_all(2)
	count_style.set_corner_radius_all(22)
	count_style.shadow_color = Color(0, 0, 0, 0.6)
	count_style.shadow_size = 3
	count_badge = Panel.new()
	count_badge.name = "CountBadge"
	count_badge.position = Vector2(72, 96)
	count_badge.size = Vector2(44, 44)
	count_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_badge.add_theme_stylebox_override("panel", count_style)
	top_label.add_child(count_badge)
	count_label.reparent(count_badge)
	count_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_color_override("font_color", Color("#faecd2"))
	count_label.add_theme_font_size_override("font_size", 22)
	top_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.mouse_entered.connect(func(): _hovered = true; queue_redraw())
	button.mouse_exited.connect(func(): _hovered = false; queue_redraw())
	resized.connect(_layout_pile)
	_layout_pile()

	queue_redraw()

func _layout_pile() -> void:
	# The label is also the visible card and the public-card animation anchor.
	top_label.position = Vector2((size.x - 96) * 0.5, 3)
	top_label.size = Vector2(96, 128)
	title_label.position = Vector2(0, 135)
	title_label.size = Vector2(size.x, 25)
	var hint := get_node_or_null("PileContent/DrawHint") as Label
	if hint:
		hint.position = Vector2(-12, 160)
		hint.size = Vector2(size.x + 24, 22)
		hint.add_theme_font_size_override("font_size", 16)
	queue_redraw()


func update_pile(count: int, top_card_name := "CARD BACK", top_card: Dictionary = {}) -> void:
	_pile_count = count
	count_label.text = str(count)
	top_label.text = top_card_name
	var art_path := "res://cards/art/%s.png" % str(top_card.get("base_id", top_card.get("id", "")))
	top_art.texture = load(art_path) if not top_card.is_empty() and ResourceLoader.exists(art_path) else null
	top_art.visible = top_art.texture != null
	art_frame.visible = top_art.visible
	top_fields.visible = not top_card.is_empty()
	var faction := str(top_card.get("faction", ""))
	top_fields.text = "%s · %s费" % [faction if not faction.is_empty() else "中立", str(top_card.get("cost", 0))]
	if top_art.visible:
		top_label.text = ""
	elif top_card.is_empty():
		top_label.text = ""
	if not top_card.is_empty():
		button.tooltip_text = "%s · %s\n%s" % [top_card_name, top_fields.text, str(top_card.get("description", ""))]
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
	var card := Rect2(top_label.position, top_label.size)
	if _hovered and not button.disabled:
		draw_style_box(_halo(), card.grow(5))

	# Tangible stacked cards underneath with soft drop shadows and gilded edges
	var depth := clampi(ceili(_pile_count / 18.0), 1, 5) if _pile_count > 0 else 0
	for index in range(depth, 0, -1):
		var offset := Vector2(-index * 2.0, index * 2.5)
		var offset_card := Rect2(card.position + offset, card.size)
		draw_rect(offset_card, Color(0.08, 0.07, 0.06, 0.95), true)
		draw_rect(offset_card, Color(0.72, 0.58, 0.32, 0.45), false, 1.0)

	# Main card base
	draw_rect(card, Color("#141210"), true)
	draw_rect(card, Color(0.85, 0.70, 0.38, 0.85), false, 1.5)

	if pile_title == "牌堆":
		if _pile_count > 0:
			draw_texture_rect(CARD_BACK_TEXTURE, card, false)
	else:
		# Discard pile frame
		if not top_art.visible:
			draw_texture_rect(preload("res://assets/ui/empty-card-slot.png"), card, false, Color(1, 1, 1, 0.7))

func _halo() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("#e8c56e")
	style.set_border_width_all(1)
	style.shadow_color = Color(0.96, 0.75, 0.35, 0.2)
	style.shadow_size = 12
	return style
