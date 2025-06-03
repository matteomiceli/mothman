extends MultiplayerSynchronizer

# Each client peer has authority over its own player_input, while the
# server has authority over the player itself.

@export var input_dir: Vector2

# Actions -- simulate just_pressed, just_released
@export var jump_pressed := false
@export var dash_pressed := false
@export var grab_pressed := false
@export var grab_released := false
@export var crouch_pressed := false
@export var tag_pressed := false

func _physics_process(_delta: float) -> void:
	if not is_multiplayer_authority(): return
	input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")

	if Input.is_action_just_pressed("jump"):
		jump.rpc()

	if Input.is_action_just_pressed("dash"):
		dash.rpc()

	if Input.is_action_just_pressed("grab"):
		grab.rpc()

	if Input.is_action_just_released("grab"):
		grab_release.rpc()

	if Input.is_action_pressed("crouch"):
		crouch.rpc()
	
	if Input.is_action_pressed("tag"):
		tag.rpc()	

@rpc("call_local")
func jump() -> void:
	jump_pressed = true

@rpc("call_local")
func dash() -> void:
	dash_pressed = true

@rpc("call_local")
func grab() -> void:
	grab_pressed = true

@rpc("call_local")
func grab_release() -> void:
	grab_released = true

@rpc("call_local")
func crouch() -> void:
	crouch_pressed = true
	
@rpc("call_local")
func tag() -> void:
	tag_pressed = true
