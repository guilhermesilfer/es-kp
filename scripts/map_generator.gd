extends Node2D

@export var room_scene: PackedScene = preload("res://scenes/room.tscn")
@export var horizontal_corridor_scene: PackedScene = preload("res://scenes/horizontal_straight_corridor.tscn")
@export var vertical_corridor_scene: PackedScene = preload("res://scenes/vertical_straight_corridor.tscn")
@export var cross_corridor_scene: PackedScene = preload("res://scenes/cross_corridor.tscn")
@export var door_scene: PackedScene = preload("res://scenes/door.tscn")
@export var supply_box_scene: PackedScene = preload("res://scenes/supply_box.tscn")

# Cena do Guarda Top-Down
@export var guard_scene: PackedScene = preload("res://scenes/guard.tscn")

@export var map_size: int = 10
@export var total_pieces: int = 40
@export var cell_size: Vector2 = Vector2(128, 128)

const DIRECTIONS: Dictionary = {
	"North": Vector2(0, -1),
	"South": Vector2(0, 1),
	"East":  Vector2(1,  0),
	"West":  Vector2(-1, 0),
}
const OPPOSITE_DIR: Dictionary = {
	"North": "South", "South": "North", "East": "West", "West": "East"
}
# All 4 tiles of an opening — filling these closes the passage entirely.
const OPENING_TILES: Dictionary = {
	"North": [Vector2i(-2,-4), Vector2i(-1,-4), Vector2i(0,-4), Vector2i(1,-4)],
	"South": [Vector2i(-2, 3), Vector2i(-1, 3), Vector2i(0, 3), Vector2i(1, 3)],
	"East":  [Vector2i(3,-2),  Vector2i(3,-1),  Vector2i(3, 0), Vector2i(3, 1)],
	"West":  [Vector2i(-4,-2), Vector2i(-4,-1), Vector2i(-4, 0),Vector2i(-4, 1)],
}
# Only the two outer flanking tiles — filling these forces the player through the
# center 32 px door slot instead of walking around the door.
const DOOR_OUTER_TILES: Dictionary = {
	"North": [Vector2i(-2,-4), Vector2i(1,-4)],
	"South": [Vector2i(-2, 3), Vector2i(1, 3)],
	"East":  [Vector2i(3,-2),  Vector2i(3, 1)],
	"West":  [Vector2i(-4,-2), Vector2i(-4, 1)],
}
const KEY_COLORS: Array = [
	{"key": "Chave Amarela", "color": Color.YELLOW},
	{"key": "Chave Verde",   "color": Color.GREEN},
	{"key": "Chave Azul",    "color": Color.BLUE},
]

var grid_map: Dictionary  = {}
var grid_type: Dictionary = {}
var _stage_of: Dictionary = {}   # Vector2 → int  1‥4
var _key_rooms: Array[Vector2] = []

func _ready() -> void:
	randomize()
	_generate()

const MIN_MAIN_PATH: int = 8  # each of 4 stages gets ≥2 cells → guaranteed 3 doors

func _generate() -> void:
	# Plan layout first (no nodes spawned), retry until path is long enough.
	var start: Vector2
	var exit_coords: Vector2
	var main_path: Array[Vector2]
	var positions: Array[Vector2]
	var attempt := 0
	while true:
		attempt += 1
		grid_map.clear()
		grid_type.clear()
		_stage_of.clear()
		_key_rooms.clear()

		positions  = _random_walk()
		start      = positions[0]
		_register_grid(positions)          # fills grid_map keys only (values stay null)

		exit_coords = _find_exit(start)
		main_path   = _bfs_path(start, exit_coords)

		if main_path.size() >= MIN_MAIN_PATH:
			break
		if attempt >= 30:
			push_error("MapGenerator: no valid layout after 30 attempts")
			return

	# Layout is valid — now spawn all nodes.
	_spawn_pieces()
	_assign_stages(main_path)
	_seal_inter_stage_walls(main_path)   # must run before boundary seal
	_seal_boundary_openings()
	_place_stage_locks(main_path)
	_spawn_exploration_supply_boxes()
	
	# PASSO NOVO: Injeta os guardas nas salas do labirinto
	_spawn_guards(start)
	
	_place_player(start)

	print("Map OK | Start:%s  Exit:%s  Path:%d  Attempt:%d" % [start, exit_coords, main_path.size(), attempt])

