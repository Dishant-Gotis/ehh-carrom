extends Node

## Game state machine & logic for Carrom Board 3D.
## Autoload singleton — access via GameManager.
## Scale: 1 unit = 1 cm.

# --- Signals ---
signal state_changed(new_state: int)
signal turn_changed(player: int)
signal score_updated(player: int, score: int)
signal piece_pocketed(piece: RigidBody3D, player: int)
signal foul_committed(player: int, reason: String)
signal game_over(winner: int)

# --- Enums ---
enum State { PLACE_STRIKER, AIM, POWER, SIMULATION }
enum PieceColor { BLACK, WHITE, RED }

# --- Constants (all in cm) ---
const BOARD_HALF := 37.0
const PLACEMENT_Y := -29.0
const PLACEMENT_X_MIN := -18.5
const PLACEMENT_X_MAX := 18.5
const MAX_POWER := 5.0
const POWER_CHARGE_SPEED := 3.0  # units per second
const STOP_THRESHOLD := 0.5  # cm/s — imperceptible at this scale
const STOP_CONFIRM_FRAMES := 12  # consecutive frames below threshold before resolving (~0.2s at 60fps)
const MIN_SIMULATION_TIME := 0.5  # seconds — prevents zero-power instant resolve
const SCORE_BLACK := 10
const SCORE_WHITE := 20
const SCORE_QUEEN := 50

# --- State ---
var current_state: State = State.PLACE_STRIKER
var current_player: int = 1
var scores: Array[int] = [0, 0]
var aim_direction: Vector3 = Vector3(0, 0, -1)
var power: float = 0.0
var is_charging: bool = false

var pieces: Array[RigidBody3D] = []
var striker: RigidBody3D = null
var queen: RigidBody3D = null
var queen_pocketed_by: int = -1
var queen_covered: bool = false

var pocketed_this_turn: Array[RigidBody3D] = []
var striker_pocketed: bool = false
var own_piece_pocketed: bool = false

var game_active: bool = true

# --- Debug ---
var _sim_frame_count: int = 0
var _sim_log_interval: int = 30

# --- Stop detection ---
var _stop_confirm_count: int = 0
var _sim_elapsed: float = 0.0


func _ready() -> void:
	set_process(true)
	print("[GM] _ready()")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("reset_board"):
		get_tree().reload_current_scene()


func _process(delta: float) -> void:
	if not game_active:
		return

	match current_state:
		State.POWER:
			if is_charging:
				power = minf(power + POWER_CHARGE_SPEED * delta, MAX_POWER)
		State.SIMULATION:
			_sim_frame_count += 1
			if _sim_frame_count <= 5 or _sim_frame_count % _sim_log_interval == 0:
				_log_simulation_frame()


func _physics_process(delta: float) -> void:
	if current_state == State.SIMULATION:
		_sim_elapsed += delta
		if striker and _sim_frame_count <= 3:
			print("[PHYS] frame=%d vel=%.2f pos=%s" % [
				_sim_frame_count, striker.linear_velocity.length(), striker.global_position])
		_check_simulation_complete()


func _log_simulation_frame() -> void:
	if not striker:
		return
	var max_vel := 0.0
	var moving := 0
	for piece in pieces:
		if piece.visible:
			var v := piece.linear_velocity.length()
			if v > max_vel:
				max_vel = v
			if v > STOP_THRESHOLD:
				moving += 1
	print("[SIM] frame=%d | striker: vel=%.2f | pieces: %d moving, max=%.2f" % [
		_sim_frame_count, striker.linear_velocity.length(), moving, max_vel])


func start_game() -> void:
	print("[GM] start_game()")
	current_player = 1
	scores = [0, 0]
	queen_pocketed_by = -1
	queen_covered = false
	game_active = true
	_set_state(State.PLACE_STRIKER)


