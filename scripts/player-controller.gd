extends CharacterBody3D

@export var currAnim: int = AnimState.IDLE
@export var footstep_sounds: Array[AudioStream] = []

@onready var anim_tree := $PlayerModel/AnimationTree
@onready var dash_bar := get_tree().get_root().get_node("Game/Mode/Singleplayer/World/DashCooldownLayer/DashCooldownBar")
@onready var hoody_mesh: MeshInstance3D = $PlayerModel/Armature/Skeleton3D/Hoody
@onready var skeleton: Skeleton3D = $PlayerModel/Armature/Skeleton3D # Adjust path to your skeleton
const RIGHT_ARM_BONE := "mixamorig10_RightArm"

@onready var input_synchronizer := $Sync/InputSynchronizer

@export var device_index: int = 0

# Audio
const FOOTSTEP_INTERVAL := 0.35 # seconds between steps
var footstep_timer := 0.0

# Customization
@export var hoody_color: Color = Color.YELLOW

# Player
const MOVE_SPEED := 6
const ACCELERATION := 90
const JUMP_VELOCITY := 8
const PLAYER_GRAVITY := Vector3(0, -20, 0)
var target_rotation_y := 0.0

# Animations
const BLEND_SPEED := 15
enum AnimState {IDLE, RUN, JUMP, FALL, DASH, WALL_RUN, CROUCH, HANGING}
var crouch_val := 0.0
var run_val := 0.0
var dash_val := 0.0
var wallrun_val := 0.0
var falling_val := 0.0

# Crouch
const CROUCH_SPEED_MULTIPLIER := 0.5
var is_crouching := false

# Dash
const DASH_FORCE := 40
const DASH_DECAY := 200
const DASH_COOLDOWN := 1
var is_dashing := false
var dash_velocity := Vector3.ZERO
var dash_cooldown_timer := 0.0

# Wall Run
const WALL_RUN_DURATION := 0.8 # seconds
const WALL_RUN_GRAVITY := -7
var is_wall_running := false
var wall_run_timer := 0.8
var wall_normal := Vector3.ZERO
var can_wall_run := true
var can_wall_jump := true
var last_wall_id := 0

# Swing
const FIXED_SWING_RADIUS := 2.0
const SWING_ACCEL := 2.5
var is_swinging := false
var swing_anchor: Node3D = null
var swing_angle := 0.0
var swing_speed := 0.0
var swing_radius := 1112.0
var swing_plane_normal := Vector3.ZERO
var swing_binormal := Vector3.ZERO
var swing_base_vector := Vector3.ZERO
var swing_offset_from_anchor := Vector3.ZERO
var snap_start_pos: Vector3
var snap_target_pos: Vector3
var snap_time := 0.0
var snap_duration := 0.15
var is_snapping := false
var hanging_val := 0.0

func _enter_tree() -> void:
	print("name:", name, " id:", multiplayer.get_unique_id(), " auth:", get_multiplayer_authority())

func _ready() -> void:
	Global.player = self
	Global.emit_signal("player_spawned", self)
	apply_character_customization()
	input_synchronizer.set_multiplayer_authority(name.to_int())
	add_to_group("players")

func _physics_process(delta: float) -> void:
	handle_animations(delta)

	if not multiplayer.is_server(): return

	handle_inputs()
	handle_dash_cooldown(delta)
	if is_snapping:
		handle_snap(delta)
	elif is_swinging:
		handle_swing(delta)
	else:
		apply_gravity(delta)
		handle_movement(delta)
		handle_dash_decay(delta)
		detect_wall_run()
		handle_wall_run(delta)
		handle_footsteps(delta)
		move_and_slide()

func handle_snap(delta: float) -> void:
	snap_time += delta
	var t: float = clamp(snap_time / snap_duration, 0.0, 1.0)
	global_position = snap_start_pos.lerp(snap_target_pos, t)
	if t >= 1.0:
		is_snapping = false

func handle_inputs() -> void:
	if input_synchronizer.jump_pressed:
		try_jump()
		input_synchronizer.jump_pressed = false

	if input_synchronizer.dash_pressed:
		if dash_cooldown_timer <= 0.0:
			start_dash()
		input_synchronizer.dash_pressed = false

	if input_synchronizer.grab_pressed:
		if not is_swinging and swing_anchor:
			start_swing()
		input_synchronizer.grab_pressed = false

	if input_synchronizer.grab_released:
		if is_swinging:
			release_swing()
		input_synchronizer.grab_released = false

	if input_synchronizer.crouch_pressed:
		currAnim = AnimState.CROUCH
		input_synchronizer.crouch_pressed = false

	if input_synchronizer.tag_pressed:
		var target := get_closest_other_character()
		if target and skeleton:
			point_right_arm_at.rpc(target.global_position)
		else:
			reset_right_arm.rpc()
		input_synchronizer.tag_pressed = false
	elif input_synchronizer.tag_released:
		reset_right_arm.rpc()
		input_synchronizer.tag_released = false
	else:
		reset_right_arm.rpc()

