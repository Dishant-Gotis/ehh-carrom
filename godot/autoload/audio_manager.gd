extends Node

## Audio system for Carrom Board 3D.
## Autoload singleton — access via AudioManager.

enum SFX { PIECE_COLLISION, STRIKER_WALL, PIECE_WALL, POT, POWER_BAR }

const SOUND_PATHS: Dictionary = {
	SFX.PIECE_COLLISION: "res://assets/audio/carrom_carrommen_cd.wav",
	SFX.STRIKER_WALL: "res://assets/audio/carrom_striker_wall.wav",
	SFX.PIECE_WALL: "res://assets/audio/Carrom_carrommen_wall.wav",
	SFX.POT: "res://assets/audio/carrom_pot_sound.wav",
	SFX.POWER_BAR: "res://assets/audio/carrom_power_bar.wav",
}

const DEFAULT_GAINS: Dictionary = {
	SFX.PIECE_COLLISION: 0.3,
	SFX.STRIKER_WALL: 0.7,
	SFX.PIECE_WALL: 0.4,
	SFX.POT: 0.7,
	SFX.POWER_BAR: 0.7,
}

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _power_bar_player: AudioStreamPlayer = null


func _ready() -> void:
	# Load all audio streams
	for sfx_id: int in SOUND_PATHS:
		var path: String = String(SOUND_PATHS[sfx_id])
		var stream: AudioStream = load(path) as AudioStream
		if stream:
			_streams[sfx_id] = stream

	# Create a pool of audio players for one-shot sounds
	for i in range(8):
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_players.append(player)

	# Dedicated looping player for power bar
	_power_bar_player = AudioStreamPlayer.new()
	_power_bar_player.bus = "Master"
	add_child(_power_bar_player)
	if _streams.has(SFX.POWER_BAR):
		_power_bar_player.stream = _streams[SFX.POWER_BAR] as AudioStream


func play_sound(sfx: SFX, volume: float = -1.0) -> void:
	if not _streams.has(sfx):
		return
	var gain: float = volume if volume >= 0.0 else float(DEFAULT_GAINS.get(sfx, 0.5))
	# Find a free player
	for player in _players:
		if not player.playing:
			player.stream = _streams[sfx] as AudioStream
			player.volume_db = linear_to_db(gain)
			player.play()
			return
	# All busy — use first player (interrupt)
	_players[0].stream = _streams[sfx]
	_players[0].volume_db = linear_to_db(gain)
	_players[0].play()


func play_collision_sound(sfx: SFX, velocity: float) -> void:
	## Dynamic volume: louder collisions = louder sound.
	var gain: float = float(DEFAULT_GAINS.get(sfx, 0.5))
	if velocity > 1.0:
		gain = clampf(gain * velocity * 0.01, 0.1, 1.0)
	play_sound(sfx, gain)


func play_power_bar() -> void:
	if _power_bar_player and not _power_bar_player.playing:
		_power_bar_player.volume_db = linear_to_db(float(DEFAULT_GAINS[SFX.POWER_BAR]))
		_power_bar_player.play()


func stop_power_bar() -> void:
	if _power_bar_player:
		_power_bar_player.stop()
