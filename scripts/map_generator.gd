extends Node2D

@export var room_scene: PackedScene = preload("res://scenes/room.tscn")
@export var horizontal_corridor_scene: PackedScene = preload("res://scenes/horizontal_straight_corridor.tscn")
@export var vertical_corridor_scene: PackedScene = preload("res://scenes/vertical_straight_corridor.tscn")
@export var cross_corridor_scene: PackedScene = preload("res://scenes/cross_corridor.tscn")
@export var door_scene: PackedScene = preload("res://scenes/door.tscn")
@export var supply_box_scene: PackedScene = preload("res://scenes/supply_box.tscn")
@export var guard_scene: PackedScene = preload("res://scenes/guard.tscn")

@export var map_size: int = 30
@export var cell_size: Vector2 = Vector2(128, 128)

# Each stage gets rows_per_stage rows of territory (computed dynamically).
# Between every pair of adjacent stages there are TRANSITION_HEIGHT corridor cells.
# Total Y needed = TOTAL_STAGES * rows_per_stage + (TOTAL_STAGES-1) * TRANSITION_HEIGHT <= map_size
const TOTAL_STAGES: int = 6
const TRANSITION_HEIGHT: int = 3
@export var rooms_per_stage: int = 9

# Must match item_atlas_positions in player.gd and world_test.gd.
const STAGE_KEYS: Array[String] = ["Chave Verde", "Chave Amarela", "Chave Azul", "Chave de Fenda"]

const DIRECTIONS: Dictionary = {
	"North": Vector2(0, -1),
	"South": Vector2(0, 1),
	"East":  Vector2(1,  0),
	"West":  Vector2(-1, 0),
}
const OPENING_TILES: Dictionary = {
	"North": [Vector2i(-2,-4), Vector2i(-1,-4), Vector2i(0,-4), Vector2i(1,-4)],
	"South": [Vector2i(-2, 3), Vector2i(-1, 3), Vector2i(0, 3), Vector2i(1, 3)],
	"East":  [Vector2i(3,-2),  Vector2i(3,-1),  Vector2i(3, 0), Vector2i(3, 1)],
	"West":  [Vector2i(-4,-2), Vector2i(-4,-1), Vector2i(-4, 0),Vector2i(-4, 1)],
}

var grid_map: Dictionary  = {}
var grid_type: Dictionary = {}
var _stage_of: Dictionary = {}
# Southernmost cell of each inter-stage transition corridor (door goes here).
var _stage_transitions: Array[Vector2] = []
var _exit_room_coords: Vector2 = Vector2.ZERO

func _ready() -> void:
	randomize()
	_generate()

func _generate() -> void:
	grid_map.clear()
	grid_type.clear()
	_stage_of.clear()
	_stage_transitions.clear()

	var result = _build_layered_layout()
	var start: Vector2 = result[0]

	_spawn_pieces()
	_seal_boundary_openings()
	_spawn_stage_doors()
	_spawn_exit_trigger()
	_spawn_exploration_supply_boxes()
	_spawn_guards(start)
	_place_player(start)

	print("Map OK | Start: %s | Exit: %s" % [start, _exit_room_coords])

# ── Layout planner ────────────────────────────────────────────────────────────

func _build_layered_layout() -> Array[Vector2]:
	# rows_per_stage: how many Y rows each stage's room territory occupies.
	# Derived so all stages + all transition corridors fit inside map_size.
	var rows_per_stage: int = max(2, int(floor(
		float(map_size - (TOTAL_STAGES - 1) * TRANSITION_HEIGHT) / float(TOTAL_STAGES)
	)))

	var global_start_pos := Vector2.ZERO
	# X column that the top transition cell of the previous stage sits at.
	# The next stage starts directly below it.
	var last_transition_top := Vector2.ZERO

	for stage in range(1, TOTAL_STAGES + 1):
		# Stage Y territory (strict – random walk must stay here).
		# Stage 1 is at the bottom (highest Y values); stage N at the top.
		# Each stage's slot = rows_per_stage room rows + TRANSITION_HEIGHT corridor rows above it.
		var stage_bottom_y: int = (map_size - 1) - (stage - 1) * (rows_per_stage + TRANSITION_HEIGHT)
		var stage_top_y: int    = stage_bottom_y - (rows_per_stage - 1)

		# Entry X: align with the column that came out of the previous transition.
		var start_x: int = randi() % map_size if stage == 1 else int(last_transition_top.x)
		var layer_start := Vector2(start_x, stage_bottom_y)

		if stage == 1:
			global_start_pos = layer_start

		# ── Random walk strictly within [stage_top_y, stage_bottom_y] ──────
		var current_pos := layer_start
		var stage_positions: Array[Vector2] = [current_pos]
		_stage_of[current_pos] = stage
		grid_map[current_pos]  = null

		var attempts := 0
		while stage_positions.size() < rooms_per_stage and attempts < 20000:
			attempts += 1
			var dirs := [Vector2(0,-1), Vector2(0,1), Vector2(-1,0), Vector2(1,0)]
			var nxt: Vector2 = current_pos + dirs[randi() % 4]
			if nxt.x >= 0 and nxt.x < map_size and nxt.y >= stage_top_y and nxt.y <= stage_bottom_y:
				if not stage_positions.has(nxt):
					stage_positions.append(nxt)
					_stage_of[nxt] = stage
					grid_map[nxt]  = null
				current_pos = nxt

		# ── Force a straight vertical path from the walker's last position
		#    up to stage_top_y so the exit is always at the stage's top row. ──
		var stage_exit := current_pos
		while int(stage_exit.y) > stage_top_y:
			var step: Vector2 = stage_exit + Vector2(0, -1)
			if not grid_map.has(step):
				grid_map[step]   = null
				_stage_of[step]  = stage
			stage_exit = step
		# stage_exit is now at (some_x, stage_top_y)

		if stage < TOTAL_STAGES:
			# ── Build the 3-cell transition corridor above stage_exit ──────
			# These cells are outside stage territory (in the gap between stages).
			# Cell order going north: T1 (southernmost), T2, T3 (northernmost).
			var prev := stage_exit
			for i in range(TRANSITION_HEIGHT):
				var tc: Vector2 = prev + Vector2(0, -1)
				grid_map[tc]  = null
				_stage_of[tc] = stage
				if i == 0:
					# Door goes on the southernmost transition cell (right above the stage).
					_stage_transitions.append(tc)
				prev = tc
			last_transition_top = prev
			# The next stage starts at (last_transition_top.x, last_transition_top.y - 1),
			# which equals that stage's computed stage_bottom_y – they connect naturally.
		else:
			_exit_room_coords = stage_exit

	return [global_start_pos, _exit_room_coords]