func try_jump() -> void:
	if is_on_floor():
		can_wall_jump = true
		velocity.y = JUMP_VELOCITY
		fire_jump_animation.rpc()
	elif is_wall_running and can_wall_jump:
		can_wall_jump = false
		stop_wall_run()
		velocity = (Vector3.UP + wall_normal * 0.5).normalized() * JUMP_VELOCITY
		fire_jump_animation.rpc()

func start_dash() -> void:
	is_dashing = true
	dash_cooldown_timer = DASH_COOLDOWN
	dash_velocity = Vector3(input_synchronizer.input_dir.x, 0, input_synchronizer.input_dir.y) * DASH_FORCE
	input_synchronizer.dash_pressed = false

func handle_dash_decay(delta: float) -> void:
	if is_dashing:
		var decay := DASH_DECAY * delta
		if dash_velocity.length() > decay:
			dash_velocity -= dash_velocity.normalized() * decay
		else:
			dash_velocity = Vector3.ZERO
			is_dashing = false

func handle_dash_cooldown(delta: float) -> void:
	dash_cooldown_timer = max(dash_cooldown_timer - delta, 0)
	if dash_bar:
		dash_bar.value = DASH_COOLDOWN - dash_cooldown_timer

func handle_footsteps(delta: float) -> void:
	if (is_on_floor() or is_wall_running) and velocity.length() > 1.0:
		footstep_timer -= delta
		if footstep_timer <= 0:
			play_footstep()
			footstep_timer = FOOTSTEP_INTERVAL
	else:
		footstep_timer = 0.0

func detect_wall_run() -> void:
	if is_on_floor(): return
	if is_on_wall() and is_wall_running: return
	if is_on_wall() and not is_wall_running:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			if col.get_collider().is_in_group("walls") and sign(velocity.y) != -1:
				start_wall_run(col.get_normal())
				if col.get_collider().get_instance_id() != last_wall_id:
					can_wall_jump = true
				last_wall_id = col.get_collider().get_instance_id()
				break
	else:
		stop_wall_run()

func start_wall_run(normal: Vector3) -> void:
	if not can_wall_run:
		return
	is_wall_running = true
	fire_wallrun_animation.rpc()
	wall_run_timer = WALL_RUN_DURATION
	wall_normal = normal

func stop_wall_run() -> void:
	is_wall_running = false
	wall_normal = Vector3.ZERO
	anim_tree.set("parameters/fire_wallrun/request", AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FADE_OUT)


func handle_wall_run(delta: float) -> void:
	if is_wall_running:
		wall_run_timer -= delta
		velocity.y += WALL_RUN_GRAVITY * delta
		if wall_run_timer <= 0.0 or is_on_floor():
			stop_wall_run()

func apply_gravity(delta: float) -> void:
	if not is_on_floor() and not is_wall_running:
		velocity += PLAYER_GRAVITY * delta
		if velocity.y < -3:
			currAnim = AnimState.FALL
			anim_tree.set("parameters/fire_jump/request", AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FADE_OUT)

func handle_movement(delta: float) -> void:
	var input_dir: Vector2 = input_synchronizer.input_dir
	var speed := MOVE_SPEED * (CROUCH_SPEED_MULTIPLIER if is_crouching else 1.0)
	var input_velocity := Vector3(input_dir.x, 0, input_dir.y) * speed
	var target_velocity := input_velocity + dash_velocity
	velocity.x = move_toward(velocity.x, target_velocity.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, ACCELERATION * delta)
	if input_dir.length() > 0.1:
		target_rotation_y = atan2(-input_dir.x, -input_dir.y)
		rotation.y = lerp_angle(rotation.y, target_rotation_y, 10.0 * delta)
	if is_on_floor():
		currAnim = AnimState.IDLE if velocity.is_zero_approx() else AnimState.RUN
		if not can_wall_run:
			can_wall_run = true
			can_wall_jump = true

func start_swing() -> void:
	is_swinging = true
	currAnim = AnimState.HANGING
	var offset := global_position - swing_anchor.global_position
	var bar_axis := Vector3(1, 0, 0)
	var x_offset := bar_axis * offset.dot(bar_axis)
	var radial := (offset - x_offset).normalized() * FIXED_SWING_RADIUS
	var snapped_offset := x_offset + radial
	swing_offset_from_anchor = snapped_offset
	swing_radius = FIXED_SWING_RADIUS
	swing_base_vector = swing_offset_from_anchor.normalized()
	swing_plane_normal = bar_axis
	swing_binormal = swing_plane_normal.cross(swing_base_vector).normalized()
	var swing_forward := swing_binormal.normalized()
	swing_angle = 0.0
	swing_speed = velocity.dot(swing_forward) / swing_radius
	snap_start_pos = global_position
	snap_target_pos = swing_anchor.global_position + snapped_offset
	snap_time = 0.0
	is_snapping = true

func handle_swing(delta: float) -> void:
	var torque := -SWING_ACCEL * sin(swing_angle)
	swing_speed += torque * delta
	swing_speed *= 0.995
	swing_angle += swing_speed * delta
	var rotated := swing_base_vector.rotated(swing_plane_normal, swing_angle)
	global_position = swing_anchor.global_position + rotated * swing_radius
	rotation.x = 0
	rotation.z = 0
	currAnim = AnimState.HANGING

