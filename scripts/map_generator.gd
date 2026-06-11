extends Node2D

@export var room_scene: PackedScene = preload("res://scenes/room.tscn")
@export var cross_corridor_scene: PackedScene = preload("res://scenes/cross_corridor.tscn")
@export var horizontal_corridor_scene: PackedScene = preload("res://scenes/horizontal_straight_corridor.tscn")
@export var vertical_corridor_scene: PackedScene = preload("res://scenes/vertical_straight_corridor.tscn")

# Carrega a cena da porta dupla
@export var door_scene: PackedScene = preload("res://scenes/door.tscn")

# Comprimento do caminho principal até o final
@export var depth: int = 30 

var current_piece: Node2D

# Lista que vai guardar todas as peças criadas no jogo
var all_map_pieces: Array[Node2D] = []
var cross_corridors_to_expand: Array[Node2D] = []

# Lista de chaves possíveis para trancar as portas bônus
var possible_keys: Array[String] = ["Chave Amarela", "Chave Verde", "Chave Azul"]

func _ready() -> void:
	randomize()
	generate_total_map()

func generate_total_map() -> void:
	print("--- PASSO 1: Gerando Caminho Crítico Seguro ---")
	
	current_piece = room_scene.instantiate()
	add_child(current_piece)
	current_piece.global_position = Vector2.ZERO
	all_map_pieces.append(current_piece)
	
	var next_direction = "East"
	
	for i in range(depth):
		var new_piece_scene: PackedScene
		if i % 2 == 0:
			if next_direction == "North" or next_direction == "South":
				new_piece_scene = vertical_corridor_scene if randf() > 0.4 else cross_corridor_scene
			else:
				new_piece_scene = horizontal_corridor_scene if randf() > 0.4 else cross_corridor_scene
		else:
			new_piece_scene = room_scene
			
		var new_piece = new_piece_scene.instantiate()
		add_child(new_piece)
		
		var entrance_direction = get_opposite_direction(next_direction)
		
		# Cria a conexão e coloca a porta livre do caminho principal
		connect_pieces_with_door(current_piece, next_direction, new_piece, entrance_direction, false)
		
		all_map_pieces.append(new_piece)
		
		if new_piece_scene == cross_corridor_scene:
			cross_corridors_to_expand.append(new_piece)
			
		current_piece = new_piece
		next_direction = choose_safe_direction(current_piece, entrance_direction)
		
	print("--- PASSO 2: Espetando Salas Adjacentes nas Laterais ---")
	_generate_adjacent_branches()
	
	print("--- PASSO 3: Identificando Sobras e Tapando Buracos com Portas Pretas ---")
	_tapa_buracos_do_vazio()

# --- PASSO 2: FILTRA BIFURCAÇÕES ---
func _generate_adjacent_branches() -> void:
	var directions = ["North", "South", "East", "West"]
	
	for cross in cross_corridors_to_expand:
		for dir in directions:
			if _is_marker_pointing_to_piece(cross, dir):
				continue
				
			if randf() > 0.5:
				var bonus_room = room_scene.instantiate()
				var entrance = get_opposite_direction(dir)
				
				_simulate_connection(cross, dir, bonus_room, entrance)
				
				if not _is_space_obstructed(bonus_room.global_position):
					add_child(bonus_room)
					all_map_pieces.append(bonus_room)
					
					var should_lock = randf() > 0.3
					connect_pieces_with_door(cross, dir, bonus_room, entrance, should_lock)
				else:
					bonus_room.queue_free()

# --- PASSO 3: VARREDURA DEFASADA ---
func _tapa_buracos_do_vazio() -> void:
	for piece in all_map_pieces:
		if not is_instance_valid(piece): continue
		
		var markers_node = piece.get_node_or_null("MarkersEntranceExit")
		if markers_node:
			for marker in markers_node.get_children():
				var marker_dir = marker.name
				
				if not _is_marker_pointing_to_piece(piece, marker_dir):
					if not _already_has_door_at(piece.get_marker_global_position(marker_dir)):
						_spawn_black_door_at(piece, marker_dir)

