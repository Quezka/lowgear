extends Node
## Autoload "Sfx": small generated chimes.

const SR := 22050

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_streams["coin"] = _bells([[88, 0.0], [95, 0.07]], 0.6)
	_streams["trail"] = _bells([[84, 0.0], [88, 0.08], [91, 0.16], [96, 0.24]], 1.0)
	_streams["discover"] = _bells([[72, 0.0], [76, 0.12], [79, 0.24], [84, 0.36], [88, 0.5]], 1.8)
	_streams["reset"] = _whoosh(0.45)


func play(sound: String, vol := 1.0) -> void:
	if not _streams.has(sound):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[sound]
	p.volume_db = linear_to_db(maxf(vol * float(GameState.settings["sfx"]), 0.0001)) - 3.0
	p.play()


func _bells(notes: Array, dur: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	for nt in notes:
		var f := AudioUtil.hz(float(nt[0]))
		var s0 := int(float(nt[1]) * SR)
		for i in range(s0, n):
			var t := float(i - s0) / SR
			var env := exp(-t * 6.0) * minf(1.0, t * 400.0)
			buf[i] += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.0 * t) * exp(-t * 12.0)) * env * 0.22
	return AudioUtil.wav(AudioUtil.to_pcm(buf), SR)


func _whoosh(dur: float) -> AudioStreamWAV:
	var n := int(dur * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var lp := 0.0
	for i in n:
		var t := float(i) / dur / SR
		lp += (rng.randf_range(-1.0, 1.0) - lp) * (0.05 + 0.3 * t)
		buf[i] = lp * sin(PI * t) * 0.5
	return AudioUtil.wav(AudioUtil.to_pcm(buf), SR)
