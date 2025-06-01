extends Node

var steam_to_peer := {}

@rpc("any_peer")
func announce_my_id() -> void:
	if not Global.IS_HOST:
		rpc_id(1, "register_peer_id", Steam.getSteamID(), multiplayer.get_unique_id())

@rpc("authority")
func register_peer_id(steam_id: int, peer_id: int) -> void:
	steam_to_peer[steam_id] = peer_id

@rpc("any_peer")
func sync_active_players(active_players: Array) -> void:
	Global.ACTIVE_PLAYERS = active_players
