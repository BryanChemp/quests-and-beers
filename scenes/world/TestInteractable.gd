extends Interactable

@onready var anim: AnimationPlayer = $AnimationPlayer;

var is_up = false;

func interact(player):
	print(player.name + " interagiu!")
	
	if is_up:
		anim.play("down");
	else:
		anim.play("up");


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "up":
		is_up = true;
	else:
		is_up = false;
