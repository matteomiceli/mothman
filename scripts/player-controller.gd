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
const WALL_RUN_DURATION = 0.8 # seconds
const WALL_RUN_GRAVITY = -5
var is_wall_running = false
var wall_run_timer = 0.8
var wall_normal = Vector3.ZERO
# Vars to enforce wall jump and wall run once
var can_wall_run = true
var can_wall_jump = true

# Bar Swing
var is_swinging: bool = false
var swing_anchor: Node3D = null
var swing_angle: float = 0.0
var swing_speed: float = 0.0
var swing_radius: float = 2.0
var swing_plane_normal: Vector3
var swing_binormal: Vector3
const SWING_GRAVITY = -10.0
const SWING_ACCEL = 2.5

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
		handle_swing_input()
		if not is_swinging:
			apply_gravity(delta)
			handle_movement(delta)
			handle_wall_run(delta)
			handle_dash_cooldown(delta)
			detect_wall_run()
			move_and_slide()
		else:
			handle_swing(delta)
			
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
	if is_on_floor():
		return

	if is_on_wall() and not is_wall_running:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision.get_collider().is_in_group("walls"):
				start_wall_run(collision.get_normal())
				break
	else:
		stop_wall_run()

func handle_movement(delta: float):
	if is_swinging:
		return

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
		if not can_wall_run:
			can_wall_run = true
			can_wall_jump = true

		# Animation
		if velocity.is_zero_approx():
			currAnim = AnimState.IDLE
		else:
			currAnim = AnimState.RUN

	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or is_wall_running:
			velocity.y = JUMP_VELOCITY
			fire_jump_animation.rpc()

			if is_wall_running:
				can_wall_jump = false
				stop_wall_run()

	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0:
		if not is_dashing:
			is_dashing = true
			dash_cooldown_timer = DASH_COOLDOWN
			dash_velocity = Vector3(input_dir.x, 0, input_dir.y) * DASH_FORCE

func handle_swing_input():
	if Input.is_action_just_pressed("grab") and not is_swinging and swing_anchor:
		start_swing()
	elif Input.is_action_just_released("grab") and is_swinging:
		swing_anchor = null
		release_swing()

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
		velocity.y += WALL_RUN_GRAVITY * delta

		if wall_run_timer <= 0.0 or is_on_floor():
			stop_wall_run()

func start_wall_run(new_wall_normal: Vector3):
	if not is_wall_running:
		is_wall_running = true
		currAnim = AnimState.WALL_RUN
		wall_run_timer = WALL_RUN_DURATION
		wall_normal = new_wall_normal

func stop_wall_run():
	is_wall_running = false
	wall_normal = Vector3.ZERO

func handle_swing(delta: float):
	swing_speed += -sin(swing_angle) * SWING_ACCEL * delta
	swing_speed *= 0.99
	swing_angle += swing_speed * delta

	# New position = rotated offset in dynamic swing plane
	var local_offset = cos(swing_angle) * (global_position - swing_anchor.global_position).normalized() * swing_radius \
					 + sin(swing_angle) * swing_binormal * swing_radius

	global_position = swing_anchor.global_position + local_offset

	look_at(swing_anchor.global_position, Vector3.UP)
	rotate_y(PI)

func set_swing_anchor(anchor: Node3D):
	swing_anchor = anchor

func start_swing():
	print("Swing anchor:", swing_anchor)

	is_swinging = true
	currAnim = AnimState.IDLE  # Or use AnimState.SWING if defined

	# Step 1: define swing frame
	var anchor_to_player = (global_position - swing_anchor.global_position).normalized()
	swing_plane_normal = anchor_to_player.cross(velocity).normalized()
	swing_binormal = swing_plane_normal.cross(anchor_to_player).normalized()
	swing_radius = (global_position - swing_anchor.global_position).length()

	# Step 2: convert velocity to angular speed
	# We'll treat swing_angle as a scalar for rotation progress, not a global angle
	var tangential_dir = swing_binormal  # direction player moves around the anchor
	swing_speed = velocity.dot(tangential_dir) / swing_radius
	swing_angle = 0.0  # starting at current position

func release_swing():
	is_swinging = false
	
	var release_velocity = swing_binormal * swing_speed * swing_radius
	velocity = release_velocity

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

@rpc("call_local")
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

func _process(delta):
	if is_swinging:
		DebugDraw3D.draw_line(swing_anchor.global_position, swing_anchor.global_position + swing_binormal * 2.0, Color.RED)
		DebugDraw3D.draw_line(swing_anchor.global_position, swing_anchor.global_position + swing_plane_normal * 2.0, Color.BLUE)
