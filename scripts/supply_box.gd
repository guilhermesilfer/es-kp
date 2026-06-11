extends Area2D

# Lista de itens possíveis baseada no seu GDD
var possible_items: Array[String] = ["Pistola Silenciada", "Flashbang", "Chave Amarela", "Chave Verde", "Chave Azul", "Chave de Fenda"]
var contained_item: String
var player_inside: CharacterBody2D = null

func _ready() -> void:
	# Escolhe um item aleatório da lista quando a caixa nasce no mapa
	contained_item = possible_items[randi() % possible_items.size()]
	
	# Conecta os sinais da própria Area2D para saber quando o player entra/sai de perto
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	# Se o jogador estiver perto e apertar a tecla "F" (Interagir)
	if player_inside != null and Input.is_action_just_pressed("ui_accept"): 
		# Nota: "ui_accept" por padrão na Godot é o Espaço/Enter. 
		# Se você já configurou a tecla "F" no Input Map, mude para o nome da sua ação (ex: "interact")
		
		# Tenta colocar o item no inventário do jogador
		var collected = player_inside.add_item(contained_item)
		
		if collected:
			print("Você abriu o baú e pegou: ", contained_item)
			queue_free() # Some com a caixa do cenário (já foi coletada)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		player_inside = body
		print("Pressione F para abrir a caixa de suprimentos")

func _on_body_exited(body: Node2D) -> void:
	if body == player_inside:
		player_inside = null
