class_name CombatAudio
extends Node

const MIX_RATE := 44100
var enabled := true
var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _noise := RandomNumberGenerator.new()

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: stop_all()

func play_event(kind: String) -> void:
	if not enabled: return
	var player := AudioStreamPlayer.new()
	player.stream = _stream_for(kind)
	player.volume_db = -12.0 if kind in ["attack", "hit"] else -15.0
	add_child(player)
	_players.append(player)
	player.finished.connect(func() -> void:
		_players.erase(player)
		if is_instance_valid(player): player.queue_free()
	)
	player.play()

func stop_all() -> void:
	for player in _players:
		if is_instance_valid(player): player.stop(); player.queue_free()
	_players.clear()

func _stream_for(kind: String) -> AudioStreamWAV:
	if _streams.has(kind): return _streams[kind]
	var spec: Dictionary = {
		"attack": {"start": 220.0, "end": 520.0, "duration": 0.18, "noise": 0.04},
		"hit": {"start": 120.0, "end": 72.0, "duration": 0.15, "noise": 0.16},
		"block": {"start": 760.0, "end": 310.0, "duration": 0.16, "noise": 0.08},
		"buffer": {"start": 330.0, "end": 580.0, "duration": 0.16, "noise": 0.02},
		"heal": {"start": 430.0, "end": 820.0, "duration": 0.28, "noise": 0.01},
		"turn": {"start": 260.0, "end": 390.0, "duration": 0.22, "noise": 0.01},
		"draw": {"start": 620.0, "end": 1050.0, "duration": 0.18, "noise": 0.14},
		"card_play": {"start": 420.0, "end": 240.0, "duration": 0.20, "noise": 0.10}
	}
	var s: Dictionary = spec.get(kind, spec.turn)
	var count := int(float(s.duration) * MIX_RATE)
	var bytes := PackedByteArray()
	var phase := 0.0
	for i in range(count):
		var t := float(i) / float(count)
		var freq := lerpf(float(s.start), float(s.end), t)
		var envelope := minf(1.0, t * 18.0) * minf(1.0, (1.0 - t) * 10.0)
		phase += TAU * freq / MIX_RATE
		var sample := (sin(phase) * 0.8 + sin(phase * 2.01) * 0.2) * envelope
		if float(s.noise) > 0.0: sample += _noise.randf_range(-float(s.noise), float(s.noise)) * envelope
		var value := clampi(int(sample * 15000.0), -32768, 32767)
		bytes.append(value & 255)
		bytes.append((value >> 8) & 255)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	_streams[kind] = stream
	return stream
