extends Node2D

var item_name: String = ""
var _player_nearby: CharacterBody2D = null

func _ready() -> void:
	$Label.text = item_name
	$PickupArea.body_entered.connect(_on_body_entered)
	$PickupArea.body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_nearby and Input.is_action_just_pressed("ui_accept"):
		if _player_nearby.add_item(item_name):
			queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_nearby = body

func _on_body_exited(body: Node2D) -> void:
	if body == _player_nearby:
		_player_nearby = null