func _set_state(new_state: State) -> void:
	var old_name: String = State.keys()[current_state]
	var new_name: String = State.keys()[new_state]
	print("[STATE] %s → %s | player=%d" % [old_name, new_name, current_player])
	current_state = new_state
	state_changed.emit(new_state)


# --- Striker Placement ---

func place_striker_at(x_pos: float) -> void:
	if current_state != State.PLACE_STRIKER or striker == null:
		return
	var clamped_x := clampf(x_pos, PLACEMENT_X_MIN, PLACEMENT_X_MAX)
	var placement_z: float = -PLACEMENT_Y if current_player == 1 else PLACEMENT_Y
	striker.global_position = Vector3(clamped_x, 0.2, placement_z)
	striker.rotation = Vector3.ZERO
	striker.linear_velocity = Vector3.ZERO
	striker.angular_velocity = Vector3.ZERO
	striker.freeze = true


func confirm_placement() -> void:
	if current_state != State.PLACE_STRIKER:
		return
	_set_state(State.AIM)


# --- Aiming ---

func set_aim_direction(dir: Vector3) -> void:
	if current_state != State.AIM:
		return
	aim_direction = dir.normalized()


func confirm_aim() -> void:
	if current_state != State.AIM:
		return
	power = 0.0
	is_charging = false
	_set_state(State.POWER)


# --- Power ---

func release_power() -> void:
	if current_state != State.POWER:
		return
	is_charging = false
	AudioManager.stop_power_bar()
	_shoot_striker()


func _shoot_striker() -> void:
	if striker == null:
		return

	striker.freeze = false

	# aim_direction is already the world-space shot direction (set by raycast)
	var speed := power * 22.0
	striker.linear_velocity = aim_direction * speed

	print("[SHOOT] power=%.2f speed=%.1f dir=%s vel=%s" % [
		power, speed, aim_direction, striker.linear_velocity])

	pocketed_this_turn.clear()
	striker_pocketed = false
	own_piece_pocketed = false
	_sim_frame_count = 0
	_stop_confirm_count = 0
	_sim_elapsed = 0.0
	_set_state(State.SIMULATION)


# --- Simulation / Stop Detection ---

func _check_simulation_complete() -> void:
	if striker == null:
		return
	if _sim_elapsed < MIN_SIMULATION_TIME:
		return

	var all_stopped := true
	for piece in pieces:
		if piece.visible and piece.linear_velocity.length() > STOP_THRESHOLD:
			all_stopped = false
			break
	if all_stopped and striker.linear_velocity.length() > STOP_THRESHOLD:
		all_stopped = false

	if all_stopped:
		_stop_confirm_count += 1
	else:
		_stop_confirm_count = 0

	if _stop_confirm_count >= STOP_CONFIRM_FRAMES:
		print("[SIM] === ALL STOPPED at frame %d (confirmed over %d frames) ===" % [
			_sim_frame_count, STOP_CONFIRM_FRAMES])
		_resolve_turn()


func _resolve_turn() -> void:
	_return_count = 0

	if striker_pocketed:
		foul_committed.emit(current_player, "Striker pocketed!")
		_handle_foul()
		return

	if queen_pocketed_by == current_player and not queen_covered:
		if own_piece_pocketed:
			queen_covered = true
		else:
			foul_committed.emit(current_player, "Queen not covered!")
			_return_queen_to_center()
			queen_pocketed_by = -1
			_switch_turn()
			return

	_return_opponent_pieces()

	if _check_win():
		return

	if own_piece_pocketed:
		_set_state(State.PLACE_STRIKER)
	else:
		_switch_turn()


