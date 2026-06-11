extends CharacterBody2D

@onready var sprite: Sprite2D = $Sprite2D

@export var speed: float = 100.0
@export var dropped_item_scene: PackedScene = preload("res://scenes/dropped_item.tscn")

# --- CONFIGURAÇÃO DA SPRITESHEET ---
@export var player_spritesheet: Texture2D = preload("res://assets/protagonist_spritesheet.png")
# DICA: Certifique-se no Inspector se o tamanho correto de cada frame é 16, 24, 32, etc.
@export var slot_size: int = 16

var item_atlas_positions: Dictionary = {
	"Slot Vazio": 0,
	"Chave de Fenda": 1,
	"Chave Verde": 2,
	"Chave Amarela": 3,
	"Chave Azul": 4,
	"Pistola Silenciada": 5,
	"Flashbang": 6
}

var inventory: Array[String] = [] 
var max_items: int = 3

# --- CONTROLE DE SELEÇÃO DE ITEM ---
var active_slot_index: int = 0 # Guarda qual slot (0, 1 ou 2) está na mão do jogador

func _ready() -> void:
	update_player_visual()

func _physics_process(_delta: float) -> void:
	# Movimentação
	var direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO:
		velocity = direction * speed
	else:
		velocity = velocity.move_toward(Vector2.ZERO, speed)
	move_and_slide()
	
	# Mira e rotação
	_handle_aim_and_rotation()
	
	# ESCUTA OS COMANDOS DE TROCA DE ITEM
	_handle_item_switching()

func _handle_aim_and_rotation() -> void:
	var local_mouse_pos = to_local(get_global_mouse_position())
	
	if local_mouse_pos.x < 0:
		sprite.flip_h = true  
	else:
		sprite.flip_h = false 
		
	var angle = local_mouse_pos.angle()
	var max_angle_rad = deg_to_rad(10.0)
	rotation = 0.0
	
	if sprite.flip_h:
		var left_angle = angle - PI if angle > 0 else angle + PI
		sprite.rotation = clamp(left_angle, -max_angle_rad, max_angle_rad)
	else:
		sprite.rotation = clamp(angle, -max_angle_rad, max_angle_rad)

# --- SISTEMA DE TROCA DE ITENS (SCROLL E TECLADO) ---
func _handle_item_switching() -> void:
	var old_index = active_slot_index
	
	# 1. Troca pelas Teclas 1, 2 e 3
	if Input.is_key_pressed(KEY_1):
		active_slot_index = 0
	elif Input.is_key_pressed(KEY_2):
		active_slot_index = 1
	elif Input.is_key_pressed(KEY_3):
		active_slot_index = 2
		
	# 2. Troca pelo Scroll do Rato (Mouse Wheel)
	if Input.is_action_just_pressed("next_item"):
		active_slot_index = (active_slot_index + 1) % max_items # Avança e volta pro 0 se estourar 3
	elif Input.is_action_just_pressed("prev_item"):
		active_slot_index = (active_slot_index - 1 + max_items) % max_items # Recua de forma segura
		
	# Se o índice mudou, atualiza o visual do boneco imediatamente!
	if active_slot_index != old_index:
		update_player_visual()
		print("Slot ativo mudou para: ", active_slot_index)

# --- ATUALIZAÇÃO DO VISUAL BASEADO NO SLOT SELECIONADO ---
func update_player_visual() -> void:
	var current_item_name = "Slot Vazio"
	
	# Verifica se o slot selecionado realmente tem um item guardado nele
	if active_slot_index < inventory.size():
		current_item_name = inventory[active_slot_index]
		
	var column = item_atlas_positions.get(current_item_name, 0)
	
	var atlas_rect = AtlasTexture.new()
	atlas_rect.atlas = player_spritesheet
	
	# CORRIGIDO: O último parâmetro agora usa slot_size para ter altura real e não sumir!
	atlas_rect.region = Rect2(column * slot_size, 0, slot_size, slot_size)
	atlas_rect.filter_clip = true # Evita vazamento de pixels vizinhos
	
	sprite.texture = atlas_rect

# --- DROP ---
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_drop_active_item()

func _drop_active_item() -> void:
	if active_slot_index >= inventory.size():
		return
	var item = inventory[active_slot_index]
	inventory.remove_at(active_slot_index)
	active_slot_index = clamp(active_slot_index, 0, max(0, inventory.size() - 1))
	update_player_visual()
	var dropped = dropped_item_scene.instantiate()
	dropped.item_name = item
	get_parent().add_child(dropped)
	dropped.global_position = global_position
	print("Dropped: ", item)

# --- COLETA ---
func add_item(item_name: String) -> bool:
	if inventory.size() < max_items:
		inventory.append(item_name)
		print("Item coletado: ", item_name, " | Inventário: ", inventory)
		
		# Faz o slot ativo pular automaticamente para o item recém-coletado (conforto para o jogador)
		active_slot_index = inventory.size() - 1
		
		update_player_visual() 
		return true
	else:
		print("Inventário cheio!")
		return false
