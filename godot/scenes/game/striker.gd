extends RigidBody3D

## Striker input handling — placement, aiming, and power control.
## Uses camera raycast for aim (point-to-aim) — works identically for both players.
## Scale: 1 unit = 1 cm.

const AIM_DOT_COUNT := 12
const AIM_DOT_SPACING := 4.0  # cm between dots
const AIM_DOT_RADIUS := 0.4   # cm

var _aim_dots: Array[MeshInstance3D] = []
var _dot_materials: Array[StandardMaterial3D] = []


func _ready() -> void:
	_create_aim_dots()
	GameManager.state_changed.connect(_on_state_changed)


func _create_aim_dots() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = AIM_DOT_RADIUS
	sphere.height = AIM_DOT_RADIUS * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4

	for i in range(AIM_DOT_COUNT):
		var dot := MeshInstance3D.new()
		dot.mesh = sphere

		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1, 1, 1, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		dot.material_override = mat
		dot.visible = false
		add_child(dot)

		_aim_dots.append(dot)
		_dot_materials.append(mat)


func _on_state_changed(new_state: int) -> void:
	var show := new_state == GameManager.State.AIM or new_state == GameManager.State.POWER
	for dot in _aim_dots:
		dot.visible = show


func _unhandled_input(event: InputEvent) -> void:
	if not GameManager.game_active:
		return

	match GameManager.current_state:
		GameManager.State.PLACE_STRIKER:
			_handle_placement(event)
		GameManager.State.AIM:
			_handle_aim(event)
		GameManager.State.POWER:
			_handle_power(event)


# --- Raycast helper ---

func _mouse_to_board(mouse_pos: Vector2) -> Vector3:
	## Raycast from camera through mouse position onto the board plane (Y=0).
	## Returns the world-space hit point, or Vector3.INF if ray is parallel to board.
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return Vector3.INF
	var origin := camera.project_ray_origin(mouse_pos)
	var normal := camera.project_ray_normal(mouse_pos)
	if absf(normal.y) < 0.001:
		return Vector3.INF  # ray parallel to board
	var t := -origin.y / normal.y
	return origin + normal * t


# --- Placement ---

func _handle_placement(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _mouse_to_board(event.position)
		if hit != Vector3.INF:
			GameManager.place_striker_at(hit.x)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameManager.confirm_placement()


# --- Aiming ---

func _handle_aim(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hit := _mouse_to_board(event.position)
		if hit == Vector3.INF:
			return

		var dir := hit - global_position
		dir.y = 0.0

		# Zero-direction guard — mouse on striker
		if dir.length() < 0.1:
			return

		dir = dir.normalized()

		# Forward-hemisphere guard — can't aim backward toward own wall
		var forward := Vector3(0, 0, -1) if GameManager.current_player == 1 else Vector3(0, 0, 1)
		if dir.dot(forward) < -0.2:
			return

		GameManager.set_aim_direction(dir)
		_update_aim_dots(dir)

	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			GameManager.confirm_aim()


func _update_aim_dots(dir: Vector3) -> void:
	for i in range(AIM_DOT_COUNT):
		var dist := (i + 1) * AIM_DOT_SPACING
		_aim_dots[i].position = dir * dist + Vector3(0, 1.0, 0)
		# Fade opacity from 0.8 (near) to 0.1 (far)
		var alpha := lerpf(0.8, 0.1, float(i) / float(AIM_DOT_COUNT - 1))
		_dot_materials[i].albedo_color = Color(1, 1, 1, alpha)


# --- Power ---

func _handle_power(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			GameManager.is_charging = true
			AudioManager.play_power_bar()
		else:
			if GameManager.is_charging:
				GameManager.release_power()
	elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		GameManager.is_charging = false
		GameManager.power = 0.0
		AudioManager.stop_power_bar()
		GameManager._set_state(GameManager.State.AIM)
