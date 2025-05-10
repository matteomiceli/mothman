extends MultiplayerSynchronizer

# Set via RPC to simulate is_action_just_pressed.
@export var jumping := false

# Synchronized property.
@export var input_dir := Vector2()

func _ready() -> void:
	#set_process(get_multiplayer_authority() == multiplayer.get_unique_id())
	pass

@rpc("call_local")
func jump():
	jumping = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta) -> void:
	if not is_multiplayer_authority():
		return
	input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")

	if Input.is_action_just_pressed("jump"):
		jump.rpc()
