extends MultiplayerSynchronizer

@export var input_dir: Vector2

func _enter_tree() -> void:
	pass

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
