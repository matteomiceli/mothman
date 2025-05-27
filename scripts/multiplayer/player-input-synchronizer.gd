extends MultiplayerSynchronizer

# Each client peer has authority over its own player_input, while the
# server has authority over the player itself.

@export var input_dir: Vector2

# Actions -- simulate just_pressed, just_released
@export var jump_pressed := false
@export var dash_pressed := false

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")

	if Input.is_action_just_pressed("jump"):
		jump.rpc()

	if Input.is_action_just_pressed("dash"):
		dash.rpc()
		
	# TODO-MM: refactor rest of movement logic under this synchronizer

@rpc("call_local")
func jump() -> void:
	jump_pressed = true


@rpc("call_local")
func dash() -> void:
	dash_pressed = true
