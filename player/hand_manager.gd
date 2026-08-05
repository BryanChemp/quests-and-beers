extends Node

enum Hand { LEFT, RIGHT }

@export var left_hand: Node
@export var right_hand: Node

var _two_hand_active := false

@export_group("Debug")
@export var debug_enabled := true

func _process(_delta):
	if debug_enabled:
		_handle_debug_input()

func equip_one_hand(hand: Hand) -> void:
	_two_hand_active = false
	_set_hand_state(hand, left_hand.HandState.ONE_HAND if hand == Hand.LEFT else right_hand.HandState.ONE_HAND)

func unequip(hand: Hand) -> void:
	if _two_hand_active:
		_two_hand_active = false
		left_hand.set_state(left_hand.HandState.REST)
		right_hand.set_state(right_hand.HandState.REST)
	else:
		_set_hand_state(hand, left_hand.HandState.REST if hand == Hand.LEFT else right_hand.HandState.REST)

func equip_two_hand() -> void:
	_two_hand_active = true
	left_hand.set_state(left_hand.HandState.TWO_HAND)
	right_hand.set_state(right_hand.HandState.TWO_HAND)

func _set_hand_state(hand: Hand, state) -> void:
	if hand == Hand.LEFT:
		left_hand.set_state(state)
	else:
		right_hand.set_state(state)

# --- Debug só pra testar antes do sistema de item existir ---

func _handle_debug_input():
	if Input.is_action_just_pressed("debug_left_rest"):
		unequip(Hand.LEFT)
	elif Input.is_action_just_pressed("debug_left_one"):
		equip_one_hand(Hand.LEFT)

	if Input.is_action_just_pressed("debug_right_rest"):
		unequip(Hand.RIGHT)
	elif Input.is_action_just_pressed("debug_right_one"):
		equip_one_hand(Hand.RIGHT)

	if Input.is_action_just_pressed("debug_two_hand"):
		equip_two_hand()
