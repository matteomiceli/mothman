extends Node3D

@onready var player_spawner := $PlayersSpawn
var Player := preload("res://scenes/player.tscn")

func _ready() -> void:
	if Global.game_mode == Global.MODE.SINGLEPLAYER:
		add_player(1)
	elif Global.game_mode == Global.MODE.STEAM_MULTIPLAYER:
		for active_player: Dictionary in Global.ACTIVE_PLAYERS:
			var id: int = active_player.get("id", 0)
			var color: Color = active_player.get("color", Color(1,1,1))  # optional if you store color
			add_player(id, color)

func add_player(id: int, color: Color = Color(1,1,1)) -> void:
	var player := Player.instantiate()
	player.name = str(id)
	player.hoody_color = color
	player.set_multiplayer_authority(id)

	player.position.x = len(multiplayer.get_peers())  # Simple offset, can be improved
	player_spawner.add_child(player, true)

func remove_player(id: int) -> void:
	print("remove", id)
	if player_spawner.has_node(str(id)):
		player_spawner.get_node(str(id)).queue_free()
