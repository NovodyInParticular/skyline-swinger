extends Node
## Autoload "Sfx": procedural sound effects. Each sound is one or more synth voices
## (a pitch sweep with optional noise) mixed into a single AudioStreamGenerator.

const MIX_RATE := 22050.0
const MAX_VOICES := 16

## kind -> list of voices: [duration s, start Hz, end Hz, amplitude, noise 0..1, wave (0 sine, 1 square), delay s]
const SOUNDS := {
	"fire": [[0.10, 1500.0, 500.0, 0.20, 0.35, 0, 0.0]],
	"attach": [[0.09, 240.0, 110.0, 0.40, 0.45, 0, 0.0]],
	"miss": [[0.07, 320.0, 200.0, 0.12, 0.2, 1, 0.0]],
	"release": [[0.07, 600.0, 950.0, 0.12, 0.1, 0, 0.0]],
	"jump": [[0.10, 300.0, 540.0, 0.10, 0.0, 1, 0.0]],
	"dash": [[0.28, 700.0, 180.0, 0.35, 0.85, 0, 0.0]],
	"land": [[0.20, 130.0, 45.0, 0.55, 0.6, 0, 0.0]],
	"orb": [[0.09, 880.0, 880.0, 0.22, 0.0, 0, 0.0], [0.14, 1320.0, 1320.0, 0.22, 0.0, 0, 0.07]],
	"drone": [[0.25, 420.0, 700.0, 0.07, 0.1, 1, 0.0]],
	"start": [[0.12, 440.0, 440.0, 0.15, 0.0, 0, 0.0], [0.12, 660.0, 660.0, 0.15, 0.0, 0, 0.1], [0.2, 880.0, 880.0, 0.15, 0.0, 0, 0.2]],
	"game_over": [[0.9, 420.0, 70.0, 0.25, 0.15, 1, 0.0]],
	"click": [[0.03, 1100.0, 1100.0, 0.08, 0.0, 0, 0.0]],
}

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _voices: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = MIX_RATE
	generator.buffer_length = 0.1
	_player = AudioStreamPlayer.new()
	_player.stream = generator
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _exit_tree() -> void:
	_player.stop()
	_player.stream = null
	_playback = null   # drop the stream reference so nothing leaks at exit


func play(kind: String) -> void:
	if not SOUNDS.has(kind):
		push_warning("Unknown sound: %s" % kind)
		return
	for spec: Array in SOUNDS[kind]:
		_voices.append({
			"t": -float(spec[6]), "dur": float(spec[0]), "f0": float(spec[1]), "f1": float(spec[2]),
			"amp": float(spec[3]), "noise": float(spec[4]), "wave": int(spec[5]), "phase": 0.0,
		})
	if _voices.size() > MAX_VOICES:
		_voices = _voices.slice(_voices.size() - MAX_VOICES)


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var frames := _playback.get_frames_available()
	if frames <= 0:
		return
	var buffer := PackedVector2Array()
	buffer.resize(frames)   # zero-filled: silence when nothing plays
	if not _voices.is_empty():
		_mix(buffer, frames)
	_playback.push_buffer(buffer)


func _mix(buffer: PackedVector2Array, frames: int) -> void:
	var dt := 1.0 / MIX_RATE
	for i in frames:
		var sample := 0.0
		for v in _voices:
			var t: float = v.t
			var dur: float = v.dur
			if t >= 0.0 and t < dur:
				var k := t / dur
				var freq: float = lerpf(v.f0, v.f1, k)
				var phase: float = fmod(v.phase + freq * dt, 1.0)
				v.phase = phase
				var tone := sin(TAU * phase) if v.wave == 0 else (0.5 if phase < 0.5 else -0.5)
				var noise: float = v.noise
				var envelope := minf(t / 0.004, 1.0) * (1.0 - k) * (1.0 - k)
				sample += (tone * (1.0 - noise) + _rng.randf_range(-1.0, 1.0) * noise) * envelope * float(v.amp)
			v.t = t + dt
		sample = clampf(sample, -1.0, 1.0)
		buffer[i] = Vector2(sample, sample)
	_voices = _voices.filter(func(v: Dictionary) -> bool: return v.t < v.dur)
