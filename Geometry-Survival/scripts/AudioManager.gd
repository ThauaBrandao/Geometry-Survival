extends Node
## Áudio 100% procedural (autoload) — GDD §15.
## Efeitos sonoros e instrumentos são sintetizados uma vez em AudioStreamWAV
## (funciona em desktop e Web). A música é um sequenciador generativo que
## toca esses instrumentos com escalas, andamento e padrões por contexto:
## menu (ambiente calmo), Alpha (calmo), Beta (harmônicos circulares),
## Gamma (batidas glitch), vitória e derrota.

const RATE := 22050
const SFX_VOICES := 10
const MUSIC_VOICES := 14

var _sfx: Dictionary = {}
var _inst: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _music_players: Array[AudioStreamPlayer] = []
var _sfx_i := 0
var _mus_i := 0

# sequenciador
var _track: String = ""
var _pending_track: String = ""
var _step := 0
var _step_time := 0.0
var _acc := 0.0
var _gain := 0.0          # 0..1 (fade)
var _gain_target := 0.0
var _bar := 0
var _rng := RandomNumberGenerator.new()

const TRACKS := {
	"menu":  {"bpm": 68,  "root": 57, "scale": [0, 2, 3, 7, 9],  "chords": [[0, 3, 7], [-4, 0, 3], [-7, -3, 0], [-2, 2, 5]]},
	"alpha": {"bpm": 84,  "root": 60, "scale": [0, 2, 4, 7, 9],  "chords": [[0, 4, 7], [-3, 0, 4], [-7, -3, 0], [-5, -1, 2]]},
	"beta":  {"bpm": 96,  "root": 62, "scale": [0, 2, 4, 6, 7, 11], "chords": [[0, 4, 7], [2, 6, 9], [-1, 2, 7], [-3, 0, 4]]},
	"gamma": {"bpm": 112, "root": 52, "scale": [0, 1, 3, 5, 7, 8], "chords": [[0, 3, 7], [1, 5, 8], [-2, 1, 5], [0, 3, 8]]},
	"victory": {"bpm": 90, "root": 60, "scale": [0, 2, 4, 7, 9], "chords": [[0, 4, 7], [5, 9, 12], [7, 11, 14], [0, 4, 7]]},
	"defeat":  {"bpm": 60, "root": 50, "scale": [0, 2, 3, 7, 8], "chords": [[0, 3, 7], [-4, 0, 3]]},
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 424242
	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	for i in MUSIC_VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "Music"
		add_child(p)
		_music_players.append(p)
	_build_instruments()
	_build_sfx()


# ================================================================ API
func play(sfx: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _sfx.has(sfx):
		return
	var p := _sfx_players[_sfx_i]
	_sfx_i = (_sfx_i + 1) % SFX_VOICES
	p.stream = _sfx[sfx]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_music(track: String) -> void:
	if track == _track and _gain_target > 0.0:
		return
	if _track == "" or _gain <= 0.01:
		_start_track(track)
	else:
		_pending_track = track
		_gain_target = 0.0


func stop_music() -> void:
	_pending_track = ""
	_gain_target = 0.0


func current_track() -> String:
	return _track


# ================================================================ sequenciador
func _start_track(track: String) -> void:
	_track = track
	_pending_track = ""
	if not TRACKS.has(track):
		_track = ""
		return
	_step = 0
	_bar = 0
	_acc = 0.0
	_step_time = 60.0 / TRACKS[track].bpm / 4.0
	_gain_target = 1.0


func _process(delta: float) -> void:
	_gain = move_toward(_gain, _gain_target, delta * (0.7 if _gain_target > _gain else 1.4))
	if _pending_track != "" and _gain <= 0.01:
		_start_track(_pending_track)
	if _track == "" or _gain <= 0.001:
		return
	_acc += delta
	while _acc >= _step_time:
		_acc -= _step_time
		_tick()


func _note(inst: String, midi: float, vol_db: float) -> void:
	var data: Dictionary = _inst[inst]
	var p := _music_players[_mus_i]
	_mus_i = (_mus_i + 1) % MUSIC_VOICES
	p.stream = data.stream
	p.pitch_scale = pow(2.0, (midi - data.base) / 12.0)
	p.volume_db = vol_db + linear_to_db(maxf(_gain, 0.001))
	p.play()


func _tick() -> void:
	var t: Dictionary = TRACKS[_track]
	var root: int = t.root
	var chord: Array = t.chords[_bar % t.chords.size()]
	var s := _step % 16
	var scale: Array = t.scale
	match _track:
		"menu", "defeat":
			if s == 0:
				for n in chord:
					_note("pad", root + n, -13.0)
			if s % 4 == 2 and _rng.randf() < 0.45:
				_note("bell", root + 12 + scale[_rng.randi_range(0, scale.size() - 1)], -20.0)
		"alpha":
			if s == 0:
				for n in chord:
					_note("pad", root + n, -15.0)
				_note("bass", root - 12 + chord[0], -12.0)
			if s % 2 == 0:
				var arp := [0, 1, 2, 1]
				_note("pluck", root + 12 + chord[arp[(s / 2) % 4]], -17.0)
			if s == 0 or s == 8:
				_note("kick", 36, -12.0)
			if s % 4 == 2:
				_note("hat", 80, -24.0)
		"beta":
			if s == 0:
				for n in chord:
					_note("pad", root + n, -16.0)
				_note("bass", root - 12 + chord[0], -11.0)
			# arpejo circular: 1-3-5-8-5-3…
			var circ := [0, 1, 2, 3, 2, 1]
			var idx: int = circ[s % 6]
			var nn: int = (chord[idx] if idx < 3 else chord[0] + 12)
			if s % 2 == 0 or _rng.randf() < 0.25:
				_note("bell", root + 12 + nn, -19.0)
			if s == 0 or s == 10:
				_note("kick", 36, -11.0)
			if s % 2 == 1:
				_note("hat", 82, -25.0)
		"gamma":
			if s == 0:
				for n in chord:
					_note("pad", root + 12 + n, -18.0)
			if s in [0, 3, 6, 8, 11, 14]:
				_note("bass", root - 12 + chord[0] + (12 if s == 14 else 0), -9.0)
			if s in [0, 4, 8, 12] or (s == 14 and _rng.randf() < 0.5):
				_note("kick", 36, -9.0)
			if s % 2 == 1 or _rng.randf() < 0.2:
				_note("hat", 80 + _rng.randi_range(-4, 6), -21.0)
			if s == 12 and _rng.randf() < 0.35:   # glitch: rajada de hats
				for k in 3:
					_note("hat", 90 + k * 3, -23.0)
			if s % 4 == 2 and _rng.randf() < 0.4:
				_note("pluck", root + 24 + scale[_rng.randi_range(0, scale.size() - 1)], -20.0)
		"victory":
			if s == 0:
				for n in chord:
					_note("pad", root + n, -12.0)
				_note("bass", root - 12 + chord[0], -10.0)
			if s % 2 == 0:
				_note("bell", root + 12 + chord[(s / 2) % 3] + (12 if s >= 8 else 0), -17.0)
			if s == 0 or s == 8:
				_note("kick", 36, -12.0)
	_step += 1
	if _step % 16 == 0:
		_bar += 1


# ================================================================ síntese
func _to_stream(buf: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = buf.size()
	return s


func _osc(wave: String, phase: float) -> float:
	match wave:
		"sine": return sin(phase * TAU)
		"tri": return 1.0 - 4.0 * absf(fposmod(phase + 0.25, 1.0) - 0.5)
		"square": return 1.0 if fposmod(phase, 1.0) < 0.5 else -1.0
		"saw": return 2.0 * fposmod(phase, 1.0) - 1.0
	return 0.0


## Tom com envelope ADR, glissando e vibrato.
func _tone(dur: float, f0: float, f1: float, wave: String, vol: float,
		attack: float = 0.005, release: float = 0.1, curve: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var k := pow(float(i) / n, curve)
		var f := lerpf(f0, f1, k)
		phase += f / RATE
		var env := minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))
		buf[i] = _osc(wave, phase) * env * vol
	return buf


func _noise(dur: float, vol: float, attack: float, release: float, lp: float = 1.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		var env := minf(1.0, t / maxf(attack, 0.0001)) * minf(1.0, (dur - t) / maxf(release, 0.0001))
		buf[i] = y * env * vol
	return buf


func _mix(a: PackedFloat32Array, b: PackedFloat32Array, offset: float = 0.0) -> PackedFloat32Array:
	var off := int(offset * RATE)
	var n := maxi(a.size(), b.size() + off)
	var out := a.duplicate()
	out.resize(n)
	for i in b.size():
		out[i + off] += b[i]
	return out


func _bell(dur: float, f: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * 5.0 / dur) * minf(1.0, t / 0.004)
		buf[i] = (sin(TAU * f * t) + 0.35 * sin(TAU * f * 2.76 * t) * exp(-t * 6.0) + 0.2 * sin(TAU * f * 5.4 * t) * exp(-t * 12.0)) * env * vol
	return buf


func _pluck(dur: float, f: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += f / RATE
		var env := exp(-t * 7.0) * minf(1.0, t / 0.003)
		buf[i] = (_osc("tri", phase) * 0.8 + 0.2 * sin(TAU * phase * 2.0)) * env * vol
	return buf


func _pad(dur: float, f: float, vol: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var ph := [0.0, 0.0, 0.0, 0.0]
	var det := [1.0, 1.004, 0.996, 2.0]
	var amp := [0.45, 0.35, 0.35, 0.12]
	for i in n:
		var t := float(i) / RATE
		var env := minf(1.0, t / 0.9) * minf(1.0, (dur - t) / 1.4)
		var v := 0.0
		for k in 4:
			ph[k] += f * det[k] / RATE
			v += sin(TAU * ph[k]) * amp[k]
		v += 0.08 * _osc("saw", ph[0]) * (0.5 + 0.5 * sin(t * 1.3))
		buf[i] = v * env * vol
	return buf


func _kick() -> PackedFloat32Array:
	var n := int(0.32 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 45.0 + 95.0 * exp(-t * 28.0)
		phase += f / RATE
		buf[i] = sin(TAU * phase) * exp(-t * 11.0) * 0.9
	return buf


func _hat() -> PackedFloat32Array:
	var n := int(0.05 * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var w := _rng.randf_range(-1.0, 1.0)
		buf[i] = (w - prev) * 0.5 * exp(-t * 70.0)
		prev = w
	return buf


func _build_instruments() -> void:
	_inst = {
		"pad":   {"stream": _to_stream(_pad(3.2, 220.0, 0.5)), "base": 57},
		"pluck": {"stream": _to_stream(_pluck(0.6, 440.0, 0.5)), "base": 69},
		"bell":  {"stream": _to_stream(_bell(1.1, 880.0, 0.4)), "base": 81},
		"bass":  {"stream": _to_stream(_mix(_tone(0.5, 110.0, 110.0, "sine", 0.6, 0.005, 0.25),
			_tone(0.5, 220.0, 220.0, "tri", 0.15, 0.005, 0.2))), "base": 45},
		"kick":  {"stream": _to_stream(_kick()), "base": 36},
		"hat":   {"stream": _to_stream(_hat()), "base": 80},
	}


func _seq(notes: Array, step: float, note_dur: float, vol: float, bell := true) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for i in notes.size():
		var f := 440.0 * pow(2.0, (notes[i] - 69) / 12.0)
		var b := _bell(note_dur, f, vol) if bell else _pluck(note_dur, f, vol)
		out = _mix(out, b, i * step)
	return out


func _build_sfx() -> void:
	_sfx["ui_hover"] = _to_stream(_tone(0.05, 1500, 1800, "sine", 0.18, 0.002, 0.03))
	_sfx["ui_select"] = _to_stream(_mix(_tone(0.07, 660, 660, "tri", 0.3, 0.002, 0.03),
		_tone(0.1, 990, 990, "tri", 0.3, 0.002, 0.06), 0.06))
	_sfx["ui_back"] = _to_stream(_tone(0.12, 700, 380, "tri", 0.3, 0.002, 0.06))
	_sfx["type"] = _to_stream(_tone(0.018, 2200, 1900, "square", 0.05, 0.001, 0.01))
	_sfx["tick"] = _to_stream(_tone(0.025, 2600, 2600, "sine", 0.12, 0.001, 0.015))
	_sfx["charge"] = _to_stream(_mix(_tone(0.32, 260, 1100, "saw", 0.12, 0.01, 0.05, 0.6),
		_tone(0.32, 520, 2200, "sine", 0.18, 0.01, 0.05, 0.6)))
	_sfx["correct"] = _to_stream(_seq([84, 88, 91, 96], 0.07, 0.7, 0.3))
	_sfx["seal"] = _to_stream(_mix(_noise(0.55, 0.45, 0.005, 0.45, 0.35),
		_tone(0.55, 900, 120, "sine", 0.4, 0.005, 0.3, 0.5)))
	_sfx["wrong"] = _to_stream(_mix(_tone(0.32, 150, 140, "square", 0.12, 0.005, 0.15),
		_tone(0.32, 157, 146, "square", 0.12, 0.005, 0.15)))
	_sfx["soft_error"] = _to_stream(_tone(0.14, 330, 280, "tri", 0.25, 0.003, 0.08))
	_sfx["life_lost"] = _to_stream(_mix(_seq([64, 61, 57], 0.12, 0.5, 0.28, false),
		_noise(0.3, 0.3, 0.002, 0.25, 0.6)))
	_sfx["rift_open"] = _to_stream(_mix(_noise(0.9, 0.22, 0.3, 0.35, 0.08),
		_tone(0.9, 90, 420, "saw", 0.1, 0.2, 0.3, 1.5)))
	_sfx["rift_expand"] = _to_stream(_mix(_tone(0.8, 70, 45, "saw", 0.3, 0.01, 0.4),
		_noise(0.8, 0.35, 0.01, 0.5, 0.12)))
	_sfx["rift_close"] = _to_stream(_mix(_tone(0.35, 500, 90, "sine", 0.3, 0.005, 0.2),
		_noise(0.35, 0.18, 0.005, 0.25, 0.2)))
	_sfx["whoosh"] = _to_stream(_noise(0.5, 0.4, 0.22, 0.26, 0.15))
	_sfx["unlock"] = _to_stream(_seq([72, 76, 79, 84, 88], 0.08, 0.8, 0.26))
	_sfx["stamp"] = _to_stream(_mix(_kick(), _noise(0.12, 0.3, 0.001, 0.1, 0.5)))
	_sfx["star"] = _to_stream(_seq([91, 96], 0.05, 0.5, 0.25))
	_sfx["pause"] = _to_stream(_mix(_tone(0.08, 880, 880, "sine", 0.22, 0.002, 0.05),
		_tone(0.12, 660, 660, "sine", 0.22, 0.002, 0.08), 0.07))
	_sfx["victory"] = _to_stream(_mix(_seq([60, 64, 67, 72, 76, 79, 84], 0.11, 1.6, 0.24),
		_pad(2.6, 261.6, 0.25), 0.7))
	_sfx["defeat"] = _to_stream(_mix(_seq([67, 63, 60, 55], 0.28, 1.4, 0.24, false),
		_pad(2.2, 130.8, 0.22), 0.5))
