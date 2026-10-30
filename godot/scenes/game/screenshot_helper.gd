extends Node

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var vp := get_viewport()
	var tex := vp.get_texture()
	var img := tex.get_image()
	if img:
		img.save_png("res://screenshot_place_striker.png")
		print("[CAPTURE] Saved screenshot_place_striker.png")

	# Move camera to SIMULATION preset
	var cam: Camera3D = vp.get_camera_3d()
	if cam:
		cam.position = Vector3(0, 85, 25)
		cam.rotation_degrees = Vector3(-70, 0, 0)
	
	await get_tree().create_timer(0.5).timeout
	var img2 := vp.get_texture().get_image()
	if img2:
		img2.save_png("res://screenshot_simulation.png")
		print("[CAPTURE] Saved screenshot_simulation.png")

	get_tree().quit()
