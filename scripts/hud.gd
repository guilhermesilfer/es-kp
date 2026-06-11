extends CanvasLayer

signal time_expired # Avisa o jogo que o tempo acabou

@onready var time_bar: TextureProgressBar = $Control/TimerBar

@export var level_time: float = 60.0 # Tempo em segundos para a fase
var current_time: float

func _ready() -> void:
	current_time = level_time
	time_bar.max_value = level_time
	time_bar.value = level_time

func _process(delta: float) -> void:
	if current_time > 0:
		current_time -= delta
		time_bar.value = current_time
		
		if current_time <= 0:
			emit_signal("time_expired")
