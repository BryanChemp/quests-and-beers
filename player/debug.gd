extends Node
## DebugActions
##
## Ações de debug locais (troca de câmera, etc). Cada ação só deve reagir
## no cliente que É a autoridade deste Player — senão, no multiplayer, você
## trocaria a câmera de TODO MUNDO ao apertar a tecla, não só a sua.

@export_node_path("CharacterBody3D") var player
@export_node_path("Camera3D") var first_person_camera
@export_node_path("Camera3D") var third_person_camera

var _player: CharacterBody3D
var _first_person_camera: Camera3D
var _third_person_camera: Camera3D

var _using_first_person := false


func _ready() -> void:
	_player = get_node(player)
	_first_person_camera = get_node(first_person_camera)
	_third_person_camera = get_node(third_person_camera)

	# Se esse Player não é seu (não é a autoridade), desliga o processamento
	# de input desse nó inteiro — assim nem precisa checar autoridade de
	# novo a cada tecla, ele simplesmente nunca recebe o evento.
	if not _player.is_multiplayer_authority():
		set_process_unhandled_input(false)
		return

	_apply_camera_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_change_camera"):
		_using_first_person = !_using_first_person
		_apply_camera_state()
		get_viewport().set_input_as_handled()


func _apply_camera_state() -> void:
	_first_person_camera.current = _using_first_person
	_third_person_camera.current = !_using_first_person
