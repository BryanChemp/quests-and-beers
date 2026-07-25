extends Node
## HipController
##
## O FootPlacement já resolve a altura de CADA pé de forma independente
## (um raycast por pé). O que faltava é o quadril: sem isso, numa rampa, os
## dois TwoBoneIK3D tentam esticar a perna até o pé mais baixo igualmente,
## e se a distância passar do alcance da perna, o IK "trava" e volta pra
## pose de rest — foi o que aconteceu no seu teste.
##
## Esse script baixa o Skeleton3D até acompanhar o pé mais baixo, dentro de
## um limite (max_leg_length). O resultado: a perna do lado baixo fica quase
## esticada, a do lado alto dobra mais — porque ela ficou relativamente mais
## curta em relação ao quadril, não porque alguém disse "dobra essa perna".

@export_node_path("CharacterBody3D") var player
@export_node_path("Node3D") var skeleton
@export_node_path("Marker3D") var left_foot_target
@export_node_path("Marker3D") var right_foot_target

## Distância vertical máxima que o quadril pode descer em relação à altura
## de repouso — meça no editor a distância do quadril até o pé com a perna
## esticada (mas não 100% travada, deixe uma pequena folga).
@export var max_leg_length: float = 0.55

## Suavização do movimento vertical do quadril. Maior = mais lento/suave.
@export var smoothing: float = 10.0

var _player: CharacterBody3D
var _skeleton: Node3D
var _left_target: Node3D
var _right_target: Node3D

var _rest_local_y: float
var _current_offset: float = 0.0


func _ready() -> void:
	_player = get_node(player)
	_skeleton = get_node(skeleton)
	_left_target = get_node(left_foot_target)
	_right_target = get_node(right_foot_target)

	# Altura local do Skeleton3D dentro do VisualRoot, capturada como
	# "quadril em pé, chão plano" — é a partir dela que descemos.
	_rest_local_y = _skeleton.position.y


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var lower_foot_y: float = minf(_left_target.global_position.y, _right_target.global_position.y)

	# O quanto o pé mais baixo está abaixo do "chão esperado" (a posição Y
	# do próprio player, que é onde o CharacterBody3D acha que está o chão).
	var drop: float = lower_foot_y - _player.global_position.y

	# Nunca deixa o quadril descer mais que o alcance da perna, senão a
	# perna do lado alto estica além do limite físico do IK.
	var desired_offset: float = clampf(drop, -max_leg_length, 0.05)

	_current_offset = lerpf(_current_offset, desired_offset, 1.0 - exp(-smoothing * delta))
	_skeleton.position.y = _rest_local_y + _current_offset
