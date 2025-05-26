extends Area3D

func _on_body_entered(body: CharacterBody3D) -> void:
	body.set_swing_anchor(self.get_node("Anchor"))
