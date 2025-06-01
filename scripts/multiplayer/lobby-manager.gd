extends Node

signal members_updated(members: Array)
signal ready_states_updated(ready_states: Dictionary)
signal lobby_created(success: bool, lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_left

var lobby_id := 0
var members := []
var ready_states := {}
var pending_lobby_name := ""

func create_lobby(status: int, max_players: int, lobby_name: String) -> void:
	pending_lobby_name = lobby_name
	Steam.createLobby(status, max_players)
	
func join_lobby(lobby_id_: int) -> void:
	lobby_id = lobby_id_
	Steam.joinLobby(lobby_id)

func leave_lobby() -> void:
	if lobby_id == 0: return
	Steam.leaveLobby(lobby_id)
	lobby_id = 0
	members.clear()
	ready_states.clear()
	emit_signal("lobby_left")
	emit_signal("ready_states_updated", ready_states)
	emit_signal("members_updated", members)

func set_lobby_members() -> void:
	members.clear()
	ready_states.clear()
	var count := Steam.getNumLobbyMembers(lobby_id)
	for i in count:
		var steam_id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var steam_name := Steam.getFriendPersonaName(steam_id)
		members.append({ "steam_id": steam_id, "steam_name": steam_name })
		ready_states[steam_id] = false
	emit_signal("members_updated", members)
	emit_signal("ready_states_updated", ready_states)

func set_ready_state(steam_id: int, is_ready: bool) -> void:
	ready_states[steam_id] = is_ready
	emit_signal("ready_states_updated", ready_states)

func handle_lobby_data_update(member_id: int) -> void:
	var key := "ready_%s" % member_id
	var ready_val := Steam.getLobbyMemberData(lobby_id, member_id, key)
	ready_states[member_id] = ready_val == "true"
	emit_signal("ready_states_updated", ready_states)

func handle_lobby_created(success: int, lobby_id_: int) -> void:
	if success == 1:
		Global.IS_HOST = true
		lobby_id = lobby_id_
		Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()))
		Steam.setLobbyData(lobby_id, "lobby_name", pending_lobby_name)
		NetworkManager.steam_to_peer[Steam.getSteamID()] = multiplayer.get_unique_id()
	emit_signal("lobby_created", success, lobby_id_)

func handle_lobby_joined(lobby_id_: int) -> void:
	lobby_id = lobby_id_

	var steam_peer := SteamMultiplayerPeer.new()
	var host_id := int(Steam.getLobbyData(lobby_id, "host"))
	var my_steam_id := Steam.getSteamID()

	if my_steam_id == host_id:
		steam_peer.create_host(0)
	else:
		steam_peer.create_client(host_id, 0)

	multiplayer.multiplayer_peer = steam_peer
	print("multiplayer_peer status: ", steam_peer.get_connection_status())
	NetworkManager.announce_my_id()
	emit_signal("lobby_joined", lobby_id_)
