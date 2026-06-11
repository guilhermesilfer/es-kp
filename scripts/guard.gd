extends CharacterBody2D

@export var speed: float = 45.0
@export var chase_speed: float = 70.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var vision_area: Area2D = $VisionArea

enum State { PATROL, CHASE }
var current_state: State = State.PATROL

var patrol_direction: Vector2 = Vector2.RIGHT
var target_player: CharacterBody2D = null
var change_dir_timer: float = 0.0

func _ready() -> void:
	# Conecta a visão do guarda para rastrear o Batman
	vision_area.body_entered.connect(_on_vision_area_body_entered)
	vision_area.body_exited.connect(_on_vision_area_body_exited)
	_choose_random_direction()

func _physics_process(delta: float) -> void:
	match current_state:
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase()

	# move_and_slide() retorna true se colidir com uma parede do Tilemap
	var collided = move_and_slide()
	if collided and current_state == State.PATROL:
		_choose_random_direction()

	_update_animation()

# --- PATRULHA CARDINAL (4 DIREÇÕES) ---
func _process_patrol(delta: float) -> void:
	velocity = patrol_direction * speed
	
	# Tempo para ele decidir mudar de direção sozinho (deixa o padrão mais orgânico)
	change_dir_timer -= delta
	if change_dir_timer <= 0:
		_choose_random_direction()

func _choose_random_direction() -> void:
	var directions = [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	patrol_direction = directions[randi() % directions.size()]
	change_dir_timer = randf_range(1.0, 3.0) # Anda entre 1 e 3 segundos antes de avaliar virar

# --- PERSEGUIÇÃO TOP-DOWN ---
func _process_chase() -> void:
	if is_instance_valid(target_player):
		# Rastreia a posição exata do Batman no plano 2D
		var dir = (target_player.global_position - global_position).normalized()
		velocity = dir * chase_speed
	else:
		current_state = State.PATROL

# --- CONTROLE DE ANIMAÇÃO TOP-DOWN ---
func _update_animation() -> void:
	if velocity.length() > 0:
		if abs(velocity.x) > abs(velocity.y):
			sprite.flip_h = (velocity.x < 0)

# --- SENSORES DE VISÃO DO GUARDA ---
func _on_vision_area_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		target_player = body
		current_state = State.CHASE
		print("Guarda detectou o Batman na sala!")

func _on_vision_area_body_exited(body: Node2D) -> void:
	if body == target_player:
		target_player = null
		current_state = State.PATROL
		print("Batman despistou o guarda.")
