class_name EngineSound
extends AudioStreamPlayer
## Live engine note: pitch follows the fake gearbox rpm, timbre per car.

const SR := 22050.0

var car: Car
var base := 38.0
var harsh := 0.5
var _pb: AudioStreamGeneratorPlayback
var _ph := 0.0
var _ph2 := 0.0
var _lp := 0.0
var _amp := 0.0
var _rng := RandomNumberGenerator.new()


func setup(c: Car) -> void:
	car = c
	var es: Dictionary = c.spec["engine_sound"]
	base = es["base"]
	harsh = es["harsh"]
	var g := AudioStreamGenerator.new()
	g.mix_rate = SR
	g.buffer_length = 0.12
	stream = g
	apply_volume()
	play()
	_pb = get_stream_playback()


func apply_volume() -> void:
	volume_db = linear_to_db(maxf(float(GameState.settings["engine"]) * 0.9, 0.0001))


func _process(_delta: float) -> void:
	if not _pb or not car:
		return
	var n := _pb.get_frames_available()
	if n <= 0:
		return
	var inc := base * (0.55 + car.rpm * 2.4) / SR
	var target := 0.10 + 0.16 * car.throttle + 0.05 * car.rpm
	var cutoff := 0.12 + 0.35 * car.throttle
	var noise := 0.08 * car.throttle
	var buf := PackedVector2Array()
	buf.resize(n)
	for i in n:
		_amp += (target - _amp) * 0.002
		_ph = fmod(_ph + inc, 1.0)
		_ph2 = fmod(_ph2 + inc * 0.5, 1.0)
		var pulse := 1.0 if _ph2 < 0.35 else -0.6
		var s := sin(_ph * TAU) * (1.0 - harsh) + (_ph * 2.0 - 1.0) * harsh * 0.6 + pulse * 0.25 + _rng.randf_range(-1.0, 1.0) * noise
		_lp += (s - _lp) * cutoff
		var v := _lp * _amp
		buf[i] = Vector2(v, v)
	_pb.push_buffer(buf)
