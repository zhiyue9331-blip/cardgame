class_name HandZone
extends Control

const CARD_SIZE := Vector2(142, 188)
const MAX_GAP := 172.0
const HAND_SCALE := 1.16

var cards: Array[DraggableCard] = []


func add_card(card: DraggableCard, start_global_position: Vector2, animate_enter := true) -> void:
	add_child(card)
	cards.append(card)
	card.set_rest_scale(Vector2.ONE * HAND_SCALE)
	card.hover_changed.connect(_on_card_hover_changed)
	if not animate_enter:
		card.visible = false
		return
	card.global_position = start_global_position - CARD_SIZE * 0.5
	card.scale = Vector2(0.45, 0.45)
	card.modulate.a = 0.0
	call_deferred("layout_cards")
	call_deferred("_play_card_enter", card)


func _play_card_enter(card: DraggableCard) -> void:
	if is_instance_valid(card) and card.get_parent() == self and not card.is_queued_for_deletion() and not card.dragging:
		card.play_enter_animation()


func remove_card(card: DraggableCard) -> void:
	cards.erase(card)
	layout_cards()


func clear_cards() -> void:
	for card in cards:
		card.queue_free()
	cards.clear()


func layout_cards() -> void:
	if cards.is_empty():
		return
	var visual_width := CARD_SIZE.x * HAND_SCALE
	var available := maxf(0.0, size.x - visual_width)
	var gap := MAX_GAP
	if cards.size() > 1:
		gap = minf(MAX_GAP, available / float(cards.size() - 1))
	var row_width := visual_width + gap * float(cards.size() - 1)
	var start_x := maxf(0.0, (size.x - row_width) * 0.5) + (visual_width - CARD_SIZE.x) * 0.5
	var center_idx := float(cards.size() - 1) * 0.5
	for index in range(cards.size()):
		var diff := float(index) - center_idx
		var arc_y := absf(diff) * 2.2
		var card := cards[index]
		card.set_home(Vector2(start_x + index * gap, 6.0 + arc_y), true)
		if not card.dragging:
			if bool(card.get_meta("hand_hovered", false)):
				card.position.y = card.home_position.y - 20.0
				card.scale = card.rest_scale * 1.06
				card.rotation = 0.0
			else:
				card.rotation = deg_to_rad(diff * 1.5)


func _on_card_hover_changed(card: DraggableCard, hovered: bool) -> void:
	if is_instance_valid(card):
		card.set_meta("hand_hovered", hovered)
		layout_cards()
