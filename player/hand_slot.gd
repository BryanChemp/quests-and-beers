extends Node3D

enum HandState { REST, ONE_HAND, TWO_HAND }

# Struct simples pra agrupar target + pole de cada pose
class PoseRef:
	var target: Node3D
	var pole: Node3D
	func _init(t: Node3D, p: Node3D):
		target = t
		pole = p

@export_group("Rest")
@export var rest_target: Node3D
@export var rest_pole: Node3D

@export_group("One Hand")
@export var one_hand_target: Node3D
@export var one_hand_pole: Node3D

@export_group("Two Hand")
@export var two_hand_target: Node3D
@export var two_hand_pole: Node3D

@export_group("IK Output")
@export var ik_target: Node3D
@export var ik_pole_target: Node3D

@export_group("Blend")
@export var blend_speed := 32.0

var state: HandState = HandState.REST
var _poses: Dictionary = {}

var _current_target_xform: Transform3D
var _current_pole_xform: Transform3D

func _ready():
	_poses = {
		HandState.REST: PoseRef.new(rest_target, rest_pole),
		HandState.ONE_HAND: PoseRef.new(one_hand_target, one_hand_pole),
		HandState.TWO_HAND: PoseRef.new(two_hand_target, two_hand_pole),
	}
	_current_target_xform = rest_target.global_transform
	_current_pole_xform = rest_pole.global_transform
	ik_target.global_transform = _current_target_xform
	ik_pole_target.global_transform = _current_pole_xform

func _process(delta):
	var pose: PoseRef = _poses[state]
	var t = 1.0 - exp(-blend_speed * delta)

	_current_target_xform = _current_target_xform.interpolate_with(pose.target.global_transform, t)
	_current_pole_xform = _current_pole_xform.interpolate_with(pose.pole.global_transform, t)

	ik_target.global_transform = _current_target_xform
	ik_pole_target.global_transform = _current_pole_xform

func set_state(new_state: HandState) -> void:
	state = new_state
