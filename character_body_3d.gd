extends CharacterBody3D

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")
var speed = 4.0  # movement speed
var jump_speed = 6.0  # determines jump height
var mouse_sensitivity = 0.002  # turning speed


func get_input():
	var input = Input.get_vector("strafe_left", "strafe_right", "move_forward", "move_back")
	if Input.is_action_pressed("dash"):		
		velocity.x = input.x * speed * 2
		velocity.z = input.y * speed * 2
	else:
		velocity.x = input.x * speed
		velocity.z = input.y * speed

func _physics_process(delta):
	velocity.y += -gravity * delta
	get_input()
	move_and_slide()
