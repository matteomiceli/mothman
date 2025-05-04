extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if multiplayer.is_server():
		setup_multiplayer()


func setup_multiplayer():
	# Listen for peers connecting and disconnecting
	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(remove_player)

	# Handle already connected peers
	for id in multiplayer.get_peers():
		add_player(id)

	# Add a player on the host system if not a dedicated server
	if not OS.has_feature("dedicated_server"):
		add_player(1)

func add_player(id: int):
	print("ADD", id)
	var player = preload("res://scenes/player.tscn").instantiate()
	player.id = id
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
