extends Control

func _on_play_button_pressed() -> void:
	# Change this path to your actual gameplay scene
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_options_button_pressed() -> void:
	# For now, just a placeholder. You can open an options panel here later.
	print("Opening Options Menu...")

func _on_quit_button_pressed() -> void:
	# Closes the game cleanly
	get_tree().quit()
