extends Node

signal message_sent(user_id: int, message: String)
signal message_received(user_id: int, message: String)

func send_message(lobby_id: int, message: String) -> void:
	receive_message(Steam.getSteamID(), message)
	rpc("receive_message", Steam.getSteamID(), message)

@rpc("any_peer")
func receive_message(from_steam_id: int, message: String) -> void:
	var steam_name := Steam.getFriendPersonaName(from_steam_id)
	emit_signal("message_received", steam_name, message)
