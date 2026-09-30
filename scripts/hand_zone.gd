class_name HandZone
extends Control

const CARD_SIZE := Vector2(142, 188)
const MAX_GAP := 154.0

var cards: Array[DraggableCard] = []


func add_card(card: DraggableCard, start_global_position: Vector2) -> void:
	add_child(card)
	cards.append(card)
	card.rest_scale = Vector2.ONE
	card.global_position = start_global_position - CARD_SIZE * 0.5
	card.scale = Vector2(0.45, 0.45)
	card.modulate.a = 0.0
	var appear := card.create_tween().set_parallel(true)
	appear.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	appear.tween_property(card, "scale", Vector2.ONE, 0.28)
	appear.tween_property(card, "modulate:a", 1.0, 0.16)
	call_deferred("layout_cards")


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
	var available := maxf(0.0, size.x - CARD_SIZE.x)
	var gap := MAX_GAP
	if cards.size() > 1:
		gap = minf(MAX_GAP, available / float(cards.size() - 1))
	var row_width := CARD_SIZE.x + gap * float(cards.size() - 1)
	var start_x := maxf(0.0, (size.x - row_width) * 0.5)
	for index in range(cards.size()):
		cards[index].set_home(Vector2(start_x + index * gap, 6.0), true)
