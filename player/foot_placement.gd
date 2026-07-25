extends Node
## FootPlacement
##
## Responsabilidade única: manter LeftFootHome / RightFootHome grudados no chão,
## num ponto que já leva em conta a velocidade do jogador (previsão de passo).
## Não mexe nos FootTarget (isso é trabalho do ProceduralLocomotion).
##
## Este script assume que LeftFootRay / RightFootRay (RayCast3D) já existem em
## VisualRoot/ProceduralRig/GroundDetectors, como já está na sua cena.

@export_node_path("CharacterBody3D") var player
@export_node_path("Marker3D") var left_foot_home
@export_node_path("Marker3D") var right_foot_home

## Quanto tempo (em segundos) de velocidade "olhar à frente" ao prever o passo.
## Valores maiores = passos mais largos em corrida.
@export var prediction_time: float = 0.15

## Velocidade acima da qual a previsão para de crescer (evita passos gigantes).
@export var max_speed_for_prediction: float = 6.0

## Altura do raycast acima do "home" ideal, e o quanto ele desce.
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

	# Guarda a posição de descanso (X, Z) que você já configurou nos Markers,
	# relativa ao Player, para poder deslocá-la com a previsão de movimento.
	_left_rest_local = _player.to_local(_left_home.global_position)
	_right_rest_local = _player.to_local(_right_home.global_position)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_place_home(_left_home, _left_rest_local, _left_ray)
	_place_home(_right_home, _right_rest_local, _right_ray)


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
