extends Node

#127.0.0.1

signal game_started
signal player_connected(peer_id: int)

const PORT := 7777
const MAX_PLAYERS := 8

var peer := ENetMultiplayerPeer.new()

func _ready():
	multiplayer.peer_connected.connect(_player_connected)
	multiplayer.peer_disconnected.connect(_player_disconnected)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)


func _player_connected(id: int):
	print("Player conectado:", id)
	player_connected.emit(id)


func _player_disconnected(id: int):
	print("Player saiu:", id)


func _connected():
	print("Conectado ao servidor!")
	game_started.emit()


func _connection_failed():
	print("Falha ao conectar!")

func host_game() -> void:

	var error := peer.create_server(PORT, MAX_PLAYERS)

	if error != OK:
		push_error("Erro ao criar servidor: %s" % error)
		return

	multiplayer.multiplayer_peer = peer

	print("Servidor iniciado!")
	
	player_connected.emit(multiplayer.get_unique_id())
	game_started.emit()


func join_game(ip: String) -> void:

	var error := peer.create_client(ip, PORT)

	if error != OK:
		push_error("Erro ao conectar: %s" % error)
		return

	multiplayer.multiplayer_peer = peer

	print("Conectando...")
