class_name FootPlacement
extends Node
## FootPlacement
##
## Responsabilidade única: manter LeftFootHome / RightFootHome grudados no chão,
## num ponto que já leva em conta a velocidade do jogador (previsão de passo).
## Não mexe nos FootTarget (isso é trabalho do ProceduralLocomotion).
##
## Este script assume que LeftFootRay / RightFootRay (RayCast3D) já existem em
## VisualRoot/ProceduralRig/GroundDetectors, como já está na sua cena.
##
## prediction_time e max_speed_for_prediction vêm do preset ativo (ver
## locomotion_presets.gd e o campo State abaixo). ray_start_height e
## ray_length ficam FORA do preset — são sobre o tamanho físico do rig
## (altura do quadril, alcance do raycast pro chão), não sobre o tipo de
## passo, então não fazem sentido mudar entre walk/run/strafe.
##
## No ar (is_on_floor() == false) este script não atualiza os Homes: eles
## ficam congelados na última posição no chão. Ver nota equivalente em
## procedural_locomotion.gd.

@export_node_path("CharacterBody3D") var player
@export_node_path("Marker3D") var left_foot_home
@export_node_path("Marker3D") var right_foot_home

## Preset ativo. Trocar isso aqui já reaplica prediction_time e
## max_speed_for_prediction com os valores do preset escolhido.
@export var state: LocomotionPresets.State = LocomotionPresets.State.WALK:
	set(value):
		state = value
		_apply_preset()

## Quanto tempo (em segundos) de velocidade "olhar à frente" ao prever o
## passo. Preenchido pelo preset.
@export var prediction_time: float = 0.15
## Velocidade acima da qual a previsão para de crescer. Preenchido pelo preset.
@export var max_speed_for_prediction: float = 6.0

## Fixos: dependem do tamanho do personagem (1.7m), não do tipo de passo.
@export var ray_start_height: float = 0.6
@export var ray_length: float = 1.2

var _player: CharacterBody3D
var _left_home: Node3D
var _right_home: Node3D
var _left_ray: RayCast3D
var _right_ray: RayCast3D

# Posição de descanso de cada pé, em espaço local do Player (X e Z importam,
# Y é recalculado pelo raycast a cada frame). Capturada uma vez no _ready(),
# a partir de onde você deixou os Markers posicionados no editor.
var _left_rest_local: Vector3
var _right_rest_local: Vector3


func _ready() -> void:
	_player = get_node(player)
	_left_home = get_node(left_foot_home)
	_right_home = get_node(right_foot_home)
	_left_ray = _player.get_node("VisualRoot/ProceduralRig/GroundDetectors/LeftFootRay")
	_right_ray = _player.get_node("VisualRoot/ProceduralRig/GroundDetectors/RightFootRay")
	_left_ray.target_position = Vector3(0, -ray_length, 0)
	_right_ray.target_position = Vector3(0, -ray_length, 0)
	_left_ray.enabled = true
	_right_ray.enabled = true

	_left_rest_local = _player.to_local(_left_home.global_position)
	_right_rest_local = _player.to_local(_right_home.global_position)

	_apply_preset()


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if not _player.network_on_floor:
		# No ar: Homes ficam congelados na última posição no chão. Ver
		# nota no topo do arquivo.
		return

	_place_home(_left_home, _left_rest_local, _left_ray)
	_place_home(_right_home, _right_rest_local, _right_ray)


func _apply_preset() -> void:
	var p: Dictionary = LocomotionPresets.get_preset(state)
	prediction_time = p["prediction_time"]
	max_speed_for_prediction = p["max_speed_for_prediction"]


func _place_home(home: Node3D, rest_local: Vector3, ray: RayCast3D) -> void:
	var horizontal_velocity := Vector2(
		_player.network_velocity.x,
		_player.network_velocity.z
	)
	var speed := minf(horizontal_velocity.length(), max_speed_for_prediction)
	var move_dir := Vector3.ZERO
	if horizontal_velocity.length() > 0.01:
		move_dir = Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.y).normalized()
	var lead := speed * prediction_time
	# rest_local gira com o corpo (é "embaixo do quadril", faz sentido
	# acompanhar a rotação do player) — então essa parte passa por to_global.
	var rest_world := _player.to_global(rest_local)
	# move_dir já é espaço de mundo (vem de velocity.x/z). Soma DIRETO em
	# espaço de mundo, sem passar de novo por to_global, senão ele giraria
	# junto com o corpo e a previsão ficaria torta sempre que você rotacionar.
	var target_world := rest_world + Vector3(move_dir.x, 0.0, move_dir.z) * lead
	# Reposiciona o raycast em cima do ponto previsto e dispara.
	ray.global_position = Vector3(target_world.x, target_world.y + ray_start_height, target_world.z)
	ray.force_raycast_update()
	if ray.is_colliding():
		target_world.y = ray.get_collision_point().y
	else:
		# Sem chão detectado (beirada, buraco): mantém a última altura conhecida
		# em vez de deixar o pé cair no vazio.
		target_world.y = home.global_position.y
	home.global_position = target_world
