extends Node

@onready var player_color_picker := $ServerMenu/ItemList/PlayerColorPicker
@onready var player_list_element: Label = $ServerMenu/ItemList/Players
@onready var start_game_btn := $ServerMenu/ItemList/StartGame

@onready var world := $World

var players: Dictionary = {}

const PORT = 4433

func _ready() -> void:
	# Pause game
	get_tree().paused = true

	start_server()
	register_listeners()

	#Global.countdown_finished.connect(_on_countdown_finished)

func start_server() -> void: 
	multiplayer.server_relay = false

	# Start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server.")
		_on_host_pressed.call_deferred()

func register_listeners() -> void:
	if not multiplayer.is_server(): return

	multiplayer.peer_disconnected.connect(world.remove_player)

@rpc("any_peer")
func register_player(id: int, color: Color) -> void:
	if multiplayer.is_server(): 
		players[id] = color
		update_player_list.rpc(players)
		add_player(id)

func add_player(id: int) -> void:
	var player_color: Variant = players.get(id, Color.WHITE)
	world.add_player(id, player_color)

@rpc("call_local")
func update_player_list(players_list: Dictionary) -> void:
	# reset
	player_list_element.text = "Players:\n"

	for player: int in players_list.keys():
		player_list_element.text += "%s\n" % player

func _on_host_pressed() -> void:
	# Start host
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer
	start_game_btn.visible = true

	register_player(1, player_color_picker.color)
	
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

	multiplayer.connected_to_server.connect(func() -> void:
		var my_id: int = multiplayer.get_unique_id()
		register_player.rpc_id(1, my_id, player_color_picker.color)
	)

	start_game.rpc()

#func _on_countdown_finished():
	#start_game()

func _on_start_game_pressed() -> void:
	start_game.rpc()

@rpc("call_local")
func start_game() -> void:
	$ServerMenu.hide()
	get_tree().paused = false

func _exit_tree() -> void:
	# Cleanup listeners
	if not multiplayer.is_server(): return 

	multiplayer.peer_disconnected.disconnect(world.remove_player)
