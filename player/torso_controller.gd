class_name TorsoController
extends SkeletonModifier3D
## TorsoController
##
## Filho direto de um Skeleton3D. Só faz o "lean" da cintura: inclina o
## bone da cintura com base na velocidade LOCAL do Player (frente/trás e
## lateral), simulando ajuste de equilíbrio ao andar. Escreve em cima da
## pose já animada do frame (o Skeleton3D garante que isto roda depois
## da animação, então não precisa se preocupar com ordem/acúmulo).
##
## Usa network_velocity, não velocity: este script roda em TODO player na
## sua tela (o seu e os remotos), mas velocity só é atualizado por quem
## chama move_and_slide() — e isso só acontece em quem é
## is_multiplayer_authority() daquele Player (ver character_body.gd). Nos
## players remotos, velocity fica parado; network_velocity é o campo que
## o dono replica via MultiplayerSynchronizer, então é o único que
## realmente reflete o movimento de outra pessoa na sua tela.

@export_node_path("CharacterBody3D") var player
@export var waist_bone_name := "Waist"
## Inclinação lateral (roll) por (m/s) de velocidade de strafe.
@export var lean_side_amount := 0.05
## Inclinação frente/trás (pitch) por (m/s) de velocidade frente/trás.
@export var lean_forward_amount := 0.03
@export var max_lean_deg := 8.0
## Velocidade de suavização do lean (maior = reage mais rápido).
@export var lean_smooth_speed := 8.0

var _player: CharacterBody3D
var _waist_idx: int
var _waist_roll := 0.0
var _waist_pitch := 0.0


func _ready() -> void:
	_player = get_node(player)
	var skeleton := get_skeleton()
	_waist_idx = skeleton.find_bone(waist_bone_name)
	if _waist_idx < 0:
		push_warning("TorsoController: bone '%s' não encontrado." % waist_bone_name)


# Chamado automaticamente pelo Skeleton3D, DEPOIS de aplicar a pose da
# animação deste frame. Não usar _process/_physics_process aqui.
func _process_modification() -> void:
	if not is_instance_valid(_player) or _waist_idx < 0:
		return

	var skeleton := get_skeleton()
	var delta := get_physics_process_delta_time()

	# Velocidade LOCAL (relativa à rotação do corpo): x = lateral, z = frente/trás.
	# network_velocity em vez de velocity — ver nota no topo do arquivo.
	var local_vel: Vector3 = _player.transform.basis.inverse() * _player.network_velocity

	var max_lean := deg_to_rad(max_lean_deg)
	var t := 1.0 - exp(-lean_smooth_speed * delta)
	var target_roll := clampf(-local_vel.x * lean_side_amount, -max_lean, max_lean)
	var target_pitch := clampf(local_vel.z * lean_forward_amount, -max_lean, max_lean)
	_waist_roll = lerp(_waist_roll, target_roll, t)
	_waist_pitch = lerp(_waist_pitch, target_pitch, t)

	var waist_extra := Quaternion.from_euler(Vector3(_waist_pitch, 0.0, _waist_roll))
	var waist_base := skeleton.get_bone_pose_rotation(_waist_idx)
	skeleton.set_bone_pose_rotation(_waist_idx, waist_base * waist_extra)
