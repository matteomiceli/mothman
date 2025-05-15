extends Node3D

@onready var player_spawner = $PlayersSpawn

var Player = preload("res://scenes/player.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.game_mode == Global.MODE.SINGLEPLAYER:
		pass
		add_player(1)

func add_player(id: int, color: Color = Color(1, 1, 1)):
	var player = Player.instantiate()
	player.name = str(id)
	player.hoody_color = color
	print("INSIDE ADD PLAYER")

	if len(multiplayer.get_peers()) > 0:
		# TODO - This positioning doesn't work yet - this forum thread might help
		# https://forum.godotengine.org/t/setting-position-on-spawn-in-multiplayer-causes-client-to-spawn-at-0-0-0/78584/7
		pass
		#player.position.x += 10
	player_spawner.add_child(player, true)

func remove_player(id: int):
	print("remove", id)
	if player_spawner.has_node(str(id)):
		player_spawner.get_node(str(id)).queue_free()
