extends Node3D

## Builds the carrom board, pieces, pockets, and walls procedurally.
## Attached to the root Board node in main.tscn.
## Scale: 1 unit = 1 cm. Board is 74x74 cm.

# --- Dimensions (cm) ---
const BOARD_SIZE := 74.0
const BOARD_HEIGHT := 0.4
const FRAME_WIDTH := 5.5
const FRAME_HEIGHT := 2.6
const POCKET_RADIUS := 2.8
const MEN_RADIUS := 1.8
const MEN_HEIGHT := 0.45
const STRIKER_RADIUS := 2.2

# --- Physics (grams, real carrom values) ---
const MEN_MASS := 5.0       # ~5g carrom piece
const STRIKER_MASS := 15.0   # ~15g striker (3:1 ratio)
const PIECE_LINEAR_DAMP := 0.5   # gentle surface friction (powdered board)
const PIECE_ANGULAR_DAMP := 2.0  # moderate spin resistance
const PIECE_BOUNCE := 0.8        # hard plastic = elastic collisions
const PIECE_FRICTION := 0.05     # powdered board = near-frictionless
const WALL_BOUNCE := 0.7         # rubber cushion on wood frame
const WALL_FRICTION := 0.1       # smooth lacquered wood

# Textures
var _tex_board_albedo: Texture2D
var _tex_board_roughness: Texture2D
var _tex_board_normal: Texture2D
var _tex_frame_top: Texture2D
var _tex_frame_bottom: Texture2D
var _tex_piece_white: Texture2D
var _tex_piece_black: Texture2D
var _tex_piece_queen: Texture2D
var _tex_piece_striker: Texture2D


func _ready() -> void:
	# Clear stale refs from previous scene load (autoload persists across reloads)
	GameManager.pieces.clear()
	GameManager.striker = null
	GameManager.queen = null

	_load_textures()
	_build_board_surface()
	_build_boundaries()
	_build_pockets()
	_spawn_pieces()
	_spawn_striker()
	GameManager.start_game()


func _load_texture_safe(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			return res
	var global_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	return null


func _load_textures() -> void:
	_tex_board_albedo = _load_texture_safe("res://assets/textures/carrom_board_albedo.png")
	_tex_board_roughness = _load_texture_safe("res://assets/textures/carrom_board_roughness.png")
	_tex_board_normal = _load_texture_safe("res://assets/textures/carrom_board_normal.png")
	_tex_frame_top = _load_texture_safe("res://assets/textures/frame_top.png")
	_tex_frame_bottom = _load_texture_safe("res://assets/textures/frame_bottom.png")
	_tex_piece_white = _load_texture_safe("res://assets/textures/piece_white.png")
	_tex_piece_black = _load_texture_safe("res://assets/textures/piece_black.png")
	_tex_piece_queen = _load_texture_safe("res://assets/textures/piece_queen.png")
	_tex_piece_striker = _load_texture_safe("res://assets/textures/piece_striker.png")


# --- Board Surface ---

func _build_board_surface() -> void:
	var body := StaticBody3D.new()
	body.name = "BoardSurface"

	# Visual playing surface: PlaneMesh has clean 1:1 UV mapping (0,0 to 1,1)
	var mesh_inst := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(BOARD_SIZE, BOARD_SIZE)
	mesh_inst.mesh = plane
	mesh_inst.position.y = 0.0  # flush playing surface
	mesh_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	if _tex_board_albedo:
		mat.albedo_texture = _tex_board_albedo
	else:
		mat.albedo_color = Color(0.92, 0.84, 0.72)

	if _tex_board_roughness:
		mat.roughness_texture = _tex_board_roughness
	mat.roughness = 0.32

	# Clean polished tournament board surface (no normal-map noise or shadow acne)
	mat.metallic_specular = 0.5
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mesh_inst.material_override = mat
	body.add_child(mesh_inst)

	# Underside board backing (strictly below y = 0.0 to prevent any Z-fighting)
	var underside := MeshInstance3D.new()
	var underside_box := BoxMesh.new()
	underside_box.size = Vector3(BOARD_SIZE, BOARD_HEIGHT, BOARD_SIZE)
	underside.mesh = underside_box
	underside.position.y = -BOARD_HEIGHT * 1.5  # top face at -0.4 cm, safely below playing surface
	var underside_mat := StandardMaterial3D.new()
	underside_mat.albedo_color = Color(0.12, 0.1, 0.08)
	underside.material_override = underside_mat
	underside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	body.add_child(underside)

	# Physics collision shape
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(BOARD_SIZE, BOARD_HEIGHT, BOARD_SIZE)
	col.shape = shape
	col.position.y = -BOARD_HEIGHT / 2.0
	body.add_child(col)

	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)


