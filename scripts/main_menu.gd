extends Control

@onready var main_menu_buttons = $MainMenuButtons
@onready var options_menu = $OptionsMenu
@onready var volume_slider = $OptionsMenu/HSlider

func _ready() -> void:
	main_menu_buttons.visible = true
	options_menu.visible = false
	
	var master_bus_index = AudioServer.get_bus_index("Master")
	var volume_db = AudioServer.get_bus_volume_db(master_bus_index)
	volume_slider.value = db_to_linear(volume_db) # Converts Godot decibels back to a 0.0 - 1.0 slider range

# --- MENU NAVIGATION ---

func _on_options_button_pressed() -> void:
	main_menu_buttons.visible = false
	options_menu.visible = true

func _on_close_button_pressed() -> void:
	options_menu.visible = false
	main_menu_buttons.visible = true

func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world_test.tscn")

func _on_quit_button_pressed() -> void:
	get_tree().quit()

# --- SETTINGS ---

func _on_check_box_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_h_slider_value_changed(value: float) -> void:
	var master_bus_index = AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(value))
