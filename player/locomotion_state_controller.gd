extends Node
## LocomotionStateController
##
## Decide qual preset (LocomotionPresets.State) usar e aplica nos dois
## scripts junto (ProceduralLocomotion e FootPlacement), pra não precisar
## sincronizar os dois na mão toda vez que alguma coisa mudar.
##
## running vem direto do PlayerInput (action "run") — não precisa mais
## setar nada manualmente pra isso.
##
## is_crouching continua manual: ligue na sua lógica de agachar quando ela
## existir (ex: `locomotion_state_controller.is_crouching = true`).
##
## O strafe é detectado sozinho: compara a direção do movimento (mundo)
## com a frente do corpo. Passou de strafe_angle_threshold_deg, conta
## como lateral.
##
## Não existe combinação "crouch + strafe" nos presets atuais (só
## CROUCH_WALK/CROUCH_RUN) — se um dia precisar, é só adicionar
## CROUCH_WALK_STRAFE etc. em locomotion_presets.gd e um branch aqui.

@export_node_path("CharacterBody3D") var player
@export_node_path("PlayerInput") var player_input
@export_node_path("ProceduralLocomotion") var procedural_locomotion
@export_node_path("FootPlacement") var foot_placement

## Ligue isso na sua lógica de agachar (ainda não existe action pra isso).
@export var is_crouching := false

## Acima desse ângulo (graus) entre a direção do movimento e a frente do
## corpo, o movimento conta como "lateral" e usa o preset de strafe.
@export var strafe_angle_threshold_deg := 45.0

var _player: CharacterBody3D
var _player_input: PlayerInput
var _procedural_locomotion: ProceduralLocomotion
var _foot_placement: FootPlacement
var _current_state: LocomotionPresets.State = LocomotionPresets.State.WALK
var _has_applied_once := false


func _ready() -> void:
	_player = get_node(player)
	_player_input = get_node(player_input)
	_procedural_locomotion = get_node(procedural_locomotion)
	_foot_placement = get_node(foot_placement)


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return

	var horizontal_velocity := Vector2(_player.network_velocity.x, _player.network_velocity.z)
	if horizontal_velocity.length() < 0.05:
		return  # Parado: não precisa recalcular o preset a cada frame.

	var is_running: bool = _player_input.run
	var is_strafing := _is_strafing(horizontal_velocity)
	var new_state := _resolve_state(is_running, is_strafing)

	if new_state != _current_state or not _has_applied_once:
		_current_state = new_state
		_has_applied_once = true
		_procedural_locomotion.state = new_state
		_foot_placement.state = new_state


func _is_strafing(horizontal_velocity: Vector2) -> bool:
	var move_dir := Vector3(horizontal_velocity.x, 0.0, horizontal_velocity.y).normalized()
	var body_forward: Vector3 = -_player.global_transform.basis.z
	body_forward.y = 0.0
	body_forward = body_forward.normalized()
	var angle := rad_to_deg(move_dir.angle_to(body_forward))
	return angle > strafe_angle_threshold_deg


func _resolve_state(is_running: bool, is_strafing: bool) -> LocomotionPresets.State:
	if is_crouching:
		return LocomotionPresets.State.CROUCH_RUN if is_running else LocomotionPresets.State.CROUCH_WALK
	if is_strafing:
		return LocomotionPresets.State.RUN_STRAFE if is_running else LocomotionPresets.State.WALK_STRAFE
	return LocomotionPresets.State.RUN if is_running else LocomotionPresets.State.WALK
