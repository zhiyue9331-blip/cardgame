class_name CombatPresenter
extends Node

const COMBAT_FEEDBACK_SCRIPT := preload("res://scripts/combat_feedback.gd")

signal running_changed(running: bool)

var running := false
var audio_enabled := true
var playback_speed := 1.0

var _board: Control
var _self_head: Control
var _hand_zone: HandZone
var _deck_zone: Control
var _local_slot := 0
var _opponents: Array = []
var _panels: Array = []
var _queue: Array[Dictionary] = []
var _feedback: CombatFeedback
var _generation := 0
var _active_tweens: Array[Tween] = []
var _center_labels: Array[Label] = []
var _self_head_colors: Dictionary = {}
var _shake_positions: Dictionary = {}
var _shake_tweens: Dictionary = {}
var _head_tweens: Dictionary = {}


func setup(board: Control, self_head: Control) -> void:
	reset()
	_board = board
	_self_head = self_head
	_feedback = COMBAT_FEEDBACK_SCRIPT.new()
	_feedback.z_index = 195
	_board.add_child(_feedback)
	_feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_feedback.set_audio_enabled(audio_enabled)
	_feedback.set_playback_speed(playback_speed)


func set_audio_enabled(enabled: bool) -> void:
	audio_enabled = enabled
	if _feedback:
		_feedback.set_audio_enabled(enabled)

func set_card_zones(hand_zone: HandZone, deck_zone: Control) -> void:
	_hand_zone = hand_zone
	_deck_zone = deck_zone

func set_playback_speed(value: float) -> void:
	playback_speed = clampf(value, 0.25, 3.0)
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.set_speed_scale(playback_speed)
	if _feedback:
		_feedback.set_playback_speed(playback_speed)


func play_heal_cue(slot: int, amount: int) -> void:
	enqueue([{"kind": "heal", "target": slot, "amount": amount}])


func play_turn_cue(is_local: bool, slot: int = -1) -> void:
	enqueue([{"kind": "turn", "target": _local_slot if slot < 0 else slot, "is_local": is_local}])


func set_targets(local_slot: int, opponents: Array, panels: Array) -> void:
	_local_slot = local_slot
	_opponents = opponents
	_panels = panels


func enqueue(events: Array) -> void:
	for event in events:
		if event is Dictionary:
			_queue.append(event)
	if not running and not _queue.is_empty():
		_play_queue()


func reset() -> void:
	_generation += 1
	_queue.clear()
	if is_instance_valid(_hand_zone):
		for card in _hand_zone.cards: card.show()
	for tween in _active_tweens:
		if tween and tween.is_valid():
			tween.kill()
	_active_tweens.clear()
	for label in _center_labels:
		if is_instance_valid(label):
			label.queue_free()
	_center_labels.clear()
	for node in _shake_positions:
		if is_instance_valid(node):
			node.position = _shake_positions[node]
	_shake_positions.clear()
	for node in _shake_tweens:
		var shake_tween: Tween = _shake_tweens[node]
		if shake_tween and shake_tween.is_valid():
			shake_tween.kill()
	_shake_tweens.clear()
	for head in _self_head_colors:
		if is_instance_valid(head):
			head.modulate = _self_head_colors[head]
	_self_head_colors.clear()
	for head in _head_tweens:
		var head_tween: Tween = _head_tweens[head]
		if head_tween and head_tween.is_valid():
			head_tween.kill()
	_head_tweens.clear()
	if _feedback:
		_feedback.reset()
	_set_running(false)


func _exit_tree() -> void:
	set_block_signals(true)
	reset()


