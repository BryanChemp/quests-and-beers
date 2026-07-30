extends CharacterBody3D

@export var network_velocity: Vector3 = Vector3.ZERO
@export var network_on_floor: bool
@export var walk_speed := 2.0
## Velocidade ao segurar "run". Já bate com o max_speed_for_prediction do
## preset RUN (locomotion_presets.gd) — se mudar esse valor aqui, mude lá
## também, senão a previsão de passo satura antes de chegar na velocidade
## real e o pé fica "atrasado" correndo no topo da velocidade.
@export var run_speed := 4.0
@export var jump_velocity := 5.5
@export var acceleration := 12.0
@export var air_acceleration := 4.0

@onready var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
@onready var player_input: PlayerInput = $PlayerInput
@onready var interaction_ray: RayCast3D = $CameraPivot/InteractionRay


func _enter_tree():
	set_multiplayer_authority(str(name).to_int())


func _ready() -> void:
	print("--------------------------------")
	print("Node:", name)
	print("Authority:", get_multiplayer_authority())
	print("My ID:", multiplayer.get_unique_id())
	print("Is Authority:", is_multiplayer_authority())
	$CameraPivot/Camera3D.current = is_multiplayer_authority()
	add_to_group("players")


func _physics_process(delta: float) -> void:
	if multiplayer.multiplayer_peer == null:
		return
	if !is_multiplayer_authority():
		return

	if !is_on_floor():
		velocity.y -= gravity * delta
	if player_input.jump and is_on_floor():
		velocity.y = jump_velocity

	if player_input.interact:
		interact()

	var input := player_input.movement
	var direction := (
		transform.basis * Vector3(input.x, 0.0, input.y)
	).normalized()

	var speed := run_speed if player_input.run else walk_speed
	var accel := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(
		velocity.x,
		direction.x * speed,
		accel * delta
	)
	velocity.z = move_toward(
		velocity.z,
		direction.z * speed,
		accel * delta
	)
	move_and_slide()
	network_velocity = velocity
	network_on_floor = is_on_floor()


func interact() -> void:
	if !interaction_ray.is_colliding():
		return

	var collider := interaction_ray.get_collider()
	if collider is Interactable:
		collider.interact(self)
