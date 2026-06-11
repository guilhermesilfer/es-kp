extends Node2D

func get_marker_global_position(direction: String) -> Variant:
	var marker_node = get_node_or_null("MarkersEntranceExit/" + direction)
	if marker_node:
		return marker_node.global_position
	return null
