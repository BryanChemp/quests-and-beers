extends Node3D

@export var sensitivity := 0.002

var pitch := 0.0


func _ready():
	if multiplayer.multiplayer_peer == null:
		return
	
	if !is_multiplayer_authority():
		set_process(false)
		set_process_unhandled_input(false)
		return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event):

	if event is InputEventMouseMotion:

		# Horizontal
		get_parent().rotate_y(-event.relative.x * sensitivity)

		# Vertical
		pitch -= event.relative.y * sensitivity

		pitch = clamp(
			pitch,
			deg_to_rad(-85),
			deg_to_rad(85)
		)

		rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):

		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
