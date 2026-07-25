extends Node
## ProceduralLocomotion
##
## Responsabilidade única: decidir QUANDO cada pé dá um passo e ANIMAR esse
## passo (FootTarget indo do ponto atual até o FootHome mais recente, com um
## arco de elevação no meio). Os TwoBoneIK3D já configurados na cena cuidam
## de dobrar a perna até o FootTarget — este script só move o Marker3D alvo.
##
## Funciona pra qualquer direção de movimento porque o "home" já vem
## deslocado pelo FootPlacement.gd na direção da velocidade. Não existem
## 8 animações distintas: existe um único ciclo de passo que reage à
## velocidade em qualquer ângulo.

@export_node_path("Marker3D") var left_foot_home
@export_node_path("Marker3D") var right_foot_home
@export_node_path("Marker3D") var left_foot_target
@export_node_path("Marker3D") var right_foot_target

## Duração de um passo, em segundos.
@export var step_duration: float = 0.28

## Altura do arco do pé no meio do passo.
@export var step_height: float = 0.16

## Distância entre o target atual e o home que dispara um novo passo.
## Baixo demais = passinhos nervosos. Alto demais = pés arrastando.
@export var step_trigger_distance: float = 0.28

## Curva de suavização do movimento horizontal do pé (0 = linear).
@export var ease_strength: float = -1.6

var _left_home: Node3D
var _right_home: Node3D
var _left_target: Node3D
var _right_target: Node3D


class FootStep:
	var stepping: bool = false
	var t: float = 0.0
	var start_pos: Vector3 = Vector3.ZERO
	var end_pos: Vector3 = Vector3.ZERO


var _left := FootStep.new()
var _right := FootStep.new()


func _ready() -> void:
	_left_home = get_node(left_foot_home)
	_right_home = get_node(right_foot_home)
	_left_target = get_node(left_foot_target)
	_right_target = get_node(right_foot_target)

	# Começa os targets já em cima do home, senão o primeiro frame faz o pé
	# "teleportar" de (0,0,0) até a posição real.
	_left_target.global_position = _left_home.global_position
	_right_target.global_position = _right_home.global_position


func _physics_process(delta: float) -> void:
	# Alternância de marcha: um pé só começa a passada se o outro não
	# estiver no meio de uma. Isso evita os dois pés no ar ao mesmo tempo.
	_update_foot(_left, _left_home, _left_target, delta, _right.stepping)
	_update_foot(_right, _right_home, _right_target, delta, _left.stepping)


func _update_foot(foot: FootStep, home: Node3D, target: Node3D, delta: float, other_is_stepping: bool) -> void:
	if foot.stepping:
		foot.t += delta / step_duration
		var f: float = clampf(foot.t, 0.0, 1.0)
		var eased_f: float = ease(f, ease_strength)

		var pos: Vector3 = foot.start_pos.lerp(foot.end_pos, eased_f)
		pos.y += sin(f * PI) * step_height
		target.global_position = pos

		if f >= 1.0:
			foot.stepping = false
			target.global_position = foot.end_pos
	else:
		var drift: Vector3 = home.global_position - target.global_position
		drift.y = 0.0

		if drift.length() > step_trigger_distance and not other_is_stepping:
			foot.stepping = true
			foot.t = 0.0
			foot.start_pos = target.global_position
			foot.end_pos = home.global_position