# ── Random walk ───────────────────────────────────────────────────────────────

func _random_walk() -> Array[Vector2]:
	var center = Vector2(floor(map_size / 2.0), floor(map_size / 2.0))
	var positions: Array[Vector2] = [center]
	var current = center
	while positions.size() < total_pieces:
		var dirs = [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0)]
		var next = current + dirs[randi() % 4]
		if next.x >= 0 and next.x < map_size and next.y >= 0 and next.y < map_size:
			if not positions.has(next):
				positions.append(next)
			current = next
	return positions

# ── Grid & pieces ─────────────────────────────────────────────────────────────

func _register_grid(positions: Array[Vector2]) -> void:
	for coords in positions:
		grid_map[coords] = null

func _connections_at(coords: Vector2) -> Array[String]:
	var result: Array[String] = []
	for dir_name in DIRECTIONS:
		if grid_map.has(coords + DIRECTIONS[dir_name]):
			result.append(dir_name)
	return result

func _pick_scene(connections: Array[String]) -> PackedScene:
	var n = "North" in connections
	var s = "South" in connections
	var e = "East"  in connections
	var w = "West"  in connections
	if e and w and not n and not s: return horizontal_corridor_scene
	if n and s and not e and not w: return vertical_corridor_scene
	if n and s and e and w:         return cross_corridor_scene
	return room_scene

func _spawn_pieces() -> void:
	for coords in grid_map.keys():
		var connections = _connections_at(coords)
		var scene = _pick_scene(connections)
		var piece = scene.instantiate()
		add_child(piece)
		piece.global_position = coords * cell_size
		grid_map[coords] = piece
		if   scene == room_scene:                  grid_type[coords] = "room"
		elif scene == horizontal_corridor_scene:   grid_type[coords] = "h_corridor"
		elif scene == vertical_corridor_scene:     grid_type[coords] = "v_corridor"
		else:                                      grid_type[coords] = "cross"

# ── Pathfinding ───────────────────────────────────────────────────────────────

func _find_exit(start: Vector2) -> Vector2:
	var queue = [start]
	var dist: Dictionary = {start: 0}
	var farthest = start
	while queue.size() > 0:
		var current: Vector2 = queue.pop_front()
		for dir_name in DIRECTIONS:
			var nb = current + DIRECTIONS[dir_name]
			if grid_map.has(nb) and not dist.has(nb):
				dist[nb] = dist[current] + 1
				queue.append(nb)
				if dist[nb] > dist[farthest]:
					farthest = nb
	return farthest

func _bfs_path(start: Vector2, end: Vector2) -> Array[Vector2]:
	var queue: Array = [[start]]
	var visited: Dictionary = {start: true}
	while queue.size() > 0:
		var path: Array = queue.pop_front()
		var current: Vector2 = path[-1]
		if current == end:
			var typed: Array[Vector2] = []
			for p in path: typed.append(p)
			return typed
		for dir_name in DIRECTIONS:
			var nb = current + DIRECTIONS[dir_name]
			if grid_map.has(nb) and not visited.has(nb):
				visited[nb] = true
				var np = path.duplicate()
				np.append(nb)
				queue.append(np)
	return [start]

func _dir_from_to(from: Vector2, to: Vector2) -> String:
	var diff = to - from
	for d in DIRECTIONS:
		if DIRECTIONS[d] == diff: return d
	return ""

