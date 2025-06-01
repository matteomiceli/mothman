extends Node

@onready var player_color_picker := $ServerMenu/ItemList/PlayerColorPicker
@onready var world := $World

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

	multiplayer.peer_connected.connect(add_player)
	multiplayer.peer_disconnected.connect(world.remove_player)

func add_player(id: int) -> void:
	# This peer's player
	if id == multiplayer.get_unique_id():
		world.add_player(id, player_color_picker.color)
		return
	
	world.add_player(id)

func _on_host_pressed() -> void:
	# Start host
	var peer := ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer

	# Add server host player
	world.add_player(multiplayer.get_unique_id(), player_color_picker.color)
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

#func _on_countdown_finished():
	#start_game()

func start_game() -> void:
	$ServerMenu.hide()
	get_tree().paused = false

func _exit_tree() -> void:
	# Cleanup listeners
	if not multiplayer.is_server(): return 

	multiplayer.peer_connected.disconnect(add_player)
	multiplayer.peer_disconnected.disconnect(world.remove_player)
