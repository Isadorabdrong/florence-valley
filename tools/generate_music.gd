extends SceneTree
## Composes and renders Florence Valley's original background music:
## one loop per season plus the title theme (22.05 kHz mono WAV).
##   godot --headless --path . --script res://tools/generate_music.gd
##
## Each track = soft pad chords + a plucked melody (pentatonic, chosen from
## the chord with a seeded RNG, so output is deterministic) + a gentle bass,
## and per-track colour (music box, shaker, bells…). The tail of the render
## is folded into the start, so loops are seamless.

const RATE := 22050
const OUT_DIR := "res://assets/audio/music/"

## Semitone offsets for chord degrees in a major / minor key.
const MAJOR := [0, 2, 4, 5, 7, 9, 11]
const MINOR := [0, 2, 3, 5, 7, 8, 10]

const TRACKS := {
	"spring": {"root": 60, "scale": "major", "bpm": 92, "bars": 12, "seed": 11,
		"progression": [0, 4, 5, 3], "lead": "musicbox", "pad": 0.22, "shaker": false},
	"summer": {"root": 55, "scale": "major", "bpm": 100, "bars": 12, "seed": 23,
		"progression": [0, 3, 4, 3], "lead": "pluck", "pad": 0.2, "shaker": true},
	"autumn": {"root": 57, "scale": "minor", "bpm": 84, "bars": 12, "seed": 37,
		"progression": [0, 5, 2, 6], "lead": "pluck", "pad": 0.26, "shaker": false},
	"winter": {"root": 62, "scale": "major", "bpm": 72, "bars": 10, "seed": 41,
		"progression": [0, 2, 3, 0], "lead": "bell", "pad": 0.28, "shaker": false},
	"title": {"root": 65, "scale": "major", "bpm": 76, "bars": 10, "seed": 53,
		"progression": [0, 5, 3, 4], "lead": "musicbox", "pad": 0.26, "shaker": false},
}

var _rng := RandomNumberGenerator.new()
var _failed := false


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for name: String in TRACKS:
		_write(OUT_DIR + name + ".wav", _render(TRACKS[name]))
	quit(1 if _failed else 0)


static func midi_hz(note: float) -> float:
	return 440.0 * pow(2.0, (note - 69.0) / 12.0)


func _chord_notes(spec: Dictionary, degree: int) -> Array[int]:
	var scale: Array = MAJOR if spec["scale"] == "major" else MINOR
	var root: int = spec["root"]
	var out: Array[int] = []
	for step in [0, 2, 4]:
		var d: int = degree + step
		out.append(root + int(scale[d % 7]) + 12 * (d / 7))
	return out


func _render(spec: Dictionary) -> PackedFloat32Array:
	_rng.seed = spec["seed"]
	var beat := 60.0 / float(spec["bpm"])
	var bar := beat * 4.0
	var bars: int = spec["bars"]
	var length := bar * bars
	var total := int((length + bar) * RATE) # one extra bar of tail
	var buf := PackedFloat32Array()
	buf.resize(total)
	var progression: Array = spec["progression"]
	var scale: Array = MAJOR if spec["scale"] == "major" else MINOR
	var pent := [0, 1, 2, 4, 5] if spec["scale"] == "major" else [0, 2, 3, 4, 6]
	for b in bars:
		var degree: int = progression[b % progression.size()]
		var chord := _chord_notes(spec, degree)
		var t0 := b * bar
		# pad: whole bar, slow attack and release
		for n in chord:
			_add_pad(buf, t0, bar * 1.05, midi_hz(n), float(spec["pad"]))
		# bass on beats 1 and 3
		_add_bass(buf, t0, beat * 1.8, midi_hz(chord[0] - 24), 0.32)
		_add_bass(buf, t0 + beat * 2.0, beat * 1.8, midi_hz(chord[0] - 24 + (7 if b % 2 else 0)), 0.24)
		# melody: 8th notes, rests, pentatonic around the chord
		var step := 0
		while step < 8:
			if _rng.randf() < (0.32 if spec["lead"] == "bell" else 0.22):
				step += 1
				continue
			var long := _rng.randf() < 0.3
			var deg: int = degree + int(pent[_rng.randi_range(0, pent.size() - 1)])
			var note: int = int(spec["root"]) + 12 + int(scale[deg % 7]) + 12 * (deg / 7)
			var dur := beat * (1.0 if long else 0.5)
			_add_lead(buf, t0 + step * beat * 0.5, dur * 2.5, midi_hz(note), str(spec["lead"]))
			step += 2 if long else 1
		if spec["shaker"]:
			for k in 8:
				_add_shaker(buf, t0 + k * beat * 0.5, 0.05 if k % 2 == 0 else 0.03)
	# fold the tail into the start so the loop is seamless
	var n_loop := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(n_loop)
	for i in n_loop:
		out[i] = buf[i]
	for i in range(n_loop, total):
		out[i - n_loop] += buf[i]
	return out


func _add_pad(buf: PackedFloat32Array, start: float, dur: float, hz: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var n := int(dur * RATE)
	for i in n:
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / RATE
		var env := minf(t / 0.6, 1.0) * minf((dur - t) / 0.5, 1.0)
		var v := sin(TAU * hz * t) + 0.6 * sin(TAU * hz * 1.003 * t) + 0.25 * sin(TAU * hz * 2.0 * t)
		buf[idx] += v * env * amp * 0.33


func _add_bass(buf: PackedFloat32Array, start: float, dur: float, hz: float, amp: float) -> void:
	var i0 := int(start * RATE)
	for i in int(dur * RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / RATE
		var env := minf(t / 0.02, 1.0) * exp(-t * 2.2)
		buf[idx] += (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t)) * env * amp


func _add_lead(buf: PackedFloat32Array, start: float, dur: float, hz: float, kind: String) -> void:
	var i0 := int(start * RATE)
	for i in int(dur * RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var t := float(i) / RATE
		var v := 0.0
		match kind:
			"musicbox":
				v = (sin(TAU * hz * t) + 0.5 * sin(TAU * hz * 4.0 * t) * exp(-t * 9.0)) * exp(-t * 3.2) * 0.22
			"bell":
				v = (sin(TAU * hz * t) + 0.4 * sin(TAU * hz * 2.76 * t) + 0.2 * sin(TAU * hz * 5.4 * t)) * exp(-t * 1.8) * 0.18
			_:
				v = (sin(TAU * hz * t) + 0.3 * sin(TAU * hz * 2.0 * t) + 0.15 * sin(TAU * hz * 3.0 * t)) * exp(-t * 4.5) * 0.24
		buf[idx] += v * minf(t / 0.004, 1.0)


func _add_shaker(buf: PackedFloat32Array, start: float, amp: float) -> void:
	var i0 := int(start * RATE)
	var hp := 0.0
	for i in int(0.06 * RATE):
		var idx := i0 + i
		if idx >= buf.size():
			return
		var n := _rng.randf_range(-1.0, 1.0)
		hp = n - hp * 0.5
		buf[idx] += hp * exp(-float(i) / RATE * 60.0) * amp


func _write(path: String, samples: PackedFloat32Array) -> void:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var gain := 0.7 / peak
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i] * gain, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = bytes
	if wav.save_to_wav(path) != OK:
		push_error("[music] could not save %s" % path)
		_failed = true
	else:
		print("[music] wrote %s (%.1f s)" % [path, samples.size() / float(RATE)])
