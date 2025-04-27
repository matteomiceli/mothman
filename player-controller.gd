extends CharacterBody3D

const SPEED = 6
const JUMP_VELOCITY = 5

# Dash
var is_dashing = false
var dash_velocity: Vector3
const DASH_FORCE = 40
const DASH_DECAY = 200

func apply_gravity(delta: float):
	velocity += get_gravity() * delta


func handle_movement(delta: float):
	var input := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	handle_dash_decay(delta)

	# TODO: this feels like it wants to be distilled down to an `apply_speed_modifiers` function that
	# applies all speed modifiers on the player, not just the dash modifier
	velocity.x = (input.x * SPEED) + dash_velocity.x
	velocity.z = (input.y * SPEED) + dash_velocity.z

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash"):
		if not is_dashing:
			is_dashing = true
			dash_velocity.x = input.x * DASH_FORCE
			dash_velocity.z = input.y * DASH_FORCE


func handle_dash_decay(delta: float):
	if not is_dashing:
		return

	var decay_amount := DASH_DECAY * delta
	if dash_velocity.length() > decay_amount:
		dash_velocity -= dash_velocity.normalized() * decay_amount
	else:
		dash_velocity = Vector3.ZERO
		is_dashing = false


func _physics_process(delta: float):
	handle_movement(delta)
	apply_gravity(delta)


	move_and_slide()
