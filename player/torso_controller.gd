class_name TorsoController
extends SkeletonModifier3D
## TorsoController
##
## Filho direto de um Skeleton3D. Inclina o bone da cintura com base na
## velocidade LOCAL do Player (frente/trás e lateral), simulando ajuste
## de equilíbrio ao andar. Escreve em cima da pose já animada do frame (o
## Skeleton3D garante que isto roda depois da animação, então não precisa
## se preocupar com ordem/acúmulo).
##
## v2 — pedido "ajustar conforme a velocidade pra melhor física". Duas
## coisas novas, além do lean por velocidade que já existia:
##
## 1) LEAN DE ACELERAÇÃO
##    Antes só a velocidade CONSTANTE inclinava a cintura. Agora a
##    aceleração (variação da velocidade local por segundo) também gera
##    um lean extra, na direção contrária à mudança — a sensação de
##    inércia: o corpo "atrasa" quando você começa/para de andar
##    bruscamente ou muda de direção rápido numa curva. É isso que dá
##    peso de verdade, diferente de só reagir à velocidade do instante.
##
## 2) HIP BOB
##    Um bob vertical na posição do bone (não só rotação), com frequência
##    E amplitude escaladas pela velocidade horizontal — quanto mais
##    rápido anda, mais rápido e mais forte o bob. Some sozinho quando o
##    personagem para (amplitude cai a zero, a fase só deixa de avançar).
##
## Os dois podem ser desligados (enable_accel_lean / enable_hip_bob) se
## não curtir o efeito ou quiser calibrar isolado.
##
## Sinal do lean de aceleração e frequência do bob são chutes de ponto de
## partida — pode ser que precise inverter algum sinal ou reduzir os
## valores pro seu rig, é só mexer nos exports com o jogo rodando.
##
## Continua usando network_velocity, não velocity: este script roda em
## TODO player na sua tela (o seu e os remotos), mas velocity só é
## atualizado por quem chama move_and_slide() — e isso só acontece em
## quem é is_multiplayer_authority() daquele Player (ver
## character_body.gd). Nos players remotos, velocity fica parado;
## network_velocity é o campo que o dono replica via
## MultiplayerSynchronizer, então é o único que realmente reflete o
## movimento de outra pessoa na sua tela.
@export_node_path("CharacterBody3D") var player
@export var waist_bone_name := "Waist"

@export_group("Lean por velocidade")
## Inclinação lateral (roll) por (m/s) de velocidade de strafe.
@export var lean_side_amount := 0.05
## Inclinação frente/trás (pitch) por (m/s) de velocidade frente/trás.
@export var lean_forward_amount := 0.03
@export var max_lean_deg := 8.0
## Velocidade de suavização do lean (maior = reage mais rápido).
@export var lean_smooth_speed := 8.0

@export_group("Lean por aceleração")
@export var enable_accel_lean := true
## Inclinação extra por (m/s²) de aceleração local (efeito de inércia).
@export var accel_lean_amount := 0.015
@export var max_accel_lean_deg := 6.0

@export_group("Hip bob")
@export var enable_hip_bob := true
## Amplitude máxima do bob (m), atingida em bob_reference_speed.
@export var bob_amount := 0.015
## Ciclos de bob por metro percorrido (maior = cadência "mais rápida" visualmente).
@export var bob_frequency := 1.6
## Velocidade (m/s) na qual o bob atinge amplitude máxima.
@export var bob_reference_speed := 5.5

var _player: CharacterBody3D
var _waist_idx: int
var _waist_roll := 0.0
var _waist_pitch := 0.0
var _prev_local_vel := Vector3.ZERO
var _bob_phase := 0.0
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
	if delta <= 0.0:
		return
	# Velocidade LOCAL (relativa à rotação do corpo): x = lateral, z = frente/trás.
	# network_velocity em vez de velocity — ver nota no topo do arquivo.
	var local_vel: Vector3 = _player.transform.basis.inverse() * _player.network_velocity
	var local_accel: Vector3 = (local_vel - _prev_local_vel) / delta
	_prev_local_vel = local_vel

	var max_lean := deg_to_rad(max_lean_deg)
	var t := 1.0 - exp(-lean_smooth_speed * delta)
	var target_roll := clampf(-local_vel.x * lean_side_amount, -max_lean, max_lean)
	var target_pitch := clampf(local_vel.z * lean_forward_amount, -max_lean, max_lean)

	if enable_accel_lean:
		var max_accel_lean := deg_to_rad(max_accel_lean_deg)
		# Sinal invertido: o corpo "atrasa" em relação à mudança de
		# velocidade (inércia), não acompanha ela.
		target_roll -= clampf(local_accel.x * accel_lean_amount, -max_accel_lean, max_accel_lean)
		target_pitch -= clampf(local_accel.z * accel_lean_amount, -max_accel_lean, max_accel_lean)

	_waist_roll = lerp(_waist_roll, target_roll, t)
	_waist_pitch = lerp(_waist_pitch, target_pitch, t)
	var waist_extra := Quaternion.from_euler(Vector3(_waist_pitch, 0.0, _waist_roll))
	var waist_base_rot := skeleton.get_bone_pose_rotation(_waist_idx)
	skeleton.set_bone_pose_rotation(_waist_idx, waist_base_rot * waist_extra)

	if enable_hip_bob:
		var horizontal_speed := Vector2(local_vel.x, local_vel.z).length()
		var speed_ratio := clampf(horizontal_speed / maxf(bob_reference_speed, 0.01), 0.0, 1.0)
		_bob_phase += horizontal_speed * bob_frequency * delta
		var bob_offset := sin(_bob_phase * TAU) * bob_amount * speed_ratio
		var waist_base_pos := skeleton.get_bone_pose_position(_waist_idx)
		skeleton.set_bone_pose_position(_waist_idx, waist_base_pos + Vector3(0.0, bob_offset, 0.0))