# --- Boundaries (4 walls forming clean, seamless lacquered black hardwood frame) ---

func _build_boundaries() -> void:
	var half := BOARD_SIZE / 2.0  # 37.0 cm
	var fw := FRAME_WIDTH          # 5.5 cm
	var fh := FRAME_HEIGHT         # 2.6 cm
	var frame_y := fh / 2.0 - BOARD_HEIGHT  # 1.1 cm

	# Total outer frame width = BOARD_SIZE + fw * 2 = 85.0 cm
	var outer_size := BOARD_SIZE + fw * 2.0
	var offset := half + fw / 2.0  # 39.75 cm

	# Frame material: deep black lacquered hardwood with satin clearcoat
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color(0.07, 0.07, 0.08)
	frame_mat.roughness = 0.26
	frame_mat.metallic = 0.05
	frame_mat.clearcoat_enabled = true
	frame_mat.clearcoat = 0.35
	frame_mat.clearcoat_roughness = 0.25

	# Wall definitions: [name, pos, size, logo_texture]
	# Top and Bottom span the full outer width (85 cm)
	# Left and Right span the inner board size (74 cm) between Top and Bottom
	var walls_data: Array = [
		["WallTop",    Vector3(0, frame_y, -offset), Vector3(outer_size, fh, fw), _tex_frame_top],
		["WallBottom", Vector3(0, frame_y,  offset), Vector3(outer_size, fh, fw), _tex_frame_bottom],
		["WallLeft",   Vector3(-offset, frame_y, 0), Vector3(fw, fh, BOARD_SIZE), null],
		["WallRight",  Vector3( offset, frame_y, 0), Vector3(fw, fh, BOARD_SIZE), null],
	]

	for w: Array in walls_data:
		var w_name: String = String(w[0])
		var w_pos: Vector3 = w[1] as Vector3
		var w_size: Vector3 = w[2] as Vector3
		var w_logo: Texture2D = w[3] as Texture2D

		var body := StaticBody3D.new()
		body.name = w_name
		body.position = w_pos

		var mesh_inst := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = w_size
		mesh_inst.mesh = box
		mesh_inst.material_override = frame_mat
		body.add_child(mesh_inst)

		# If this wall has a logo (NOMEX on top/bottom frame), add a crisp logo overlay mesh on the top face
		if w_logo != null:
			var logo_mesh := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(24.0, 4.2)
			logo_mesh.mesh = quad
			logo_mesh.rotation_degrees = Vector3(-90, 0, 0)
			logo_mesh.position = Vector3(0, fh / 2.0 + 0.015, 0)
			logo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

			var logo_mat := StandardMaterial3D.new()
			logo_mat.albedo_texture = w_logo
			logo_mat.roughness = 0.2
			logo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			logo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			logo_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
			logo_mesh.material_override = logo_mat
			body.add_child(logo_mesh)

		# Inner cushion rebound trim
		var cushion := MeshInstance3D.new()
		var cushion_box := BoxMesh.new()
		var cushion_mat := StandardMaterial3D.new()
		cushion_mat.albedo_color = Color(0.12, 0.12, 0.14)
		cushion_mat.roughness = 0.4
		cushion.material_override = cushion_mat

		if w_name == "WallTop" or w_name == "WallBottom":
			cushion_box.size = Vector3(outer_size, 0.3, 0.2)
			var cushion_z: float = (fw / 2.0 - 0.1) if w_name == "WallTop" else (-fw / 2.0 + 0.1)
			cushion.position = Vector3(0, -fh / 2.0 + 0.15, cushion_z)
		else:
			cushion_box.size = Vector3(0.2, 0.3, BOARD_SIZE)
			var cushion_x: float = (fw / 2.0 - 0.1) if w_name == "WallLeft" else (-fw / 2.0 + 0.1)
			cushion.position = Vector3(cushion_x, -fh / 2.0 + 0.15, 0)

		cushion.mesh = cushion_box
		body.add_child(cushion)

		# Collision shape matches the wall exactly
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = w_size
		col.shape = shape
		body.add_child(col)

		body.collision_layer = 1
		body.collision_mask = 0

		var phys_mat := PhysicsMaterial.new()
		phys_mat.bounce = WALL_BOUNCE
		phys_mat.friction = WALL_FRICTION
		body.physics_material_override = phys_mat

		add_child(body)


