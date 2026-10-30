extends Control


func _on_audio_toggled(toggled_on: bool) -> void:
	AudioServer.set_bus_mute(0, not toggled_on)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
