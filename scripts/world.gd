extends Node3D

var Player := preload("res://scenes/player.tscn")
@onready var player_spawner := $PlayersSpawn
#@onready var player_color_picker = $ServerMenu/ItemList/PlayerColorPicker
const PORT = 4433

func _on_singleplayer_pressed() -> void:
	Global.game_mode = Global.MODE.SINGLEPLAYER
	$MainMenu.hide()
	add_player_internal(1)

func _on_multiplayer_pressed() -> void:
	Global.game_mode = Global.MODE.MULTIPLAYER
	$SteamLobby.show()
	$MainMenu.hide()

#func _ready() -> void:
	# Pause game
	#get_tree().paused = true
#
	#start_server()
	#register_listeners()
	##Global.countdown_finished.connect(_on_countdown_finished)
	#
	#if Global.game_mode == Global.MODE.SINGLEPLAYER:
		#add_player(1)
		#pass
	#else:
		#for player in Global.LOBBY_MEMBERS:
			#add_player(player['steam-id'])

@rpc("any_peer")
func request_spawn() -> void:
	var peer_id := multiplayer.get_remote_sender_id()
	print("Spawning player for peer:", peer_id)
	spawn_player(peer_id)

func spawn_player(peer_id: int) -> void:
	var player := preload("res://scenes/player.tscn").instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	$PlayersSpawn.add_child(player)

func start_server() -> void:
	multiplayer.server_relay = false

	# Start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server.")
		_on_host_pressed.call_deferred()

func register_listeners() -> void:
	if not multiplayer.is_server(): return
	
	multiplayer.peer_connected.connect(add_player.rpc)
	multiplayer.peer_disconnected.connect(remove_player)
	
@rpc("authority", "call_local")
func add_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	add_player_internal(peer_id)

func _on_host_pressed() -> void:
	# Start host
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer

	# Add server host player
	$World.add_player(multiplayer.get_unique_id())
	start_game()
	
func _on_client_pressed() -> void:
	# Start client
	var ip_input: String = $ServerMenu/ItemList/ip.text
	if ip_input == "":
		# UNDO THIS
		ip_input = "127.0.0.1"
		# OS.alert("Please enter a server IP to connect to.")

	var peer := ENetMultiplayerPeer.new()
	peer.create_client(ip_input, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to connect to client")
		return
	multiplayer.multiplayer_peer = peer
	start_game()

#func _on_countdown_finished() -> void: 
	#start_game()

func start_game() -> void:
	$ServerMenu.hide()
	get_tree().paused = false


func _exit_tree() -> void:
	# Cleanup listeners
	if not multiplayer.is_server(): return

	multiplayer.peer_connected.disconnect(add_player.rpc)
	multiplayer.peer_disconnected.disconnect(remove_player)

func add_player_internal(peer_id: int, color: Color = Color.WHITE) -> void:
	var player := Player.instantiate()
	player.name = str(peer_id)
	player.hoody_color = color
	player.set_multiplayer_authority(peer_id)
	player_spawner.add_child(player)

func remove_player(id: int) -> void:
	print("remove", id)
	if player_spawner.has_node(str(id)):
		player_spawner.get_node(str(id)).queue_free()
