extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var timer_bar: TextureProgressBar = $Hud/Control/TimerBar

@export var level_time: float = 60.0
var current_time: float

func _ready() -> void:
	current_time = level_time
	timer_bar.max_value = level_time
	timer_bar.value = level_time

func _process(delta: float) -> void:
	if current_time > 0:
		current_time -= delta
		timer_bar.value = current_time
		
		if current_time <= 0:
			game_over()

func game_over() -> void:
	print("O tempo acabou! O jogador explodiu!")
	
	player.set_physics_process(false)
	
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
