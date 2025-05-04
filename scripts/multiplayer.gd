extends Node

const PORT = 4433

func _ready() -> void:
	# Pause game
	get_tree().paused = true

	multiplayer.server_relay = false

	# Start the server in headless mode.
	if DisplayServer.get_name() == "headless":
		print("Automatically starting dedicated server.")
		_on_host_pressed.call_deferred()

func _on_host_pressed():
	# Start host
	var peer = ENetMultiplayerPeer.new()
	peer.create_server(PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to host game.")
		return
	multiplayer.multiplayer_peer = peer
	start_game()

func _on_client_pressed():
	# Start client
	var ip_input = $ServerMenu/ItemList/ip.text
	if ip_input == "":
		OS.alert("Please enter a server IP to connect to.")

	var peer = ENetMultiplayerPeer.new()
	peer.create_client(ip_input, PORT)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		OS.alert("Failed to connect to client")
		return
	multiplayer.multiplayer_peer = peer
	start_game()

func start_game():
	$ServerMenu.hide()
	get_tree().paused = false
