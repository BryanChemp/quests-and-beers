class_name ProceduralLocomotion
extends Node
## ProceduralLocomotion — v2
##
## O que mudou em relação à v1 (e por quê):
##
## 1) PÉ ESTICANDO (principalmente correndo)
##    Antes o passo só disparava por distância pé→home E só se o outro pé
##    não estivesse no ar. Correndo, os dois pés queriam sair ao mesmo
##    tempo, um ficava bloqueado e a perna esticava até o gatilho.
##    Agora existe "max_stretch": distância do QUADRIL (player) até o pé
##    plantado. Ao passar disso o passo dispara de qualquer jeito, sem
##    esperar o outro pé. A perna deixa de esticar.
##
## 2) PÉ FLUTUANDO
##    Antes o pé pousava exatamente no FootHome, que é um Marker3D no ar
##    (na altura do quadril/tornozelo do rig). Agora todo destino de passo
##    passa por um raycast vertical: o pé pousa NO CHÃO real.
##
## 3) PASSO QUE NÃO TERMINA
##    step_duration agora é escalado pela velocidade real:
##    duração_efetiva = step_duration * (reference_speed / velocidade).
##    Correndo mais rápido, a passada fecha mais rápido — nada de dois pés
##    arrastando porque a animação não acabou.
##
## 4) ALTURA
##    step_height agora é a altura BASE, e ainda ganha um bônus conforme a
##    velocidade (até +50%). Os presets também subiram.

@export_node_path("CharacterBody3D") var player
@export_node_path("Marker3D") var left_foot_home
@export_node_path("Marker3D") var right_foot_home
@export_node_path("Marker3D") var left_foot_target
@export_node_path("Marker3D") var right_foot_target

@export var state: LocomotionPresets.State = LocomotionPresets.State.WALK:
	set(value):
		var changed := value != state
		state = value
		_apply_preset()
		if changed and debug_print_preset:
			_print_preset()

@export var step_duration: float = 0.26
@export var step_height: float = 0.20
@export var step_trigger_distance: float = 0.32
@export var max_stretch: float = 0.52
@export var ease_strength: float = -1.6
@export var reference_speed: float = 2.0

## Se o pé ficar absurdamente longe (teleporte, queda, spawn), reposiciona.
@export var snap_distance: float = 1.5

@export_group("Ground")
## Camadas de colisão consideradas "chão" pelo raycast de pouso.
@export_flags_3d_physics var ground_mask: int = 1
## Quanto acima/abaixo do FootHome o raycast procura chão.
@export var ground_probe_up: float = 0.6
@export var ground_probe_down: float = 1.2
## Offset do tornozelo em relação ao contato do pé com o chão.
@export var foot_ground_offset: float = 0.0

@export_group("Debug")
## Imprime o preset ativo sempre que o estado muda.
@export var debug_print_preset: bool = true
## Imprime cada passo disparado (spam alto — use só pra calibrar).
@export var debug_print_steps: bool = false

var _player: CharacterBody3D
var _left_home: Node3D
var _right_home: Node3D
var _left_target: Node3D
var _right_target: Node3D

var _last_printed_state: int = -1

class FootStep:
	var name: String = ""
	var stepping: bool = false
	var t: float = 0.0
	var duration: float = 0.26
	var height: float = 0.2
	var start_pos: Vector3 = Vector3.ZERO
	var end_pos: Vector3 = Vector3.ZERO
	## Posição do pé em ESPAÇO DE MUNDO enquanto ele está plantado no chão.
	var planted_pos: Vector3 = Vector3.ZERO

var _left := FootStep.new()
var _right := FootStep.new()


func _ready() -> void:
	_player = get_node(player)
	_left_home = get_node(left_foot_home)
	_right_home = get_node(right_foot_home)
	_left_target = get_node(left_foot_target)
	_right_target = get_node(right_foot_target)

	_left.name = "L"
	_right.name = "R"

	# Os targets NÃO podem herdar o transform do corpo: eles vivem em mundo.
	_left_target.top_level = true
	_right_target.top_level = true

	_left.planted_pos = _ground_point(_left_home.global_position)
	_right.planted_pos = _ground_point(_right_home.global_position)
	_left_target.global_position = _left.planted_pos
	_right_target.global_position = _right.planted_pos

	_apply_preset()
	if debug_print_preset:
		_print_preset()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(_player):
		return

	if debug_print_preset and state != _last_printed_state:
		_print_preset()

	if not _is_on_floor():
		# No ar: nada de passos, mas o pé continua travado em mundo.
		_left_target.global_position = _left.planted_pos
		_right_target.global_position = _right.planted_pos
		return

	var speed: float = _horizontal_speed()

	_update_foot(_left, _left_home, _left_target, delta, speed, _right)
	_update_foot(_right, _right_home, _right_target, delta, speed, _left)


