class_name CombatFeedback
extends Control

signal animation_done(token: int)

const AUDIO_SCRIPT := preload("res://scripts/combat_audio.gd")
const EFFECT_CARD_SCENE := preload("res://cards/effect_card.tscn")
const EQUIPMENT_CARD_SCENE := preload("res://cards/equipment_card.tscn")
const CARD_BACK_SCRIPT := preload("res://scripts/card_back.gd")
const GOLD := Color("#f4c76d")
const CORAL := Color("#f47c6e")
const CYAN := Color("#62d4df")
const GREEN := Color("#76d99a")

var _mode := ""
var _progress := 0.0
var _source := Vector2.ZERO
var _target := Vector2.ZERO
var _color := Color.WHITE
var _caption: Label
var _active_tween: Tween
var _audio: CombatAudio
var _seed := 17
var _playback_speed := 1.0
var _animation_token := 0
var _card_visual: Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_audio = AUDIO_SCRIPT.new()
	add_child(_audio)
	_caption = Label.new()
	_caption.visible = false
	_caption.custom_minimum_size = Vector2(300, 52)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 28)
	_caption.add_theme_color_override("font_outline_color", Color("#101820"))
	_caption.add_theme_constant_override("outline_size", 7)
	add_child(_caption)

func set_audio_enabled(enabled: bool) -> void:
	if _audio: _audio.set_enabled(enabled)

func set_playback_speed(value: float) -> void:
	_playback_speed = clampf(value, 0.25, 3.0)
	if _active_tween and _active_tween.is_valid():
		_active_tween.set_speed_scale(_playback_speed)

func play_attack(source: Vector2, target: Vector2, amount: int) -> void:
	_begin("attack", source, target, GOLD, "攻击  ATK %d" % amount)
	_audio.play_event("attack")
	await _animate(0.52)

func play_hit(source: Vector2, target: Vector2, amount: int) -> void:
	var blocked := amount <= 0
	_begin("block" if blocked else "hit", source, target, CYAN if blocked else CORAL, "格挡" if blocked else "伤害  %d" % amount)
	_audio.play_event("block" if blocked else "hit")
	await _animate(0.46 if blocked else 0.56)

func play_result(target: Vector2, buffered: int, lost_hp: int) -> void:
	var text := "缓冲 %d" % buffered
	if lost_hp > 0: text += "  ·  真血 -%d" % lost_hp
	_begin("result", target, target, CORAL if lost_hp > 0 else CYAN, text)
	_audio.play_event("hit" if lost_hp > 0 else "buffer")
	await _animate(0.62)

func play_heal(target: Vector2, amount: int) -> void:
	_begin("heal", target, target, GREEN, "治疗  +%d" % amount)
	_audio.play_event("heal")
	await _animate(0.56)

func play_turn(target: Vector2, label := "回合开始") -> void:
	_begin("turn", target, target, GOLD, label)
	_audio.play_event("turn")
	await _animate(0.44)

func play_card(source: Vector2, destination: Vector2, data: Dictionary, caption: String) -> void:
	_begin("card_play", source, destination, GOLD, caption)
	_create_card_visual(data)
	_caption.position = destination + Vector2(-150, 152)
	_audio.play_event("card_play")
	await _animate(1.45)

func play_draw(source: Vector2, destination: Vector2, data: Dictionary, face_up: bool) -> void:
	_begin("draw", source, destination, CYAN, "")
	_caption.visible = false
	_create_card_visual(data if face_up else {})
	_audio.play_event("draw")
	await _animate(0.46)

func _create_card_visual(data: Dictionary) -> void:
	_clear_card_visual()
	if data.is_empty():
		var back := CARD_BACK_SCRIPT.new()
		back.size = Vector2(142, 188)
		_card_visual = back
	else:
		var scene: PackedScene = EQUIPMENT_CARD_SCENE if data.get("type") == "装备牌" else EFFECT_CARD_SCENE
		var face := scene.instantiate() as DraggableCard
		_card_visual = face
		add_child(face)
		face.setup(data)
		face.set_interaction_enabled(false)
		face.modulate = Color.WHITE
	if not _card_visual.get_parent(): add_child(_card_visual)
	_ignore_card_input(_card_visual)
	_card_visual.pivot_offset = _card_visual.size * 0.5
	_set_progress(0.0)

func _ignore_card_input(node: Node) -> void:
	if node is Control: node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children(): _ignore_card_input(child)

func _clear_card_visual() -> void:
	if is_instance_valid(_card_visual):
		remove_child(_card_visual)
		_card_visual.queue_free()
	_card_visual = null

func reset() -> void:
	_cancel_animation()
	_clear_card_visual()
	_mode = ""
	_progress = 0.0
	if _caption: _caption.visible = false
	if _audio: _audio.stop_all()
	queue_redraw()

func _begin(mode: String, source: Vector2, target: Vector2, color: Color, caption: String) -> void:
	_cancel_animation()
	_mode = mode
	_progress = 0.0
	_source = source
	_target = target
	_color = color
	_seed += 1
	_caption.text = caption
	_caption.add_theme_color_override("font_color", color)
	_caption.position = target + Vector2(-150, -62)
	_caption.modulate.a = 1.0
	_caption.visible = true
	queue_redraw()

