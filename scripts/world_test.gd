extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var timer_bar: TextureProgressBar = %TimerBar

# --- NOVAS REFERÊNCIAS DO HUD ---
@onready var alert_label: Label = $Hud/Control/AlertTimer
@onready var inventory_slots: Array = [
	$Hud/Control/InventoryUI/Slot1,
	$Hud/Control/InventoryUI/Slot2,
	$Hud/Control/InventoryUI/Slot3
]

# Variáveis do Timer Principal (Fase)
@export var level_time: float = 60.0
var current_time: float

# Variáveis do Sistema de Alerta (Inimigos)
enum GuardState { STEALTH, ALERT, SEARCH }
var current_guard_state = GuardState.STEALTH
var alert_time_left: float = 0.0

func _ready() -> void:
	current_time = level_time
	if timer_bar:
		timer_bar.max_value = level_time
		timer_bar.value = level_time
	
	# Garante que o timer de alerta comece escondido
	alert_label.visible = false

func _process(delta: float) -> void:
	# 1. Gerencia o Timer Principal da Fase
	if current_time > 0:
		current_time -= delta
		if timer_bar:
			timer_bar.value = current_time
		if current_time <= 0:
			game_over()
			
	# 2. Gerencia o Cronômetro de Alerta/Procura dos Guardas
	_process_alert_timer(delta)
	
	# 3. Atualiza o Inventário Visual baseado no script do Player
	_update_inventory_ui()
	# TESTE TEMPORÁRIO (Apague depois!)
	if Input.is_key_pressed(KEY_1):
		change_guard_state(GuardState.ALERT, 5.0) # Tecla 1 simula: Guarda te viu (Vermelho)
	if Input.is_key_pressed(KEY_2):
		change_guard_state(GuardState.SEARCH)    # Tecla 2 simula: Sumir imediatamente
	if Input.is_key_pressed(KEY_3):
		change_guard_state(GuardState.STEALTH)    # Tecla 2 simula: Sumir imediatamente

# --- SISTEMA DE ALERTA (CORES E TEMPO) ---
func change_guard_state(new_state, duration: float = 5.0) -> void:
	current_guard_state = new_state
	alert_time_left = duration
	
	match current_guard_state:
		GuardState.STEALTH:
			alert_label.visible = false
		GuardState.ALERT:
			alert_label.visible = true
			alert_label.add_theme_color_override("font_color", Color.RED) # Fica Vermelho
		GuardState.SEARCH:
			alert_label.visible = true
			alert_label.add_theme_color_override("font_color", Color.YELLOW) # Fica Amarelo

func _process_alert_timer(delta: float) -> void:
	if current_guard_state != GuardState.STEALTH:
		alert_time_left -= delta
		
		# Atualiza o texto com duas casas decimais
		alert_label.text = "%.2f" % max(alert_time_left, 0.0)
		
		if alert_time_left <= 0:
			if current_guard_state == GuardState.ALERT:
				# Se o tempo de Alerta (Vermelho) acabar, o guarda entra em Procura (Amarelo)
				change_guard_state(GuardState.SEARCH, 5.0) # Mais 5 segundos procurando
			elif current_guard_state == GuardState.SEARCH:
				# Se o tempo de Procura acabar, ele despista e some!
				change_guard_state(GuardState.STEALTH)

# --- SISTEMA DE INVENTÁRIO VISUAL ---
# Arraste o seu arquivo de imagem da spritesheet do FileSystem para cá:
@export var spritesheet_texture: Texture2D = preload("res://assets/inventory_spritesheet.png")

# Defina o tamanho exato de cada quadrado na sua spritesheet (ex: 16 ou 32)
@export var slot_size: int = 20 

# Dicionário mapeando o nome do item para a POSIÇÃO (coluna) dele na spritesheet (começando do 0)
var item_atlas_positions: Dictionary = {
	"Slot Vazio": 0,
	"Pistola Silenciada": 5,
	"Flashbang": 6,
	"Chave Amarela": 1,
	"Chave Verde": 3,
	"Chave Azul": 2,
	"Chave de Fenda": 4
}

func _update_inventory_ui() -> void:
	if not player: return
	
	for i in range(inventory_slots.size()):
		var slot: TextureRect = inventory_slots[i]
		
		# Determina qual item vai aparecer nesse slot
		var item_name: String = "Slot Vazio"
		if i < player.inventory.size():
			item_name = player.inventory[i]
		
		# Descobre qual coluna da spritesheet esse item usa
		var column = item_atlas_positions.get(item_name, 0) # Se não achar, usa o 0 (Vazio)
		
		# Cria o recorte dinâmico (AtlasTexture)
		var atlas_rect = AtlasTexture.new()
		atlas_rect.atlas = spritesheet_texture
		# Define o quadrado de corte: X depende da coluna, Y é 0 (assumindo que a spritesheet é uma linha só)
		atlas_rect.region = Rect2(column * slot_size, 0, slot_size, slot_size)
		
		# Aplica a textura recortada diretamente no TextureRect do Slot
		slot.texture = atlas_rect

func game_over() -> void:
	print("O tempo acabou! O jogador explodiu!")
	if player:
		player.set_physics_process(false)
	await get_tree().create_timer(2.0).timeout
	get_tree().reload_current_scene()
	
	
