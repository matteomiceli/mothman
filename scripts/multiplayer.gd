extends Node

@onready var player_color_picker = $ServerMenu/ItemList/PlayerColorPicker
@onready var world = $World

const PORT = 4433

var players = {}

func _ready() -> void:
	# Pause game
	get_tree().paused = true

	start_server()
	register_listeners()
	#Global.countdown_finished.connect(_on_countdown_finished)

func start_server():
	multiplayer.server_relay = false

	# Start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server.")
		_on_host_pressed.call_deferred()

func register_listeners():
	if not multiplayer.is_server(): return

	#multiplayer.peer_connected.connect(_on_player_connect)
	multiplayer.peer_disconnected.connect(world.remove_player)

@rpc("any_peer")
func register_player(id: int, color: Color):
	if not multiplayer.is_server(): return
	players[id] = color
	add_player(id)


@rpc("authority", "call_local")
func add_player(id):
	if is_multiplayer_authority():
		var player_color = players.get(id, player_color_picker.color)
		world.add_player(id, player_color)

func _on_host_pressed():
	# Start host
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer

	# Register server player
	players[1] = player_color_picker.color
	# Add server host player
	add_player(1)
	start_game()

func _on_client_pressed():
	# Start client
	var ip_input = $ServerMenu/ItemList/ip.text
	if ip_input == "":
		# UNDO THIS
		ip_input = "127.0.0.1"
		# OS.alert("Please enter a server IP to connect to.")

	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_input, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to connect to client")
		return
	multiplayer.multiplayer_peer = peer

	multiplayer.connected_to_server.connect(func():
		var my_id = multiplayer.get_unique_id()
		register_player.rpc_id(1, my_id, player_color_picker.color)
	)

	start_game()

#func _on_countdown_finished():
	#start_game()

func start_game():
	$ServerMenu.hide()
	get_tree().paused = false


func _exit_tree() -> void:
	# Cleanup listeners
	if not multiplayer.is_server(): return

	multiplayer.peer_connected.disconnect(add_player.rpc)
	multiplayer.peer_disconnected.disconnect(world.remove_player)
