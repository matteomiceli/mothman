extends Area3D

func _on_body_entered(body: Node) -> void:
	if body is CharacterBody3D:
		body.set_swing_anchor(self.get_node("Anchor"))
