extends Node
## LookController
##
## Move um Marker3D (look_target) em direção à cabeça do player mais próximo
## dentro do raio de detecção. Presumivelmente alguma outra coisa na sua
## cena (um LookAtModifier3D, ou lógica dentro do IKController) usa esse
## Marker3D como alvo pra girar a cabeça/pescoço na direção dele.

@export_node_path("CharacterBody3D") var player
@export_node_path("Marker3D") var look_target

@export var detection_radius := 5.0
@export var look_speed := 8.0
@export var search_interval := 0.25

## Ângulo máximo (em graus) que a cabeça vira em relação à frente do corpo,
## nos dois eixos. Passou disso, ela para de acompanhar e fica no limite —
## em vez de continuar girando até dar 360° no pescoço.
@export var max_yaw_deg := 80.0
@export var max_pitch_deg := 45.0

## Altura usada só como fallback, se o alvo não tiver CameraPivot/Camera3D
## (estrutura diferente, NPC sem câmera, etc).
@export var fallback_look_height := 1.6

var _player: CharacterBody3D
var _look_target: Marker3D
var _current_target: CharacterBody3D

# Posição de repouso do look_target (relativa ao player), pra ele voltar
# pra uma pose neutra quando ninguém está por perto — sem isso, a cabeça
# fica travada olhando pro último lugar onde alguém esteve, pra sempre.
var _rest_local_offset: Vector3


func _ready() -> void:
	_player = get_node(player)
	_look_target = get_node(look_target)

	_rest_local_offset = _player.to_local(_look_target.global_position)

	var timer := Timer.new()
	timer.wait_time = search_interval
	timer.autostart = true
	timer.one_shot = false
	timer.timeout.connect(_search_target)
	add_child(timer)


func _physics_process(delta: float) -> void:
	var desired_pos: Vector3

	if is_instance_valid(_current_target):
		desired_pos = _get_target_look_point(_current_target)
		desired_pos = _clamp_to_body_cone(desired_pos)
	else:
		# Ninguém por perto: volta suavemente pra pose neutra, na direção
		# em que o corpo já está olhando, em vez de ficar travado.
		desired_pos = _player.to_global(_rest_local_offset)

	# Suavização exponencial em vez de lerp(delta * speed) puro: com
	# look_speed alto ou um frame mais lento (delta maior), lerp(..., delta*speed)
	# pode passar de 1.0 e "ultrapassar" o alvo, causando tremedeira.
	var weight: float = 1.0 - exp(-look_speed * delta)
	_look_target.global_position = _look_target.global_position.lerp(desired_pos, weight)


func _get_target_look_point(target: CharacterBody3D) -> Vector3:
	var target_camera := target.get_node_or_null("CameraPivot/Camera3D") as Node3D
	if target_camera:
		return target_camera.global_position

	# Fallback, caso o alvo não siga a mesma estrutura de cena do Player.
	var pos := target.global_position
	pos.y += fallback_look_height
	return pos


func _clamp_to_body_cone(world_pos: Vector3) -> Vector3:
	var offset: Vector3 = world_pos - _player.global_position
	var distance: float = offset.length()
	if distance < 0.001:
		return world_pos

	# Converte pra espaço local do corpo (frente do player = eixo -Z local).
	var local_dir: Vector3 = (_player.global_transform.basis.inverse() * offset).normalized()

	var horizontal: Vector3 = Vector3(local_dir.x, 0.0, local_dir.z)
	var yaw: float = 0.0
	if horizontal.length() > 0.001:
		horizontal = horizontal.normalized()
		yaw = atan2(horizontal.x, -horizontal.z)  # 0 = reto pra frente
		yaw = clampf(yaw, -deg_to_rad(max_yaw_deg), deg_to_rad(max_yaw_deg))

	var pitch: float = asin(clampf(local_dir.y, -1.0, 1.0))
	pitch = clampf(pitch, -deg_to_rad(max_pitch_deg), deg_to_rad(max_pitch_deg))

	var clamped_local_dir := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		-cos(yaw) * cos(pitch)
	)

	var clamped_offset: Vector3 = _player.global_transform.basis * (clamped_local_dir * distance)
	return _player.global_position + clamped_offset


func _search_target() -> void:
	_current_target = _find_closest_player()


func _find_closest_player() -> CharacterBody3D:
	var closest: CharacterBody3D = null
	var best_distance := detection_radius

	for candidate in get_tree().get_nodes_in_group("players"):
		if candidate == _player:
			continue
		if not is_instance_valid(candidate):
			continue

		var distance: float = _player.global_position.distance_to(candidate.global_position)
		if distance < best_distance:
			best_distance = distance
			closest = candidate

	return closest
