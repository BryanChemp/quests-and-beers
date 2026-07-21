extends Interactable

@onready var anim: AnimationPlayer = $AnimationPlayer

var is_up := false

func interact(player):
	if !multiplayer.is_server():
		request_interact.rpc_id(1)
		return
	
	toggle()

@rpc("any_peer", "reliable")
func request_interact():
	if !multiplayer.is_server():
		return

	toggle()

func toggle():
	is_up = !is_up
	play_animation.rpc(is_up)

@rpc("call_local", "reliable")
func play_animation(up: bool):
	if up:
		anim.play("up")
	else:
		anim.play("down")
