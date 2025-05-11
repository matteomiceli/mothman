extends Camera3D

var initial_position: Vector3
var players: Array[Node3D] = []

func _ready() -> void:
	initial_position = self.global_position
	Global.connect("player_spawned", Callable(self, "_on_player_spawned"))
	if Global.player != null:
		players.append(Global.player)

func _on_player_spawned(player: Node3D) -> void:
	if not players.has(player):
		players.append(player)

func _physics_process(_delta: float) -> void:
	if players.is_empty():
		return

	var avg_pos: Vector3 = Vector3.ZERO
	for player in players:
		if player != null:
			avg_pos += player.global_position
	avg_pos /= players.size()

	# Calculate max distance between players
	var max_distance := 0.0
	for i in range(players.size()):
		for j in range(i + 1, players.size()):
			var d = players[i].global_position.distance_to(players[j].global_position)
			max_distance = max(max_distance, d)

	# Adjust zoom by moving the camera along its back-facing direction
	var base_offset := Vector3(0.0, 0.0, 15.0)  # Y = height, Z = depth
	var zoom_multiplier: float = clamp(max_distance * 1.2, 5.0, 25.0)
	var offset: Vector3 = base_offset + Vector3(0.0, 0.0, zoom_multiplier)

	# Rotate the offset to match the isometric angle
	var rotated_offset := global_transform.basis * offset

	# Move camera to new position
	var desired_pos := avg_pos + rotated_offset
	global_position = global_position.lerp(desired_pos, 0.1)
