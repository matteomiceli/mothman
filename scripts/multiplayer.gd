extends Node

@onready var host_color_picker = $ServerMenu/ItemList/HostColorPicker
@onready var client_color_picker = $ServerMenu/ItemList/ClientColorPicker
@onready var world = $World

const PORT = 4433

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

	multiplayer.peer_connected.connect(world.add_player)
	multiplayer.peer_disconnected.connect(world.remove_player)


func _on_host_pressed():
	# Start host
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer

	# Add server host player
	world.add_player(multiplayer.get_unique_id())
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
	start_game()

#func _on_countdown_finished():
	#start_game()

func start_game():
	$ServerMenu.hide()
	get_tree().paused = false


func _exit_tree() -> void:
	# Cleanup listeners
	if not multiplayer.is_server(): return 

	multiplayer.peer_connected.disconnect(world.add_player)
	multiplayer.peer_disconnected.disconnect(world.remove_player)
