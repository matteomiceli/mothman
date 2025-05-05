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
	
	# TODO-MM: Eventually we'll probably want some custom handling for y tracking
	# as levels grow vertically
	global_position = lerp(initial_position, avg_pos, .6)
	look_at(avg_pos)