func _connection_key(a: Vector2, b: Vector2) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y): return str(a) + "|" + str(b)
	return str(b) + "|" + str(a)

# ── Stage assignment ──────────────────────────────────────────────────────────

# Main path is sliced into 4 equal segments → stages 1‥4.
# Off-path cells inherit the stage of their closest main-path neighbour (BFS).
func _assign_stages(main_path: Array[Vector2]) -> void:
	var n = main_path.size()
	var seg = float(n) / 4.0
	for i in range(n):
		_stage_of[main_path[i]] = min(4, int(float(i) / seg) + 1)
	_stage_of[main_path[-1]] = 4   # exit cell always stage 4

	var queue: Array = main_path.duplicate()
	var visited: Dictionary = {}
	for c in main_path: visited[c] = true
	while queue.size() > 0:
		var cur: Vector2 = queue.pop_front()
		for d in DIRECTIONS:
			var nb = cur + DIRECTIONS[d]
			if grid_map.has(nb) and not visited.has(nb):
				_stage_of[nb] = _stage_of[cur]
				visited[nb]   = true
				queue.append(nb)

# ── Sealing helpers ───────────────────────────────────────────────────────────

func _seal_opening(coords: Vector2, dir_name: String) -> void:
	var piece = grid_map.get(coords)
	if piece == null: return
	var tm: TileMapLayer = piece.get_node_or_null("TileMapLayer")
	if tm == null: return
	if piece.get_node_or_null("MarkersEntranceExit/" + dir_name) == null: return
	for cell: Vector2i in OPENING_TILES[dir_name]:
		tm.set_cell(cell, 0, Vector2i(0, 0))

# Seals every cross-stage connection that is NOT the designated lock passage.
# After this, the ONLY way between two adjacent stages is through one locked door.
func _seal_inter_stage_walls(main_path: Array[Vector2]) -> void:
	var locks: Dictionary = {}
	for i in range(main_path.size() - 1):
		if _stage_of.get(main_path[i], 0) != _stage_of.get(main_path[i + 1], 0):
			locks[_connection_key(main_path[i], main_path[i + 1])] = true

	for coords in grid_map.keys():
		for d in DIRECTIONS:
			var nb = coords + DIRECTIONS[d]
			if not grid_map.has(nb): continue
			if _stage_of.get(coords, 0) == _stage_of.get(nb, 0): continue
			if locks.has(_connection_key(coords, nb)): continue
			_seal_opening(coords, d)
			_seal_opening(nb, OPPOSITE_DIR[d])

func _seal_boundary_openings() -> void:
	for coords in grid_map.keys():
		for d in DIRECTIONS:
			if not grid_map.has(coords + DIRECTIONS[d]):
				_seal_opening(coords, d)

# ── Doors ─────────────────────────────────────────────────────────────────────

func _narrow_for_door(from_coords: Vector2, dir_name: String) -> void:
	for pair in [[from_coords, dir_name],
				 [from_coords + DIRECTIONS[dir_name], OPPOSITE_DIR[dir_name]]]:
		var piece = grid_map.get(pair[0])
		if piece == null: continue
		var tm: TileMapLayer = piece.get_node_or_null("TileMapLayer")
		if tm == null: continue
		for cell: Vector2i in DOOR_OUTER_TILES[pair[1]]:
			tm.set_cell(cell, 0, Vector2i(0, 0))

func _place_door(pos: Vector2, direction: String, key: String = "", color: Color = Color.WHITE) -> void:
	var door = door_scene.instantiate()
	add_child(door)
	door.global_position = pos
	if direction == "East" or direction == "West":
		door.global_transform = door.global_transform.rotated(deg_to_rad(90.0))
	door.is_locked    = not key.is_empty()
	door.required_key = key
	door.modulate      = color

