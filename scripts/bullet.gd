extends Area2D

@export var speed: float = 400.0

var direction: Vector2 = Vector2.ZERO

func _ready() -> void:
	# Conecta o sinal nativo de colisão da Area2D
	body_entered.connect(_on_body_entered)
	
	# Destrói a bala após 3 segundos se ela sumir do mapa, limpando a memória
	get_tree().create_timer(3.0).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	# Move a bala em linha reta
	global_position += direction * speed * delta

func _on_body_entered(body: Node2D) -> void:
	# Se acertar qualquer coisa com a função "take_damage" (o Guarda)
	if body.has_method("take_damage"):
		body.take_damage()
		queue_free() # Deleta o projétil
	# Se colidir com as paredes do cenário (TileMapLayer), a bala some
	elif body is TileMapLayer:
		queue_free()
