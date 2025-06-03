extends Node

signal members_updated(members: Array)
signal ready_states_updated(ready_states: Dictionary)
signal lobby_created(success: bool, lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_left
signal lobby_list_updated(lobbies: Array)

var lobby_id := 0
var pending_lobby_name := ""

#region state
var _members := []
var members: Array:
	get: return _members
	set(value):
		_members = value
		emit_signal("members_updated", _members)
		if multiplayer.is_server():
			rpc("sync_members", _members)
@rpc("any_peer")
func sync_members(members_: Array) -> void:
	members = members_

var _ready_states := {}
var ready_states: Dictionary:
	get: return _ready_states
	set(value):
		_ready_states = value
		emit_signal("ready_states_updated", _ready_states)
		if multiplayer.is_server():
			rpc("sync_ready_states", _ready_states)
@rpc("any_peer")
func sync_ready_states(ready_states_: Dictionary) -> void:
	ready_states = ready_states_
	
func get_lobby_name() -> String:
	return Steam.getLobbyData(lobby_id, "lobby_name")

func get_host_steam_id() -> int:
	return int(Steam.getLobbyData(lobby_id, "host"))
	
func get_lobby_list() -> void:
	Steam.requestLobbyList()
#endregion

func toggle_ready() -> void:
	var steam_id := Steam.getSteamID()
	if multiplayer.is_server():
		request_toggle_ready(steam_id)
	else:
		rpc_id(1, "request_toggle_ready", steam_id)

@rpc("authority")
func request_toggle_ready(steam_id: int) -> void:
	if multiplayer.is_server():
		var new_states := ready_states.duplicate()
		new_states[steam_id] = !ready_states.get(steam_id, false)
		ready_states = new_states
		
func _ready() -> void:
	Steam.lobby_created.connect(_on_steam_lobby_created)
	Steam.lobby_joined.connect(_on_steam_lobby_joined)
	Steam.lobby_match_list.connect(_on_steam_lobby_match_list)

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
	members = []
	ready_states = {}
	emit_signal("lobby_left")

func set_lobby_members() -> void:
	var new_members := []
	var new_ready_states := {}
	var new_teams := {}
	var new_names := {}
	var count := Steam.getNumLobbyMembers(lobby_id)
	for i in count:
		var steam_id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var steam_name := Steam.getFriendPersonaName(steam_id)
		new_members.append({ "steam_id": steam_id, "steam_name": steam_name })
		new_ready_states[steam_id] = false
		new_teams[steam_id] = 0
		new_names[steam_id] = steam_name
	members = new_members
	ready_states = new_ready_states

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
	var host_id := Steam.getLobbyOwner(lobby_id)
	var my_steam_id := Steam.getSteamID()

	if my_steam_id == host_id:
		# Host can set peer and immediately proceed.
		var result := steam_peer.create_host(0)
		if result != OK:
			push_error("Host failed to create SteamMultiplayerPeer!")
			return
		multiplayer.multiplayer_peer = steam_peer
		NetworkManager.announce_my_id()
		emit_signal("lobby_joined", lobby_id_)
	else:
		multiplayer.connected_to_server.connect(
			func() -> void:
				print("connected")
				NetworkManager.announce_my_id()
				emit_signal("lobby_joined", lobby_id_)
		)
		var result := steam_peer.create_client(host_id, 0)
		if result != OK:
			push_error("Client failed to create SteamMultiplayerPeer!")
			return

		multiplayer.multiplayer_peer = steam_peer  # triggers connection and fires signal when ready


func _on_steam_lobby_created(success: int, lobby_id: int) -> void:
	handle_lobby_created(success, lobby_id)

func _on_steam_lobby_joined(lobby_id: int, _perm: Variant, _locked: bool, _response: Variant) -> void:
	handle_lobby_joined(lobby_id)

func _on_steam_lobby_match_list(lobby_ids: Array) -> void:
	var lobbies := []
	for lobby_id: int in lobby_ids:
		var name := Steam.getLobbyData(lobby_id, "lobby_name")
		var count := Steam.getNumLobbyMembers(lobby_id)
		lobbies.append({"id": lobby_id, "name": name, "count": count})
	emit_signal("lobby_list_updated", lobbies)
