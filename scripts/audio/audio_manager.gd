extends Node

## Procedural audio manager — generates simple tones at runtime so the game isn't silent.
## Add as autoload "AudioManager" in project.godot.

var _players: Array[AudioStreamPlayer] = []
const MAX_CONCURRENT := 8


func _ready() -> void:
	for i in range(MAX_CONCURRENT):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)


func _get_free_player() -> AudioStreamPlayer:
	for p in _players:
		if not p.playing:
			return p
	return _players[0]


# --- Public API ---

func play_fire() -> void:
	_play_tone(800.0, 0.06, -6.0)


func play_reload() -> void:
	_play_tone(400.0, 0.3, -10.0)


func play_hit() -> void:
	_play_tone(500.0, 0.08, -8.0)


func play_death() -> void:
	_play_tone(120.0, 0.4, -4.0)


func play_pickup() -> void:
	_play_tone(1200.0, 0.12, -10.0)


func play_grenade() -> void:
	_play_tone(80.0, 0.5, -2.0)


func play_dash() -> void:
	_play_tone(600.0, 0.1, -12.0)


# --- Tone generation ---

func _play_tone(freq: float, duration: float, volume_db: float) -> void:
	var sample_rate := 22050
	var num_samples := int(sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = sample_rate
	audio.stereo = false

	var data := PackedByteArray()
	data.resize(num_samples * 2)

	for i in range(num_samples):
		var t := float(i) / sample_rate
		var envelope := 1.0 - (float(i) / num_samples)
		envelope *= envelope  # Quadratic falloff
		var sample := sin(t * freq * TAU) * envelope
		# Add a bit of noise for texture
		sample += randf_range(-0.05, 0.05) * envelope
		sample = clampf(sample, -1.0, 1.0)

		var val := int(sample * 32767.0)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF

	audio.data = data

	var player := _get_free_player()
	player.stream = audio
	player.volume_db = volume_db
	player.play()