func show_center_message(message: String, color: Color) -> void:
	if not _board:
		return
	var label := Label.new()
	label.z_index = 200
	label.text = message
	label.custom_minimum_size = Vector2(620, 80)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#111820"))
	label.add_theme_constant_override("outline_size", 7)
	label.add_theme_font_size_override("font_size", 34)
	_board.add_child(label)
	_center_labels.append(label)
	label.global_position = _board.get_global_rect().get_center() - Vector2(310, 70)
	var tween := _track_tween(label.create_tween().set_parallel(true))
	tween.tween_property(label, "global_position:y", label.global_position.y - 24.0, 0.9)
	tween.tween_property(label, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tween.chain().tween_callback(func() -> void:
		_center_labels.erase(label)
		if is_instance_valid(label):
			label.queue_free()
	)


func shake_self_player() -> void:
	if not _self_head:
		return
	var start: Vector2 = _shake_positions.get(_self_head, _self_head.position)
	_kill_shake_tween(_self_head)
	_shake_positions[_self_head] = start
	var tween := _track_tween(_self_head.create_tween())
	_shake_tweens[_self_head] = tween
	for offset in [Vector2(-11, 1), Vector2(9, -2), Vector2(-7, 1), Vector2(5, 0)]:
		tween.tween_property(_self_head, "position", start + offset, 0.045)
		tween.tween_property(_self_head, "position", start, 0.07)
	tween.finished.connect(func() -> void:
		_shake_tweens.erase(_self_head)
		_shake_positions.erase(_self_head)
		if is_instance_valid(_self_head):
			_self_head.position = start
	)


func _play_queue() -> void:
	var token := _generation
	_set_running(true)
	while token == _generation and not _queue.is_empty():
		var event: Dictionary = _queue.pop_front()
		var target := int(event.get("target", _local_slot))
		var target_point := _combat_point_for_slot(target)
		match str(event.get("kind", "")):
			"card_play":
				var actor := int(event.actor)
				var actor_name := "你" if actor == _local_slot else "玩家 %d" % (actor + 1)
				for opponent in _opponents:
					if int(opponent.slot) == actor: actor_name = str(opponent.name)
				await _feedback.play_card(_combat_point_for_slot(actor), _feedback.size * 0.5, event.card, "%s · %s %s" % [actor_name, str(event.get("label", "打出")), str(event.card.get("name", "卡牌"))])
			"draw":
				var source := _feedback.size * 0.5
				if event.has("source_global"):
					source = _feedback.get_global_transform().affine_inverse() * event.source_global
				elif event.get("source", "") != "inspection" and is_instance_valid(_deck_zone):
					source = _feedback.get_global_transform().affine_inverse() * _deck_zone.get_global_rect().get_center()
				var drawn_card: DraggableCard
				if target == _local_slot and is_instance_valid(_hand_zone):
					for card in _hand_zone.cards:
						if str(card.card_data.id) == str(event.card.id): drawn_card = card
					if is_instance_valid(drawn_card):
						target_point = _feedback.get_global_transform().affine_inverse() * (_hand_zone.global_position + drawn_card.home_position + drawn_card.size * 0.5)
				else:
					for index in range(mini(_opponents.size(), _panels.size())):
						if int(_opponents[index].slot) == target:
							target_point = _feedback.get_global_transform().affine_inverse() * _panels[index].hand_count.get_global_rect().get_center()
				await _feedback.play_draw(source, target_point, event.card, target == _local_slot or bool(event.get("public", false)))
				if token == _generation and is_instance_valid(drawn_card): drawn_card.show()
			"attack":
				_flash_combat_target(target)
				await _feedback.play_attack(_combat_point_for_slot(int(event.get("actor", _local_slot))), target_point, int(event.get("amount", 0)))
			"hit":
				var amount := int(event.get("amount", 0))
				if amount > 0:
					_flash_combat_target(target)
				await _feedback.play_hit(_combat_point_for_slot(int(event.get("actor", _local_slot))), target_point, amount)
			"result":
				await _feedback.play_result(target_point, int(event.get("buffered", 0)), int(event.get("lost_hp", 0)))
			"heal":
				await _feedback.play_heal(target_point, int(event.get("amount", 0)))
			"turn":
				await _feedback.play_turn(target_point, "你的回合" if bool(event.get("is_local", false)) else "对手回合")
	if token != _generation:
		return
	_set_running(false)


func _combat_point_for_slot(slot: int) -> Vector2:
	if not _feedback:
		return Vector2.ZERO
	if slot == _local_slot and _self_head:
		return _feedback.get_global_transform().affine_inverse() * _self_head.get_global_rect().get_center()
	for index in range(mini(_opponents.size(), _panels.size())):
		if int(_opponents[index].get("slot", -1)) != slot:
			continue
		return _feedback.get_global_transform().affine_inverse() * _panels[index].head_center()
	return _feedback.size * 0.5


func _flash_combat_target(slot: int) -> void:
	var head: Control = _self_head
	if slot == _local_slot:
		shake_self_player()
	else:
		for index in range(mini(_opponents.size(), _panels.size())):
			if int(_opponents[index].get("slot", -1)) != slot:
				continue
			var panel = _panels[index]
			var start: Vector2 = _shake_positions.get(panel, panel.position)
			_kill_shake_tween(panel)
			_shake_positions[panel] = start
			var shake := _track_tween(panel.create_tween())
			_shake_tweens[panel] = shake
			for offset in [Vector2(-7, 1), Vector2(6, -1), Vector2(-3, 0)]:
				shake.tween_property(panel, "position", start + offset, 0.045)
			shake.tween_property(panel, "position", start, 0.07)
			shake.finished.connect(func() -> void:
				_shake_tweens.erase(panel)
				_shake_positions.erase(panel)
				if is_instance_valid(panel):
					panel.position = start
			)
			head = panel.target_head
			break
	if not head:
		return
	var original: Color = _self_head_colors.get(head, head.modulate)
	_self_head_colors[head] = original
	_kill_head_tween(head)
	var tween := _track_tween(head.create_tween())
	_head_tweens[head] = tween
	tween.tween_property(head, "modulate", Color("#ff7e72"), 0.08)
	tween.tween_property(head, "modulate", original, 0.28)
	tween.finished.connect(func() -> void:
		_head_tweens.erase(head)
		_self_head_colors.erase(head)
		if is_instance_valid(head):
			head.modulate = original
	)


func _kill_shake_tween(node: Control) -> void:
	if not _shake_tweens.has(node):
		return
	var tween: Tween = _shake_tweens[node]
	if tween and tween.is_valid():
		tween.kill()
	_active_tweens.erase(tween)
	_shake_tweens.erase(node)
	if _shake_positions.has(node) and is_instance_valid(node):
		node.position = _shake_positions[node]


func _kill_head_tween(head: Control) -> void:
	if not _head_tweens.has(head):
		return
	var tween: Tween = _head_tweens[head]
	if tween and tween.is_valid():
		tween.kill()
	_active_tweens.erase(tween)
	_head_tweens.erase(head)
	if _self_head_colors.has(head) and is_instance_valid(head):
		head.modulate = _self_head_colors[head]


func _track_tween(tween: Tween) -> Tween:
	tween.set_speed_scale(playback_speed)
	_active_tweens.append(tween)
	tween.finished.connect(func() -> void: _active_tweens.erase(tween))
	return tween


func _set_running(value: bool) -> void:
	if running == value:
		return
	running = value
	running_changed.emit(running)
