extends CharacterBody2D

@export var speed: float = 100.0 # Velocidade tática (baixa para furtividade)

# Sistema de Inventário (Limite de 3 itens conforme o GDD)
var inventory: Array[String] = [] 
var max_items: int = 3

func _physics_process(_delta: float) -> void:

	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)

	move_and_slide()
	
	# rotacionar o sprite do personagem em direção ao mouse
	look_at(get_global_mouse_position())

func add_item(item_name: String) -> bool:
	if inventory.size() < max_items:
		inventory.append(item_name)
		print("Item coletado: ", item_name, " | Inventário: ", inventory)
		return true
	else:
		print("Inventário cheio!")
		return false
