extends Node

@export var player_scene: PackedScene

@onready var players: Node3D = $"../Players"
@onready var spawn_points: Node3D = $"../SpawnPoints"

func _ready() -> void:
	NetworkManager.player_connected.connect(spawn_player)

func spawn_player(peer_id: int) -> void:

	var player := player_scene.instantiate()

	player.name = str(peer_id)

	players.add_child(player)

	var marker := spawn_points.get_child(
		(peer_id - 1) % spawn_points.get_child_count()
	) as Marker3D

	player.global_position = marker.global_position

	player.set_multiplayer_authority(peer_id)