# ── Grid & pieces ─────────────────────────────────────────────────────────────

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
		var connections := _connections_at(coords)
		var scene := _pick_scene(connections)
		var piece := scene.instantiate()
		add_child(piece)
		piece.global_position = coords * cell_size
		grid_map[coords] = piece
		if   scene == room_scene:                  grid_type[coords] = "room"
		elif scene == horizontal_corridor_scene:   grid_type[coords] = "h_corridor"
		elif scene == vertical_corridor_scene:     grid_type[coords] = "v_corridor"
		else:                                      grid_type[coords] = "cross"

# ── Boundary sealing ──────────────────────────────────────────────────────────

func _seal_opening(coords: Vector2, dir_name: String) -> void:
	var piece = grid_map.get(coords)
	if piece == null: return
	var tm: TileMapLayer = piece.get_node_or_null("TileMapLayer")
	if tm == null: return
	if piece.get_node_or_null("MarkersEntranceExit/" + dir_name) == null: return
	for cell: Vector2i in OPENING_TILES[dir_name]:
		tm.set_cell(cell, 0, Vector2i(0, 0))

func _seal_boundary_openings() -> void:
	for coords in grid_map.keys():
		for d in DIRECTIONS:
			if not grid_map.has(coords + DIRECTIONS[d]):
				_seal_opening(coords, d)

# ── Stage doors + keys ────────────────────────────────────────────────────────

func _spawn_stage_doors() -> void:
	# Build a per-stage room list so we can place the key chest inside the stage.
	var rooms_by_stage: Dictionary = {}
	for coords in grid_map.keys():
		if grid_type.get(coords, "") != "room": continue
		var s: int = _stage_of.get(coords, 0)
		if not rooms_by_stage.has(s):
			rooms_by_stage[s] = []
		rooms_by_stage[s].append(coords)

	for coords in _stage_transitions:
		var stage: int = _stage_of.get(coords, 1)
		var key_name: String = STAGE_KEYS[(stage - 1) % STAGE_KEYS.size()]

		# Locked door at the southernmost transition corridor cell.
		var door := door_scene.instantiate()
		door.is_locked    = true
		door.required_key = key_name
		add_child(door)
		door.global_position = coords * cell_size

		# Key chest: a supply box with forced_item set before add_child so _ready() picks it up.
		var stage_rooms: Array = rooms_by_stage.get(stage, [])
		if stage_rooms.size() > 0:
			var key_room: Vector2 = stage_rooms[randi() % stage_rooms.size()]
			_spawn_supply_box(key_room, key_name)

# ── Supply boxes ──────────────────────────────────────────────────────────────

func _spawn_exploration_supply_boxes() -> void:
	for coords in grid_map.keys():
		if grid_type.get(coords, "") != "room": continue
		if _stage_of.get(coords, 0) == TOTAL_STAGES: continue
		if randf() < 0.5:
			_spawn_supply_box(coords, "")

func _spawn_supply_box(room_coords: Vector2, forced: String) -> void:
	var box := supply_box_scene.instantiate()
	if forced != "":
		box.forced_item = forced
	add_child(box)
	box.global_position = room_coords * cell_size

# ── Exit trigger (final room) ─────────────────────────────────────────────────

func _spawn_exit_trigger() -> void:
	var trigger := Area2D.new()
	var shape   := CollisionShape2D.new()
	var rect    := RectangleShape2D.new()
	rect.size = Vector2(cell_size.x * 0.8, cell_size.y * 0.8)
	shape.shape = rect
	trigger.add_child(shape)
	trigger.body_entered.connect(func(body: Node2D) -> void:
		if body.name == "Player":
			print("Você chegou ao final! Jogo encerrado.")
			get_tree().quit()
	)
	add_child(trigger)
	trigger.global_position = _exit_room_coords * cell_size

# ── Guards ────────────────────────────────────────────────────────────────────

func _spawn_guards(start_coords: Vector2) -> void:
	for coords in grid_map.keys():
		if coords == start_coords: continue
		if grid_type.get(coords, "") != "room": continue
		if randf() < 0.6:
			var guard := guard_scene.instantiate()
			add_child(guard)
			guard.global_position = coords * cell_size
			var room_stage: int = _stage_of.get(coords, 1)
			if guard.has_method("configure_difficulty"):
				guard.configure_difficulty(room_stage)

# ── Player ────────────────────────────────────────────────────────────────────

func _place_player(start_coords: Vector2) -> void:
	var player = get_node_or_null("../Player")
	if player: player.global_position = start_coords * cell_size
