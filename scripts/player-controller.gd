extends CharacterBody3D

@onready var anim_tree = $PlayerModel/AnimationTree

const SPEED := 6
const JUMP_VELOCITY := 5

# Animations
const BLEND_SPEED := 15
enum {IDLE, RUN, JUMP, JUMP_ANTICIPATION}
var currAnim := IDLE
var run_val: float = 0.0
var jump_val: float = 0.0
var jump_anticipation_val: float = 0.0

# Dash
var is_dashing := false
var dash_velocity: Vector3
const DASH_FORCE = 40
const DASH_DECAY = 200


func _enter_tree() -> void:
	# Set the player global value when this node is instantiated
	Global.player = self


func _physics_process(delta: float):
	handle_movement(delta)
	apply_gravity(delta)
	handle_animations(delta)

	move_and_slide()


func apply_gravity(delta: float):
	if not is_on_floor():
		velocity += get_gravity() * delta

func handle_movement(delta: float):
	var input_dir := Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	handle_dash_decay(delta)

	# TODO: this feels like it wants to be distilled down to an `apply_speed_modifiers` function that
	# applies all speed modifiers on the player, not just the dash modifier
	velocity.x = (input_dir.x * SPEED) + dash_velocity.x
	velocity.z = (input_dir.y * SPEED) + dash_velocity.z

 	# Handle player rotation
	var look_direction := Vector3(input_dir.x, 0, input_dir.y)
	if not position.is_equal_approx(position - look_direction):
		self.look_at(position + look_direction)

	if is_on_floor():
		if velocity.is_zero_approx():
			currAnim = IDLE
		else:
			currAnim = RUN

	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			currAnim = JUMP

	if Input.is_action_just_pressed("dash"):
		if not is_dashing:
			is_dashing = true
			dash_velocity.x = input_dir.x * DASH_FORCE
			dash_velocity.z = input_dir.y * DASH_FORCE


func handle_dash_decay(delta: float):
	if not is_dashing:
		return

	var decay_amount := DASH_DECAY * delta
	if dash_velocity.length() > decay_amount:
		dash_velocity -= dash_velocity.normalized() * decay_amount
	else:
		dash_velocity = Vector3.ZERO
		is_dashing = false


func handle_animations(delta: float):
	match currAnim:
		IDLE:
			run_val = lerpf(run_val, 0, delta * BLEND_SPEED)
			jump_val = lerpf(jump_val, 0, delta * BLEND_SPEED)
			jump_anticipation_val = lerpf(jump_anticipation_val, 0, delta * BLEND_SPEED)
		RUN:
			run_val = lerpf(run_val, 1, delta * BLEND_SPEED)
			jump_val = lerpf(jump_val, 0, delta * BLEND_SPEED)
			jump_anticipation_val = lerpf(jump_anticipation_val, 0, delta * BLEND_SPEED)
		JUMP:
			run_val = lerpf(run_val, 0, delta * BLEND_SPEED)
			jump_val = lerpf(jump_val, 1, delta * BLEND_SPEED)
			jump_anticipation_val = lerpf(jump_anticipation_val, 0, delta * BLEND_SPEED)
		JUMP_ANTICIPATION:
			run_val = lerpf(run_val, 0, delta * BLEND_SPEED)
			jump_val = lerpf(jump_val, 0, delta * BLEND_SPEED)
			jump_anticipation_val = lerpf(jump_anticipation_val, 1, delta * BLEND_SPEED)

	update_blend_values()

func update_blend_values():
	anim_tree["parameters/to_run/blend_amount"] = run_val
	anim_tree["parameters/to_jump/blend_amount"] = jump_val
	anim_tree["parameters/to_jump_anticipation/blend_amount"] = jump_anticipation_val