# --- Pockets (4 corners) ---

func _build_pockets() -> void:
	var half := BOARD_SIZE / 2.0
	var offset := half * 0.95
	var corners := [
		Vector3(-offset, 0, -offset),
		Vector3( offset, 0, -offset),
		Vector3(-offset, 0,  offset),
		Vector3( offset, 0,  offset),
	]

	for i in range(4):
		var area := Area3D.new()
		area.name = "Pocket_%d" % i
		area.position = corners[i]

		var col := CollisionShape3D.new()
		var shape := SphereShape3D.new()
		shape.radius = POCKET_RADIUS
		col.shape = shape
		area.add_child(col)

		# Visual: recessed pocket ring
		var rim_mesh := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = POCKET_RADIUS * 0.95
		torus.outer_radius = POCKET_RADIUS * 1.05
		torus.rings = 24
		torus.ring_segments = 8
		rim_mesh.mesh = torus
		rim_mesh.position.y = 0.02
		var rim_mat := StandardMaterial3D.new()
		rim_mat.albedo_color = Color(0.1, 0.1, 0.12)
		rim_mat.roughness = 0.4
		rim_mesh.material_override = rim_mat
		area.add_child(rim_mesh)

		area.collision_layer = 8
		area.collision_mask = 6   # pieces (2) + striker (4)
		area.body_entered.connect(_on_pocket_body_entered)

		add_child(area)


func _on_pocket_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		GameManager.on_piece_pocketed(body)


# --- Piece Spawning ---

func _spawn_pieces() -> void:
	var r := MEN_RADIUS  # 1.8 cm
	var d := 2.0 * r + 0.08  # spacing with small realistic gap
	var d2 := 2.0 * r - 0.35
	var cos30 := cos(deg_to_rad(30.0))
	var sin30 := sin(deg_to_rad(30.0))

	# [position_x, position_z, color] — 0=BLACK, 1=WHITE, 2=RED (Queen)
	var layout: Array = [
		[0, 0, 2],                                          # Queen (center)
		[0, d, 0],                                          # BLACK
		[d * cos30, d * sin30, 1],                          # WHITE
		[-d * cos30, d * sin30, 1],                         # WHITE
		[0, -d, 1],                                         # WHITE
		[d * cos30, -d * sin30, 0],                         # BLACK
		[-d * cos30, -d * sin30, 0],                        # BLACK
		[2 * d2 * sin30, 2 * d2 * cos30, 0],               # BLACK
		[2 * d * cos30, 2 * d * sin30, 1],                  # WHITE
		[0, 2 * d, 1],                                      # WHITE
		[2 * d2, 0, 0],                                     # BLACK
		[-2 * d2 * sin30, 2 * d2 * cos30, 0],              # BLACK
		[-2 * d * cos30, 2 * d * sin30, 1],                 # WHITE
		[-2 * d2, 0, 0],                                    # BLACK
		[2 * d2 * sin30, -2 * d2 * cos30, 0],              # BLACK
		[2 * d * cos30, -2 * d * sin30, 1],                 # WHITE
		[-2 * d2 * sin30, -2 * d2 * cos30, 0],             # BLACK
		[-2 * d * cos30, -2 * d * sin30, 1],                # WHITE
		[0, -2 * d, 1],                                     # WHITE
	]

	var textures_map := {
		0: [_tex_piece_black, Color(0.12, 0.12, 0.13), GameManager.PieceColor.BLACK],
		1: [_tex_piece_white, Color(0.95, 0.92, 0.85), GameManager.PieceColor.WHITE],
		2: [_tex_piece_queen, Color(0.85, 0.1, 0.1), GameManager.PieceColor.RED],
	}

	for i in range(layout.size()):
		var data: Array = layout[i]
		var pos_x: float = float(data[0])
		var pos_z: float = float(data[1])
		var color_idx: int = int(data[2])

		var piece_info: Array = textures_map[color_idx]
		var piece := _create_piece(
			MEN_RADIUS,
			MEN_HEIGHT,
			MEN_MASS,
			piece_info[0] as Texture2D,
			piece_info[1] as Color,
			piece_info[2] as GameManager.PieceColor
		)
		piece.name = "Piece_%d" % i
		piece.position = Vector3(pos_x, MEN_HEIGHT * 0.5, pos_z)
		add_child(piece)
		GameManager.pieces.append(piece)

		if color_idx == 2:
			GameManager.queen = piece

	print("[BOARD] Spawned %d pieces with authentic tournament materials" % GameManager.pieces.size())