# Places one locked door at each stage boundary, with exactly one key hidden
# somewhere inside that stage's rooms.
func _place_stage_locks(main_path: Array[Vector2]) -> void:
	var stage_debug := ""
	for c in main_path:
		stage_debug += str(_stage_of.get(c, 0))
	print("Stages on path (len=%d): %s" % [main_path.size(), stage_debug])

	var lock_idx = 0
	for i in range(main_path.size() - 1):
		if lock_idx >= KEY_COLORS.size(): break
		var from_c = main_path[i]
		var to_c   = main_path[i + 1]
		if _stage_of.get(from_c, 0) == _stage_of.get(to_c, 0): continue

		var dir_name = _dir_from_to(from_c, to_c)
		print("  Transition S%d→S%d at %s dir=%s (piece=%s)" % [
			_stage_of.get(from_c), _stage_of.get(to_c), from_c, dir_name,
			grid_type.get(from_c, "?")])
		if dir_name.is_empty(): continue  # non-adjacent cells, shouldn't happen

		var mpos = grid_map[from_c].get_marker_global_position(dir_name)
		if mpos == null:
			mpos = from_c * cell_size + DIRECTIONS[dir_name] * cell_size * 0.5
			print("    WARNING: marker missing, using fallback pos %s" % mpos)

		var cd = KEY_COLORS[lock_idx]
		_narrow_for_door(from_c, dir_name)
		_place_door(mpos, dir_name, cd["key"], cd["color"])
		print("  Door placed: %s at %s" % [cd["key"], mpos])

		# Exactly one key chest, somewhere inside the FROM stage.
		var from_stage = _stage_of.get(from_c, 1)
		var candidates: Array[Vector2] = []
		for c in grid_map.keys():
			if _stage_of.get(c, 0) == from_stage and grid_type.get(c, "") == "room":
				candidates.append(c)
		if candidates.is_empty(): candidates = [from_c]

		var key_room = candidates[randi() % candidates.size()]
		_key_rooms.append(key_room)
		_spawn_supply_box(key_room, cd["key"])
		lock_idx += 1

	print("Total doors placed: %d" % lock_idx)

# ── Supply boxes ──────────────────────────────────────────────────────────────

func _spawn_exploration_supply_boxes() -> void:
	for coords in grid_map.keys():
		if grid_type.get(coords, "") != "room": continue
		if coords in _key_rooms: continue
		if _stage_of.get(coords, 0) == 4: continue  # exit stage needs no loot
		if randf() < 0.5: _spawn_supply_box(coords)

func _spawn_supply_box(room_coords: Vector2, forced_item: String = "") -> void:
	var box = supply_box_scene.instantiate()
	if forced_item != "": box.forced_item = forced_item
	add_child(box)
	box.global_position = room_coords * cell_size

# ── Guard Spawning ────────────────────────────────────────────────────────────

func _spawn_guards(start_coords: Vector2) -> void:
	print("--- PASSO 4: Injetando Inimigos por Estágio ---")
	
	for coords in grid_map.keys():
		# Nunca coloca o guarda na cara do Batman na sala inicial
		if coords == start_coords: 
			continue
			
		# Apenas espeta guardas em salas reais (evita travar nos corredores estreitos)
		if grid_type.get(coords, "") != "room": 
			continue
			
		# 60% de chance de spawnar guarda por sala válida
		if randf() < 0.6:
			var guard = guard_scene.instantiate()
			add_child(guard)
			
			# Centraliza o guarda perfeitamente no espaço do quadrado
			guard.global_position = coords * cell_size
			
			# Passa o estágio da sala atual para o script do guarda (se ele aceitar)
			var room_stage = _stage_of.get(coords, 1)
			if guard.has_method("configure_difficulty"):
				guard.configure_difficulty(room_stage)
				
			print("  Guarda criado na sala %s (Estágio %d)" % [coords, room_stage])

# ── Player ────────────────────────────────────────────────────────────────────

func _place_player(start_coords: Vector2) -> void:
	var player = get_node_or_null("../Player")
	if player: player.global_position = start_coords * cell_size
