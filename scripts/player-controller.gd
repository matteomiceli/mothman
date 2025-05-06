extends CharacterBody3D

@onready var anim_tree = $PlayerModel/AnimationTree
@onready var dash_bar = get_tree().get_root().get_node("World/CanvasLayer/DashCooldownBar")

const MOVE_SPEED := 6
const ACCELERATION := 90
const JUMP_VELOCITY := 8
const PLAYER_GRAVITY := Vector3(0, -20, 0)

# Animations
const BLEND_SPEED := 15
enum AnimState {IDLE, RUN, JUMP, FALL, DASH, WALL_RUN}
@export var currAnim: int = AnimState.IDLE
var run_val: float = 0.0
var dash_val: float = 0.0
var wallrun_val: float = 0.0
var falling_val: float = 0.0
var target_rotation_y: float = 0.0

# Dash
var is_dashing := false
var dash_velocity: Vector3
const DASH_FORCE = 40
const DASH_DECAY = 200
const DASH_COOLDOWN := 1
var dash_cooldown_timer: float = 2.0

# Wall Run
const WALL_RUN_DURATION = 100 # seconds
const WALL_RUN_GRAVITY = -1.0 # slightly push into wall
var is_wall_running = false
var wall_run_timer = 100.0
var wall_normal = Vector3.ZERO

func _ready() -> void:
	Global.player = self
	Global.emit_signal("player_spawned", self)

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

	print("name: ", name)
	print("id: ", multiplayer.get_unique_id())
	print("auth: ", get_multiplayer_authority())
	print("---")

func _physics_process(delta: float):
	handle_animations(delta)
	if is_multiplayer_authority():
		apply_gravity(delta)
		handle_movement(delta)
		handle_wall_run(delta)
		handle_dash_cooldown(delta)
		detect_wall_run()
		move_and_slide()

func _on_body_entered(body):
	if not is_on_floor() and not is_wall_running:
		if body.is_in_group("walls"): # ← Make sure walls are tagged as "walls"
			var collision = get_last_slide_collision()
			if collision:
				start_wall_run(collision.normal)

func apply_gravity(delta: float):
	if not is_on_floor() and not is_wall_running:
		velocity += PLAYER_GRAVITY * delta

		if velocity.y < -3:
			anim_tree.set(
				"parameters/fire_jump/request",
				AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FADE_OUT
			)
			currAnim = AnimState.FALL


func detect_wall_run():
	if not is_on_floor() and not is_wall_running:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision.get_collider().is_in_group("walls"):
				print("Wall detected:", collision.get_collider().name)
				start_wall_run(collision.get_normal())
				break

func handle_movement(delta: float):
	var input_dir = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	var input_velocity := Vector3(input_dir.x * MOVE_SPEED, 0, input_dir.y * MOVE_SPEED)

	if dash_cooldown_timer > 0:
		dash_cooldown_timer = max(dash_cooldown_timer - delta, 0)

	handle_dash_decay(delta)

	# TODO: this feels like it wants to be distilled down to an `apply_speed_modifiers` function that
	# applies all speed modifiers on the player, not just the dash modifier
	var target_velocity := input_velocity + dash_velocity
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)

 	# Handle player rotation
	var look_direction := Vector3(input_dir.x, 0, input_dir.y)
	if look_direction.length() > 0.1:
		look_direction = look_direction.normalized()
		target_rotation_y = atan2(-look_direction.x, -look_direction.z)
	# lerp_angle for smoothing
	rotation.y = lerp_angle(rotation.y, target_rotation_y, 10.0 * delta)

	if is_on_floor():
		if velocity.is_zero_approx():
			currAnim = AnimState.IDLE
		else:
			currAnim = AnimState.RUN

	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or is_wall_running:
			velocity.y = JUMP_VELOCITY
			fire_jump_animation()

			if is_wall_running:
				stop_wall_run()

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		if not is_dashing:
			is_dashing = true
			dash_cooldown_timer = DASH_COOLDOWN
			dash_velocity = Vector3(input_dir.x, 0, input_dir.y) * DASH_FORCE

func handle_dash_decay(delta: float):
	if not is_dashing:
		return

	var decay_amount := DASH_DECAY * delta
	if dash_velocity.length() > decay_amount:
		dash_velocity -= dash_velocity.normalized() * decay_amount
	else:
		dash_velocity = Vector3.ZERO
		is_dashing = false

func handle_dash_cooldown(delta: float):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

	if dash_bar:
		if DASH_COOLDOWN > 0:
			dash_bar.value = DASH_COOLDOWN - dash_cooldown_timer
		else:
			dash_bar.value = 1.0

func handle_wall_run(delta: float):
	if is_wall_running:
		wall_run_timer -= delta
		velocity.y = WALL_RUN_GRAVITY

		if wall_run_timer <= 0.0 or is_on_floor():
			stop_wall_run()

func start_wall_run(new_wall_normal: Vector3):
	if not is_wall_running:
		is_wall_running = true
		currAnim = AnimState.WALL_RUN
		wall_run_timer = WALL_RUN_DURATION
		wall_normal = new_wall_normal
		velocity.y = 0 # Cancel downward fall instantly

func stop_wall_run():
	is_wall_running = false
	wall_normal = Vector3.ZERO

func handle_animations(delta: float):
	var run_target := 0.0
	var dash_target := 0.0
	var wallrun_target := 0.0
	var fall_target := 0.0

	match currAnim:
		AnimState.IDLE:
			run_target = 0.0
		AnimState.RUN:
			run_target = 1.0
		AnimState.DASH:
			dash_target = 1.0
		AnimState.WALL_RUN:
			wallrun_target = 1.0
		AnimState.FALL:
			fall_target = 1.0

	# Smooth blending
	run_val = lerpf(run_val, run_target, delta * BLEND_SPEED)
	dash_val = lerpf(dash_val, dash_target, delta * BLEND_SPEED)
	wallrun_val = lerpf(wallrun_val, wallrun_target, delta * BLEND_SPEED)

	# We want transitions to falling animation to be smoother
	var falling_mod = 0.2
	falling_val = lerpf(falling_val, fall_target, delta * (BLEND_SPEED * falling_mod))

	update_animation_blend_values()

func fire_jump_animation():
	currAnim = AnimState.JUMP
	# TODO: Eventually replace this system with FSM
	anim_tree.set(
		"parameters/fire_jump/request",
		AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FIRE
	)

func update_animation_blend_values():
	anim_tree.set("parameters/to_run/blend_amount", run_val)
	anim_tree.set("parameters/to_dash/blend_amount", dash_val)
	anim_tree.set("parameters/to_wallrun/blend_amount", wallrun_val)
	anim_tree.set("parameters/to_falling/blend_amount", falling_val)
