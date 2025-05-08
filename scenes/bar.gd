extends Area3D

func _on_body_entered(body):
	if body is CharacterBody3D:
		print(body)
		body.set_swing_anchor(self.get_node("Anchor"))
		
func _on_body_exited(body):
	var player = body as Node  # or a stricter cast if needed
	if "is_swinging" in player and not player.is_swinging:
		player.set_swing_anchor(null)
