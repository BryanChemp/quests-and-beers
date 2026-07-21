extends Control

@onready var host_button: Button = $VBoxContainer/HostButton
@onready var join_button: Button = $VBoxContainer/JoinButton
@onready var ip_edit: LineEdit = $VBoxContainer/IpEdit

func _ready():
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	NetworkManager.game_started.connect(_start_game)

func _start_game():
	print("startando game");
	var error := get_tree().change_scene_to_file("res://scenes/world/TestWorld.tscn")
	print(error)

func _on_host_pressed():
	NetworkManager.host_game()

func _on_join_pressed():
	NetworkManager.join_game(ip_edit.text)
