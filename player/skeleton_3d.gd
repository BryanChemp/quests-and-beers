extends SkeletonModifier3D
## TorsoController
## Precisa ser filho direto do Skeleton3D que ele modifica.

@export_node_path("CharacterBody3D") var player
@export_node_path("Node3D") var camera_pivot

@export var waist_bone_name := "Waist"
@export var head_bone_name := "Head"

@export var waist_follow_ratio := 0.45
@export var waist_smooth_speed := 6.0
@export var max_head_yaw_deg := 80.0

@export var lean_side_amount := 0.05
@export var lean_forward_amount := 0.03
@export var max_lean_deg := 8.0
@export var lean_smooth_speed := 8.0

var _player: CharacterBody3D
var _camera_pivot: Node3D
var _skeleton: Skeleton3D
var _waist_idx: int
var _head_idx: int

var _waist_yaw := 0.0
var _waist_roll := 0.0
var _waist_pitch := 0.0

func _ready() -> void:
	_player = get_node(player)
	_camera_pivot = get_node(camera_pivot)
	_skeleton = get_skeleton()  # helper do próprio SkeletonModifier3D
	_waist_idx = _skeleton.find_bone(waist_bone_name)
	_head_idx = _skeleton.find_bone(head_bone_name)

# Chamado automaticamente pelo Godot, DEPOIS da AnimationPlayer processar
# a pose deste frame. Não use _process/_physics_process aqui.
func _process_modification() -> void:
	if not is_instance_valid(_player) or _waist_idx < 0 or _head_idx < 0:
		return

	var delta := get_process_delta_time() if not Engine.is_in_physics_frame() \
		else get_physics_process_delta_time()

	# --- Olhar ---
	var offset := wrapf(_camera_pivot.camera_yaw - _player.rotation.y, -PI, PI)
	var max_head := deg_to_rad(max_head_yaw_deg)
	var head_yaw := clampf(offset, -max_head, max_head)

	var t := 1.0 - exp(-waist_smooth_speed * delta)
	var waist_target_yaw := offset * waist_follow_ratio
	_waist_yaw = lerp_angle(_waist_yaw, waist_target_yaw, t)

	# --- Lean ao andar ---
	var local_vel: Vector3 = _player.transform.basis.inverse() * _player.velocity
	var max_lean := deg_to_rad(max_lean_deg)
	var lt := 1.0 - exp(-lean_smooth_speed * delta)
	var target_roll := clampf(-local_vel.x * lean_side_amount, -max_lean, max_lean)
	var target_pitch := clampf(local_vel.z * lean_forward_amount, -max_lean, max_lean)
	_waist_roll = lerp(_waist_roll, target_roll, lt)
	_waist_pitch = lerp(_waist_pitch, target_pitch, lt)

	# --- Aplica em cima da pose já animada, sem descartá-la ---
	var waist_extra := Quaternion.from_euler(Vector3(_waist_pitch, _waist_yaw, _waist_roll))
	var waist_base := _skeleton.get_bone_pose_rotation(_waist_idx)
	_skeleton.set_bone_pose_rotation(_waist_idx, waist_base * waist_extra)

	var head_extra := Quaternion.from_euler(Vector3(0, head_yaw, 0))
	var head_base := _skeleton.get_bone_pose_rotation(_head_idx)
	_skeleton.set_bone_pose_rotation(_head_idx, head_base * head_extra)