func release_swing() -> void:
	if swing_anchor == null:
		return
	is_swinging = false
	var radial := (global_position - swing_anchor.global_position).normalized()
	var tangent := swing_plane_normal.cross(radial).normalized()
	velocity = tangent * swing_speed * swing_radius + Vector3.UP * 2.0
	swing_anchor = null
	rotation.x = 0
	rotation.z = 0
	if velocity.length() > 0.1:
		rotation.y = atan2(-velocity.x, -velocity.z)

func set_swing_anchor(anchor: Node3D) -> void:
	swing_anchor = anchor

func apply_character_customization() -> void:
	hoody_mesh.get_active_material(0).albedo_color = hoody_color

func handle_animations(delta: float) -> void:
	var crouch_t := 0.0
	var hanging_t := 0.0
	var run_t := 0.0
	var dash_t := 0.0
	var wall_t := 0.0
	var fall_t := 0.0
	match currAnim:
		AnimState.CROUCH: crouch_t = 1.0
		AnimState.HANGING: hanging_t = 1.0
		AnimState.RUN: run_t = 1.0
		AnimState.DASH: dash_t = 1.0
		AnimState.WALL_RUN: wall_t = 1.0
		AnimState.FALL: fall_t = 1.0
	hanging_val = lerpf(hanging_val, hanging_t, delta * BLEND_SPEED)
	crouch_val = lerpf(crouch_val, crouch_t, delta * BLEND_SPEED)
	run_val = lerpf(run_val, run_t, delta * BLEND_SPEED)
	dash_val = lerpf(dash_val, dash_t, delta * BLEND_SPEED)
	wallrun_val = lerpf(wallrun_val, wall_t, delta * BLEND_SPEED)
	falling_val = lerpf(falling_val, fall_t, delta * BLEND_SPEED * 0.2)
	update_animation_blend_values()

@rpc("call_local")
func fire_jump_animation() -> void:
	currAnim = AnimState.JUMP
	anim_tree.set("parameters/fire_jump/request", AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FIRE)

@rpc("call_local")
func fire_wallrun_animation() -> void:
	currAnim = AnimState.WALL_RUN
	anim_tree.set("parameters/fire_wallrun/request", AnimationNodeOneShot.OneShotRequest.ONE_SHOT_REQUEST_FIRE)


func update_animation_blend_values() -> void:
	anim_tree.set("parameters/to_crouch/blend_amount", crouch_val)
	anim_tree.set("parameters/to_hanging/blend_amount", hanging_val)
	anim_tree.set("parameters/to_run/blend_amount", run_val)
	anim_tree.set("parameters/to_dash/blend_amount", dash_val)
	anim_tree.set("parameters/to_wallrun/blend_amount", wallrun_val)
	anim_tree.set("parameters/to_falling/blend_amount", falling_val)

func get_closest_other_character() -> CharacterBody3D:
	var closest: CharacterBody3D = null
	var closest_dist := INF
	for player in get_tree().get_nodes_in_group("players"): # Add all CharacterBody3D to 'players' group
		if player == self:
			continue
		var dist := global_position.distance_to(player.global_position)
		if dist < closest_dist:
			closest = player
			closest_dist = dist
	return closest

@rpc("call_local")
func point_right_arm_at(target_pos: Vector3) -> void:
	var bone_idx := skeleton.find_bone(RIGHT_ARM_BONE)
	if bone_idx == -1:
		return
	var arm_pos := skeleton.global_transform.origin
	var to_target := (target_pos - arm_pos).normalized()
	var arm_basis := skeleton.global_transform.basis

	# Calculate the rotation to point along to_target, relative to arm's local space
	var bone_transform := skeleton.get_bone_global_pose(bone_idx)
	bone_transform = bone_transform.looking_at(target_pos, Vector3.UP)
	skeleton.set_bone_global_pose_override(bone_idx, bone_transform, 1.0, true)

@rpc("call_local")
func reset_right_arm() -> void:
	var bone_idx := skeleton.find_bone(RIGHT_ARM_BONE)
	if bone_idx == -1:
		return
	skeleton.set_bone_global_pose_override(bone_idx, Transform3D(), 0.0, true)

func play_footstep() -> void:
	if footstep_sounds.size() > 0:
		var sound := footstep_sounds[randi() % footstep_sounds.size()]
		$FootstepPlayer.stream = sound
		$FootstepPlayer.play()

func _process(_delta: float) -> void:
	if is_swinging and swing_anchor:
		DebugDraw3D.draw_line(swing_anchor.global_position, swing_anchor.global_position + swing_binormal * 2.0, Color.RED)
		DebugDraw3D.draw_line(swing_anchor.global_position, swing_anchor.global_position + swing_plane_normal * 2.0, Color.BLUE)

func print_full_tree() -> void:
	var root := get_tree().root
	_print_tree_recursive(root, 0)

func _print_tree_recursive(node: Node, indent: int) -> void:
	var padding := ""
	for i in range(indent):
		padding += "  "
	print(padding + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree_recursive(child, indent + 1)