# --- SISTEMA DE SPAWN E ENCAIXE DE PORTAS ---

func _spawn_black_door_at(piece: Node2D, direction: String) -> void:
	var marker_pos = piece.get_marker_global_position(direction)
	var black_door = door_scene.instantiate()
	add_child(black_door)
	black_door.global_position = marker_pos
	
	if direction == "North" or direction == "South":
		black_door.global_transform = black_door.global_transform.rotated(deg_to_rad(90.0))
		
	black_door.is_locked = true
	black_door.required_key = "Preta"
	black_door.modulate = Color(0.1, 0.1, 0.1, 1.0)

func connect_pieces_with_door(piece_a: Node2D, exit_a: String, piece_b: Node2D, entrance_b: String, should_lock: bool) -> void:
	var exit_a_pos = piece_a.get_marker_global_position(exit_a)
	piece_b.global_position = Vector2.ZERO
	var entrance_b_pos = piece_b.get_marker_global_position(entrance_b)
	piece_b.global_position = exit_a_pos - entrance_b_pos
	
	var nova_porta = door_scene.instantiate()
	add_child(nova_porta)
	nova_porta.global_position = exit_a_pos
	
	if exit_a == "North" or exit_a == "South":
		nova_porta.global_transform = nova_porta.global_transform.rotated(deg_to_rad(90.0))
	
	if should_lock:
		nova_porta.is_locked = true
		var chave_sorteada = possible_keys[randi() % possible_keys.size()]
		nova_porta.required_key = chave_sorteada
		if chave_sorteada == "Chave Amarela": nova_porta.modulate = Color.YELLOW
		elif chave_sorteada == "Chave Verde": nova_porta.modulate = Color.GREEN
		elif chave_sorteada == "Chave Azul": nova_porta.modulate = Color.CYAN
	else:
		nova_porta.is_locked = false

# --- CHECAGENS E UTILITÁRIOS MATEMÁTICOS ---

func _is_space_obstructed(target_pos: Vector2) -> bool:
	var safety_radius = 70.0 
	for piece in all_map_pieces:
		if is_instance_valid(piece):
			if target_pos.distance_to(piece.global_position) < safety_radius:
				return true
	return false

func _is_marker_pointing_to_piece(current_piece_checking: Node2D, direction: String) -> bool:
	var marker_pos = current_piece_checking.get_marker_global_position(direction)
	for piece in all_map_pieces:
		if is_instance_valid(piece) and piece != current_piece_checking:
			if piece.global_position.distance_to(marker_pos) < 120.0:
				return true
	return false

func _already_has_door_at(target_pos: Vector2) -> bool:
	for child in get_children():
		if "Door" in child.name and child is StaticBody2D:
			if child.global_position.distance_to(target_pos) < 15.0:
				return true
	return false

func choose_safe_direction(piece: Node2D, entrance_used: String) -> String:
	var available_exits = []
	var markers_node = piece.get_node_or_null("MarkersEntranceExit")
	if markers_node:
		for marker in markers_node.get_children():
			if marker.name != entrance_used and marker.name != "West":
				available_exits.append(marker.name)
	if available_exits.size() > 0:
		return available_exits[randi() % available_exits.size()]
	return "East"

func _simulate_connection(piece_a: Node2D, exit_a: String, piece_b: Node2D, entrance_b: String) -> void:
	var exit_a_pos = piece_a.get_marker_global_position(exit_a)
	piece_b.global_position = Vector2.ZERO
	var entrance_b_pos = piece_b.get_marker_global_position(entrance_b)
	piece_b.global_position = exit_a_pos - entrance_b_pos

func get_opposite_direction(direction: String) -> String:
	match direction:
		"North": return "South"
		"South": return "North"
		"East": return "West"
		"West": return "East"
	return "West"
