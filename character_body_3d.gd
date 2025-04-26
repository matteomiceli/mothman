extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 4.0  # movement speed
var jump_speed = 6.0  # determines jump height
var mouse_sensitivity = 0.002  # turning speed

# Jump
var is_jumping = false

# Dash
var is_dashing = false
var dash_force = 40
const DASH_DECAY = 200
var dash_velocity: Vector3

func get_input():
	var input = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	velocity.x = input.x * speed
	velocity.z = input.y * speed

	if Input.is_action_just_pressed("dash") and not is_dashing:
		is_dashing = true
		dash_velocity.x = input.x * dash_force
		dash_velocity.z = input.y * dash_force

	if Input.is_action_pressed("jump"):
		jump()

func _physics_process(delta):
	get_input()
	velocity.y += -gravity * delta

	if is_on_floor():
		is_jumping = false

	if is_dashing:
		var decay_amount = DASH_DECAY * delta
		if dash_velocity.length() <= decay_amount:
			dash_velocity = Vector3.ZERO
			is_dashing = false
		else:
			dash_velocity -= dash_velocity.normalized() * decay_amount

	velocity.x = velocity.x + dash_velocity.x
	velocity.z = velocity.z + dash_velocity.z

	move_and_slide()

func jump():
	if is_jumping or not is_on_floor():
		return

	is_jumping = true
	velocity.y = 5