func _handle_foul() -> void:
	var next_player := 2 if current_player == 1 else 1
	var placement_z: float = -PLACEMENT_Y if next_player == 1 else PLACEMENT_Y
	striker.global_position = Vector3(0, 0.2, placement_z)
	striker.linear_velocity = Vector3.ZERO
	striker.angular_velocity = Vector3.ZERO
	striker.freeze = true
	striker.visible = true
	striker_pocketed = false

	var player_color := PieceColor.BLACK if current_player == 1 else PieceColor.WHITE
	for piece in pieces:
		var pc: int = piece.get_meta("color", PieceColor.BLACK) as int
		if pc == player_color and not piece.visible:
			_return_piece_to_center(piece)
			break

	_switch_turn()


var _return_count: int = 0

func _return_piece_to_center(piece: RigidBody3D) -> void:
	var angle := _return_count * PI * 2.0 / 3.0 + randf_range(-0.3, 0.3)
	var dist := 2.0 + _return_count * 1.5  # cm offset from center
	var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
	piece.global_position = Vector3(0, 0.2, 0) + offset
	piece.linear_velocity = Vector3.ZERO
	piece.angular_velocity = Vector3.ZERO
	piece.visible = true
	piece.freeze = false
	_return_count += 1


func _return_opponent_pieces() -> void:
	var opponent_color := PieceColor.WHITE if current_player == 1 else PieceColor.BLACK
	for piece in pocketed_this_turn:
		var pc: int = piece.get_meta("color", PieceColor.BLACK) as int
		if pc == opponent_color:
			_return_piece_to_center(piece)
			var points := SCORE_WHITE if pc == PieceColor.WHITE else SCORE_BLACK
			scores[current_player - 1] -= points
			score_updated.emit(current_player, scores[current_player - 1])


func _switch_turn() -> void:
	current_player = 2 if current_player == 1 else 1
	turn_changed.emit(current_player)
	_set_state(State.PLACE_STRIKER)


func _return_queen_to_center() -> void:
	if queen != null and not queen.visible:
		queen.global_position = Vector3(0, 0.2, 0)
		queen.linear_velocity = Vector3.ZERO
		queen.angular_velocity = Vector3.ZERO
		queen.visible = true
		queen.freeze = false


func _check_win() -> int:
	var black_remaining := 0
	var white_remaining := 0
	for piece in pieces:
		if not piece.visible:
			continue
		if piece == queen:
			continue
		var pc: int = piece.get_meta("color", PieceColor.BLACK) as int
		if pc == PieceColor.BLACK:
			black_remaining += 1
		elif pc == PieceColor.WHITE:
			white_remaining += 1

	if black_remaining == 0 and queen_covered and queen_pocketed_by == 1:
		_end_game(1)
		return 1
	if white_remaining == 0 and queen_covered and queen_pocketed_by == 2:
		_end_game(2)
		return 2
	return 0


func _end_game(winner: int) -> void:
	game_active = false
	game_over.emit(winner)


# --- Pocket Events ---

func on_piece_pocketed(body: RigidBody3D) -> void:
	if not game_active:
		return
	if not body.visible:
		return  # already pocketed (duplicate body_entered signal)

	AudioManager.play_sound(AudioManager.SFX.POT, 0.7)

	if body == striker:
		striker_pocketed = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		body.visible = false
		body.global_position = Vector3(0, -100, 0)
		return

	body.visible = false
	body.freeze = true
	body.global_position = Vector3(0, -100, 0)
	pocketed_this_turn.append(body)

	var piece_color: int = body.get_meta("color", PieceColor.BLACK) as int

	var points := 0
	match piece_color:
		PieceColor.BLACK:
			points = SCORE_BLACK
		PieceColor.WHITE:
			points = SCORE_WHITE
		PieceColor.RED:
			points = SCORE_QUEEN

	scores[current_player - 1] += points
	score_updated.emit(current_player, scores[current_player - 1])
	piece_pocketed.emit(body, current_player)

	if (current_player == 1 and piece_color == PieceColor.BLACK) or \
	   (current_player == 2 and piece_color == PieceColor.WHITE):
		own_piece_pocketed = true

	if piece_color == PieceColor.RED:
		queen_pocketed_by = current_player
		queen_covered = false
