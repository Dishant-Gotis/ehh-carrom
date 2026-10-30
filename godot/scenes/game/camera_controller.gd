extends Camera3D

## Camera system with presets for each game state.
## Scale: 1 unit = 1 cm. Positions in cm.

const PRESETS := {
	GameManager.State.PLACE_STRIKER: {
		"position": Vector3(0, 112, 5),
		"rotation": Vector3(-85, 0, 0),
	},
	GameManager.State.AIM: {
		"position": Vector3(0, 60, 55),
		"rotation": Vector3(-50, 0, 0),
	},
	GameManager.State.POWER: {
		"position": Vector3(0, 60, 55),
		"rotation": Vector3(-50, 0, 0),
	},
	GameManager.State.SIMULATION: {
		"position": Vector3(0, 85, 25),
		"rotation": Vector3(-70, 0, 0),
	},
}

const PRESETS_P2 := {
	GameManager.State.PLACE_STRIKER: {
		"position": Vector3(0, 112, -5),
		"rotation": Vector3(-85, 180, 0),
	},
	GameManager.State.AIM: {
		"position": Vector3(0, 60, -55),
		"rotation": Vector3(-50, 180, 0),
	},
	GameManager.State.POWER: {
		"position": Vector3(0, 60, -55),
		"rotation": Vector3(-50, 180, 0),
	},
	GameManager.State.SIMULATION: {
		"position": Vector3(0, 85, -25),
		"rotation": Vector3(-70, 180, 0),
	},
}

var _tween: Tween = null
const TRANSITION_DURATION := 0.5


func _ready() -> void:
	GameManager.state_changed.connect(_on_state_changed)
	GameManager.turn_changed.connect(_on_turn_changed)
	_apply_preset_instant(GameManager.State.PLACE_STRIKER, 1)


func _on_state_changed(new_state: int) -> void:
	_transition_to(new_state, GameManager.current_player)


func _on_turn_changed(_player: int) -> void:
	pass


func _transition_to(state: int, player: int) -> void:
	var presets: Dictionary = PRESETS if player == 1 else PRESETS_P2
	if not presets.has(state):
		return

	var preset: Dictionary = presets[state]
	var target_pos: Vector3 = preset["position"]
	var target_rot: Vector3 = preset["rotation"]

	if _tween:
		_tween.kill()

	_tween = create_tween()
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_trans(Tween.TRANS_CUBIC)
	_tween.set_parallel(true)
	_tween.tween_property(self, "position", target_pos, TRANSITION_DURATION)
	_tween.tween_property(self, "rotation_degrees", target_rot, TRANSITION_DURATION)


func _apply_preset_instant(state: int, player: int) -> void:
	var presets: Dictionary = PRESETS if player == 1 else PRESETS_P2
	if not presets.has(state):
		return
	var preset: Dictionary = presets[state]
	position = preset["position"] as Vector3
	rotation_degrees = preset["rotation"] as Vector3
