# scripts/lobby-manager.gd
extends Node

signal members_updated(members: Array)
signal ready_states_updated(ready_states: Dictionary)
signal lobby_created(success: bool, lobby_id: int)
signal lobby_joined(lobby_id: int)
signal lobby_left

var lobby_id := 0
var members := []
var ready_states := {}

func create_lobby(status: int, max_players: int) -> void:
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
		var id := Steam.getLobbyMemberByIndex(lobby_id, i)
		var name := Steam.getFriendPersonaName(id)
		members.append({ "steam-id": id, "steam-name": name })
		ready_states[id] = false
	emit_signal("members_updated", members)
	emit_signal("ready_states_updated", ready_states)

func set_ready_state(steam_id: int, is_ready: bool) -> void:
	ready_states[steam_id] = is_ready
	emit_signal("ready_states_updated", ready_states)

func update_ready_from_lobby_data(member_id: int) -> void:
	var key := "ready_%s" % member_id
	var ready_val := Steam.getLobbyMemberData(lobby_id, member_id, key)
	ready_states[member_id] = ready_val == "true"
	emit_signal("ready_states_updated", ready_states)

func handle_lobby_created(success: int, lobby_id_: int) -> void:
	if success == 1:
		lobby_id = lobby_id_
		Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()))
	emit_signal("lobby_created", success, lobby_id_)

func handle_lobby_joined(lobby_id_: int) -> void:
	lobby_id = lobby_id_
	emit_signal("lobby_joined", lobby_id_)