func _horizontal_speed() -> float:
	var v: Vector3 = _player.velocity
	# Remoto: move_and_slide() não roda, velocity fica 0. Use a replicada.
	if v.length_squared() < 0.0001 and "network_velocity" in _player:
		v = _player.network_velocity
	v.y = 0.0
	return v.length()


func _is_on_floor() -> bool:
	if "network_on_floor" in _player:
		return _player.network_on_floor
	return _player.is_on_floor()


func _apply_preset() -> void:
	var p: Dictionary = LocomotionPresets.get_preset(state)
	step_duration = p["step_duration"]
	step_height = p["step_height"]
	step_trigger_distance = p["step_trigger_distance"]
	max_stretch = p.get("max_stretch", step_trigger_distance * 1.6)
	ease_strength = p["ease_strength"]
	reference_speed = p.get("reference_speed", 2.0)


func _print_preset() -> void:
	_last_printed_state = state
	print("[ProceduralLocomotion] %s -> preset=%s dur=%.2f height=%.2f trigger=%.2f stretch=%.2f ease=%.2f ref_speed=%.1f" % [
		_player.name if is_instance_valid(_player) else "?",
		LocomotionPresets.get_state_name(state),
		step_duration, step_height, step_trigger_distance, max_stretch,
		ease_strength, reference_speed,
	])


## Projeta um ponto no chão real abaixo dele. Isso é o que tira o pé
## flutuando: o FootHome está na altura do rig, não na altura do terreno.
func _ground_point(p: Vector3) -> Vector3:
	var space := _player.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(
		p + Vector3.UP * ground_probe_up,
		p + Vector3.DOWN * ground_probe_down
	)
	params.collision_mask = ground_mask
	params.exclude = [_player.get_rid()]
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return p
	return (hit["position"] as Vector3) + Vector3.UP * foot_ground_offset


## Duração efetiva do passo: mais rápido você anda, mais curta a passada.
func _effective_duration(speed: float) -> float:
	if speed < 0.05:
		return step_duration
	var scale: float = reference_speed / speed
	return clampf(step_duration * scale, 0.08, step_duration * 1.6)


## Altura efetiva: base + até 50% de bônus conforme a velocidade.
func _effective_height(speed: float) -> float:
	var ratio: float = clampf(speed / maxf(reference_speed, 0.01), 0.0, 1.5)
	return step_height * (0.75 + 0.5 * ratio)


func _update_foot(foot: FootStep, home: Node3D, target: Node3D, delta: float, speed: float, other: FootStep) -> void:
	if foot.stepping:
		foot.t += delta / maxf(foot.duration, 0.01)
		var f: float = clampf(foot.t, 0.0, 1.0)
		var eased_f: float = ease(f, ease_strength)
		# O home continua andando durante a passada: mira sempre no home
		# atual (já projetado no chão), senão o pé pousa atrás do corpo.
		foot.end_pos = _ground_point(home.global_position)
		var pos: Vector3 = foot.start_pos.lerp(foot.end_pos, eased_f)
		pos.y += sin(f * PI) * foot.height
		target.global_position = pos
		if f >= 1.0:
			foot.stepping = false
			foot.planted_pos = foot.end_pos
			target.global_position = foot.planted_pos
		return

	# --- Pé plantado: TRAVA em mundo (não acompanha o corpo) ---
	target.global_position = foot.planted_pos

	var home_ground: Vector3 = _ground_point(home.global_position)

	var drift: Vector3 = home_ground - foot.planted_pos
	drift.y = 0.0
	var d: float = drift.length()

	# Quanto a perna já está esticada, medida do quadril até o pé.
	var stretch_vec: Vector3 = _player.global_position - foot.planted_pos
	stretch_vec.y = 0.0
	var stretch: float = stretch_vec.length()

	if d > snap_distance:
		foot.planted_pos = home_ground
		target.global_position = foot.planted_pos
		if debug_print_steps:
			print("[ProceduralLocomotion] %s SNAP (d=%.2f)" % [foot.name, d])
		return

	var forced: bool = stretch > max_stretch
	var normal: bool = d > step_trigger_distance and not other.stepping

	if forced or normal:
		foot.stepping = true
		foot.t = 0.0
		foot.duration = _effective_duration(speed)
		foot.height = _effective_height(speed)
		foot.start_pos = foot.planted_pos
		foot.end_pos = home_ground
		if debug_print_steps:
			print("[ProceduralLocomotion] %s STEP %s | speed=%.2f d=%.2f stretch=%.2f dur=%.2f h=%.2f" % [
				foot.name, "FORCED" if forced else "normal",
				speed, d, stretch, foot.duration, foot.height,
			])
