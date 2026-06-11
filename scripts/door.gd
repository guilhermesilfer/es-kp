extends StaticBody2D

# Referências diretas aos dois sprites que você criou
@onready var left_door: Sprite2D = $Node2D/LeftDoor
@onready var right_door: Sprite2D = $Node2D/RightDoor
@onready var physics_collision: CollisionShape2D = $CollisionShape2D

@export var is_locked: bool = false
@export var required_key: String = "Chave Amarela"

var is_open: bool = false
var player_in_range: CharacterBody2D = null

func _ready() -> void:
	# Conecta a área de detecção
	$InteractionArea.body_entered.connect(_on_player_entered)
	$InteractionArea.body_exited.connect(_on_player_exited)
	physics_collision.disabled = false

func _process(_delta: float) -> void:
	if player_in_range and not is_open:
		if Input.is_key_pressed(KEY_E):
			try_open_door()

func try_open_door() -> void:
	if is_locked:
		# Se a chave exigida for "Preta", ela nunca abre (bloqueio de borda do mapa)
		if required_key == "Preta":
			print("Esta porta está permanentemente trancada. Limite do mapa.")
			return
			
		if player_in_range.inventory.has(required_key):
			player_in_range.inventory.erase(required_key)
			player_in_range.update_player_visual()
			print("Porta destrancada! Chave consumida.")
			open()
		else:
			print("Trancada! Traga a: ", required_key)
	else:
		open()

func open() -> void:
	is_open = true
	physics_collision.disabled = true # Libera a passagem física para o Batman
	
	# Efeito visual temporário: some com as duas folhas para simular a abertura
	left_door.visible = false
	right_door.visible = false
	print("Portas duplas abertas!")

func _on_player_entered(body: Node2D) -> void:
	if body.name == "Player":
		player_in_range = body

func _on_player_exited(body: Node2D) -> void:
	if body == player_in_range:
		player_in_range = null
