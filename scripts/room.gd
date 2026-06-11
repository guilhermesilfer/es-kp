extends Node2D

# Referências diretas para as posições das portas
@onready var north_marker: Marker2D = $MarkersEntranceExit/North
@onready var south_marker: Marker2D = $MarkersEntranceExit/South
@onready var east_marker: Marker2D = $MarkersEntranceExit/East
@onready var west_marker: Marker2D = $MarkersEntranceExit/West

# Dicionário prático para o gerador de mapas consultar as posições por string
# func get_door_global_position(direction: String) -> Vector2:
# 	match direction.lower():
# 		"north": return north_marker.global_position
# 		"south": return south_marker.global_position
# 		"east": return east_marker.global_position
# 		"west": return west_marker.global_position
# 	return global_position # Backup caso erre o nome
