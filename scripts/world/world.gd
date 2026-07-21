extends Node3D

@export var player_scene: PackedScene

@onready var players: Node = $Players


func _ready():
	if multiplayer.is_server():
		NetworkManager.player_connected.connect(_spawn_player)
		_spawn_player(multiplayer.get_unique_id())


func _spawn_player(peer_id: int):
	print("Spawnando ", peer_id)
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	players.add_child(player, true)