func _animate(duration: float) -> void:
	var token := _animation_token
	var tween := create_tween().set_parallel(true)
	_active_tween = tween
	_active_tween.set_speed_scale(_playback_speed)
	tween.finished.connect(func() -> void: animation_done.emit(token))
	var progress_track := _active_tween.tween_method(_set_progress, 0.0, 1.0, duration)
	if _mode not in ["card_play", "draw"]:
		progress_track.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_active_tween.tween_property(_caption, "position:y", _caption.position.y - 28.0, duration)
	_active_tween.tween_property(_caption, "modulate:a", 0.0, duration * 0.52).set_delay(duration * 0.48)
	var completed_token: int = await animation_done
	if completed_token != token:
		return
	_active_tween = null
	_clear_card_visual()
	_mode = ""
	_caption.visible = false
	queue_redraw()


func _cancel_animation() -> void:
	_animation_token += 1
	var was_running := _active_tween != null and _active_tween.is_valid() and _active_tween.is_running()
	if _active_tween and _active_tween.is_valid():
		_active_tween.kill()
	if was_running:
		animation_done.emit(_animation_token)
	_active_tween = null

func _set_progress(value: float) -> void:
	_progress = value
	if is_instance_valid(_card_visual):
		var center: Vector2
		if _mode == "card_play":
			var arrival := clampf(value / 0.26, 0.0, 1.0)
			center = _source.lerp(_target, 1.0 - pow(1.0 - arrival, 3))
			_card_visual.scale = Vector2.ONE * lerpf(0.5, 1.5, arrival)
			_card_visual.modulate.a = clampf((1.0 - value) / 0.16, 0.0, 1.0)
		else:
			center = _source.lerp(_target, value) + Vector2(0, -sin(value * PI) * 60.0)
			_card_visual.scale = Vector2.ONE * lerpf(0.55, 1.0, value)
		_card_visual.position = center - _card_visual.size * 0.5
	queue_redraw()

func _draw() -> void:
	if _mode.is_empty(): return
	var fade := 1.0 - _progress
	var soft := Color(_color.r, _color.g, _color.b, 0.18 * fade)
	var bright := Color(_color.r, _color.g, _color.b, 0.92 * fade)
	if _mode == "attack":
		var charge := clampf(_progress / 0.34, 0.0, 1.0)
		draw_arc(_source, 20.0 + charge * 18.0, 0.0, TAU, 28, bright, 4.0, true)
		for i in range(6):
			var a := float(i) * TAU / 6.0 + _seed * 0.17
			draw_line(_source + Vector2.from_angle(a) * 26.0, _source + Vector2.from_angle(a) * (32.0 + charge * 12.0), soft, 3.0, true)
		if _progress > 0.24:
			var travel := clampf((_progress - 0.24) / 0.55, 0.0, 1.0)
			var tip := _source.lerp(_target, travel)
			draw_line(_source, tip, soft, 15.0, true)
			draw_line(_source, tip, bright, 4.0, true)
			draw_circle(tip, 7.0 + 3.0 * fade, bright)
		if _progress > 0.7: _draw_burst(_target, (_progress - 0.7) / 0.3, bright)
		return
	if _mode == "hit":
		var travel := minf(1.0, _progress * 1.75)
		var tip := _source.lerp(_target, travel)
		draw_line(_source, tip, soft, 18.0, true)
		draw_line(_source, tip, bright, 5.0, true)
		if travel >= 0.78:
			var impact := clampf((_progress - 0.43) / 0.57, 0.0, 1.0)
			draw_arc(_target, 15.0 + impact * 54.0, 0.0, TAU, 32, bright, 5.0, true)
			_draw_burst(_target, impact, bright)
		return
	if _mode == "block":
		var impact := clampf(_progress / 0.45, 0.0, 1.0)
		draw_arc(_target, 24.0 + impact * 32.0, 0.0, TAU, 32, bright, 5.0, true)
		draw_line(_target + Vector2(-30, -23) * (1.0 - impact), _target + Vector2(30, 23) * (1.0 - impact), bright, 5.0, true)
		draw_line(_target + Vector2(-30, 23) * (1.0 - impact), _target + Vector2(30, -23) * (1.0 - impact), bright, 5.0, true)
		_draw_burst(_target, impact, bright)
		return
	if _mode == "result":
		draw_arc(_target, 28.0 + _progress * 45.0, 0.0, TAU, 36, bright, 4.0, true)
		_draw_burst(_target, _progress, bright)
		return
	if _mode == "heal":
		for i in range(5):
			var p := _target + Vector2((i - 2) * 15.0, 18.0 - _progress * 52.0 - absf(i - 2) * 4.0)
			draw_circle(p, 4.0 * fade, bright)
		draw_arc(_target, 30.0 + _progress * 30.0, 0.0, TAU, 30, bright, 3.0, true)
		return
	if _mode == "turn": draw_arc(_target, 26.0 + _progress * 34.0, -PI * 0.75, PI * 0.75, 28, bright, 3.0, true)

func _draw_burst(center: Vector2, amount: float, color: Color) -> void:
	var alpha_color := Color(color.r, color.g, color.b, color.a * (1.0 - amount * 0.55))
	for i in range(8):
		var angle := float(i) * TAU / 8.0 + _seed * 0.29
		draw_line(center + Vector2.from_angle(angle) * (10.0 + amount * 9.0), center + Vector2.from_angle(angle) * (18.0 + amount * 34.0), alpha_color, 3.0, true)
