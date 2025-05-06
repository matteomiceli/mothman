extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.game_mode == Global.MODE.SINGLEPLAYER:
		add_player(1)

	if multiplayer.is_server():
		setup_multiplayer()


func setup_multiplayer():
	# Listen for peers connecting and disconnecting
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	# Handle already connected peers
	for id in multiplayer.get_peers():
		add_player(id)

func add_player(id: int):
	var player = preload("res://scenes/player.tscn").instantiate()
	player.name = str(id)

	if len(multiplayer.get_peers()) > 0:
		# TODO - This positioning doesn't work yet - this forum thread might help
		# https://forum.godotengine.org/t/setting-position-on-spawn-in-multiplayer-causes-client-to-spawn-at-0-0-0/78584/7
		player.position.x += 10


	$PlayersSpawn.add_child(player, true)


func remove_player(id: int):
	print("remove", id)
	if $PlayersSpawn.has_node(str(id)):
		$PlayersSpawn.get_node(str(id)).queue_free()

func _exit_tree() -> void:
	# Cleanup listeners
	if multiplayer.is_server():
		multiplayer.peer_connected.disconnect(add_player)
		multiplayer.peer_disconnected.disconnect(remove_player)