func _spawn_striker() -> void:
	var striker := _create_piece(
		STRIKER_RADIUS,
		MEN_HEIGHT,
		STRIKER_MASS,
		_tex_piece_striker,
		Color(0.08, 0.15, 0.35),
		GameManager.PieceColor.BLACK
	)
	striker.name = "Striker"
	striker.position = Vector3(0, MEN_HEIGHT * 0.5, 29.0)
	striker.freeze = true

	var striker_script: Resource = load("res://scenes/game/striker.gd")
	if striker_script:
		striker.set_script(striker_script)

	striker.collision_layer = 4  # striker layer
	striker.collision_mask = 3   # board (1) + pieces (2)
	striker.continuous_cd = true

	add_child(striker)
	GameManager.striker = striker
	print("[BOARD] Striker spawned successfully")


func _create_piece(radius: float, height: float, mass_val: float, tex: Texture2D, fallback_color: Color, piece_color: GameManager.PieceColor) -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = mass_val
	body.gravity_scale = 0.0
	body.linear_damp = PIECE_LINEAR_DAMP
	body.angular_damp = PIECE_ANGULAR_DAMP
	body.can_sleep = false
	body.continuous_cd = true

	body.axis_lock_linear_y = true
	body.axis_lock_angular_x = true
	body.axis_lock_angular_z = true

	# 3D Cylinder Body
	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 48
	mesh_inst.mesh = cyl

	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = fallback_color
	if radius > MEN_RADIUS:
		base_mat.roughness = 0.15
		base_mat.metallic_specular = 0.6
		base_mat.clearcoat_enabled = true
		base_mat.clearcoat = 0.4
	else:
		base_mat.roughness = 0.28
		base_mat.metallic_specular = 0.45

	mesh_inst.material_override = base_mat
	body.add_child(mesh_inst)

	# Decorative face on top of piece with concentric carved grooves
	if tex:
		var top_face := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(radius * 2.0, radius * 2.0)
		top_face.mesh = quad
		top_face.rotation_degrees = Vector3(-90, 0, 0)
		top_face.position.y = height / 2.0 + 0.015  # 0.15 mm elevation to completely avoid depth fighting
		top_face.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var top_mat := StandardMaterial3D.new()
		top_mat.albedo_texture = tex
		top_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		top_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		top_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		if radius > MEN_RADIUS:
			top_mat.roughness = 0.18
			top_mat.metallic_specular = 0.6
			top_mat.clearcoat_enabled = true
			top_mat.clearcoat = 0.4
		else:
			top_mat.roughness = 0.28
			top_mat.metallic_specular = 0.45

		top_face.material_override = top_mat
		body.add_child(top_face)

	# Collision shape — sphere for reliable contact physics in Godot
	var col := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = radius
	col.shape = shape
	body.add_child(col)

	# Physics material
	var phys_mat := PhysicsMaterial.new()
	phys_mat.bounce = PIECE_BOUNCE
	phys_mat.friction = PIECE_FRICTION
	body.physics_material_override = phys_mat

	body.collision_layer = 2
	body.collision_mask = 7   # board (1) + pieces (2) + striker (4)

	body.set_meta("color", piece_color)

	body.contact_monitor = true
	body.max_contacts_reported = 4
	body.body_entered.connect(_on_piece_collision.bind(body))

	return body


func _on_piece_collision(other: Node, piece: RigidBody3D) -> void:
	var vel := piece.linear_velocity.length()
	if vel < 5.0:  # skip inaudible collisions (cm/s)
		return

	if other is StaticBody3D:
		if piece == GameManager.striker:
			AudioManager.play_collision_sound(AudioManager.SFX.STRIKER_WALL, vel)
		else:
			AudioManager.play_collision_sound(AudioManager.SFX.PIECE_WALL, vel)
	elif other is RigidBody3D:
		if piece.get_instance_id() < other.get_instance_id():
			AudioManager.play_collision_sound(AudioManager.SFX.PIECE_COLLISION, vel)
