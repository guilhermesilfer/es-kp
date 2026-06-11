extends Node2D

# Retorna a posição global de um marcador baseado na direção ("North", "South", etc)
func get_marker_global_position(direction: String) -> Vector2:
	var marker_node = get_node_or_null("MarkersEntranceExit/" + direction)
	if marker_node:
		return marker_node.global_position
	
	return Vector2.ZERO
