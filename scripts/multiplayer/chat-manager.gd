# scripts/chat-manager.gd
extends Node

signal message_sent(user_id: int, message: String)
signal message_received(user_id: int, message: String)

# chat-manager.gd
func send_message(lobby_id: int, message: String) -> void:
	if Steam.sendLobbyChatMsg(lobby_id, message):
		emit_signal("message_sent", Steam.getSteamID(), message)
	else:
		emit_signal("message_sent", Steam.getSteamID(), "[failed to send] " + message)

func receive_message(user_id: int, message: String) -> void:
	print("Received message from", user_id, ":", message)
	emit_signal("message_received", user_id, message)
