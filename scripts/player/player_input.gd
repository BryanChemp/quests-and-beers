extends Node

class_name PlayerInput

var movement := Vector2.ZERO
var jump := false
var interact := false

func _process(_delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return

	if !is_multiplayer_authority():
		return

	movement = Input.get_vector(
		"move_left",
		"move_right",
		"move_forward",
		"move_back"
	)

	jump = Input.is_action_just_pressed("jump")
	interact = Input.is_action_just_pressed("interact")
