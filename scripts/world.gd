extends Node3D

@onready var player_spawner := $PlayersSpawn
var Player := preload("res://scenes/player.tscn")

func _ready() -> void:
	if Global.game_mode == Global.MODE.SINGLEPLAYER:
		add_player(1, Color(0,0,0))
	elif Global.game_mode == Global.MODE.STEAM_MULTIPLAYER:
		var device_index := 0
		for active_player: Dictionary in Global.ACTIVE_PLAYERS:
			var steam_id: int = active_player.get("steam_id", -1)
			var steam_name: String = active_player.get("steam_name", "")
			var peer_id: int = active_player.get("peer_id", -1)
			var color: Color = active_player.get("color", Color.BLACK)
			device_index += 1
			steam_add_player(steam_id, steam_name, peer_id, color, device_index)

func steam_add_player(steam_id: int, steam_name: String, peer_id: int, color: Color, device_index: int) -> void:
	var player := Player.instantiate()
	player.name = str(peer_id)  # Node name matches peer ID
	player.hoody_color = color
	player.set_multiplayer_authority(peer_id)
	player.get_node("Sync/InputSynchronizer").set_multiplayer_authority(peer_id)  # If you have an input sync child
	player.position.x = len(multiplayer.get_peers())
	player.device_index = device_index
	player_spawner.add_child(player, true)

func add_player(id: int, color: Color = Color.BLACK) -> void:
	var player := Player.instantiate()
	player.name = str(id)
	player.hoody_color = color
	player.position.x = len(multiplayer.get_peers())  # Simple offset, can be improved
	player_spawner.add_child(player, true)

func remove_player(id: int) -> void:
	print("remove", id)
	if player_spawner.has_node(str(id)):
		player_spawner.get_node(str(id)).queue_free()
