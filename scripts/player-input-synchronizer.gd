extends MultiplayerSynchronizer

# Each client peer has authority over its own player_input, while the
# server has authority over the player itself.

@export var input_dir: Vector2

func _enter_tree() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")

	# TODO-MM: refactor rest of movement logic under this synchronizer
