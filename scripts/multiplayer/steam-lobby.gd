extends Node2D

enum LobbyStatus { Private, Friends, Public, Invisible }
enum SearchDistance { Close, Default, Far, Worldwide }

@onready var steam_name_label := $SteamName
@onready var lobby_name_input := $CreateButton/TextEdit
@onready var chat_input := $SendButton/TextEdit
@onready var lobby_name_label := $Chat/Label
@onready var chat_output := $Chat/RichTextLabel
@onready var player_count_label := $Players/Label
@onready var player_list_output := $Players/RichTextLabel
@onready var lobby_popup := $Popup
@onready var lobby_list_container := $Popup/Panel/Scroll/VBox
@onready var start_button := $StartButton

var ready_states := {}

func _ready() -> void:
	print("Steam overlay enabled:", Steam.isOverlayEnabled())
	steam_name_label.text = Global.STEAM_NAME

	Steam.connect("lobby_created", _on_lobby_created)
	Steam.connect("lobby_match_list", _on_lobby_match_list)
	Steam.connect("lobby_joined", _on_lobby_joined)
	Steam.connect("lobby_chat_update", _on_lobby_chat_update)
	Steam.connect("lobby_message", _on_lobby_message)
	Steam.connect("lobby_data_update", _on_lobby_data_update)
	Steam.connect("join_requested", _on_lobby_join_requested)

	check_command_line()
	start_button.disabled = true

func create_lobby() -> void:
	if Global.LOBBY_ID == 0:
		Steam.createLobby(LobbyStatus.Public, Global.MAX_LOBBY_PLAYERS)

func join_lobby(lobby_id: int) -> void:
	print("Joining lobby:", lobby_id)
	lobby_popup.hide()
	var lobby_name := Steam.getLobbyData(lobby_id, "name")
	display_message("Joining lobby \"%s\"..." % lobby_name)
	Global.LOBBY_MEMBERS.clear()
	Global.LOBBY_ID = lobby_id
	Steam.joinLobby(lobby_id)
	set_lobby_members()
	
func set_lobby_members() -> void:
	Global.LOBBY_MEMBERS.clear()
	ready_states.clear()
	var count := Steam.getNumLobbyMembers(Global.LOBBY_ID)
	player_count_label.text = "Players (%d)" % count
	for i in count:
		var id := Steam.getLobbyMemberByIndex(Global.LOBBY_ID, i)
		var name := Steam.getFriendPersonaName(id)
		Global.LOBBY_MEMBERS.append({ "steam-id": id, "steam-name": name })
		if !ready_states.has(id):
			ready_states[id] = false
	update_player_list()

func update_player_list() -> void:
	player_list_output.clear()
	var all_ready := true
	for member: Dictionary in Global.LOBBY_MEMBERS:
		var id: int = member["steam-id"]
		var name: String = member["steam-name"]
		var ready: bool = ready_states.get(id, false)
		if !ready:
			all_ready = false
		var icon: String = "[color=green]✓[/color]" if ready else "[color=red]✗[/color]"
		player_list_output.append_text("%s %s\n" % [icon, name])
	start_button.disabled = !all_ready

func send_chat_message() -> void:
	var message: String = chat_input.text
	if message.is_empty(): return
	if !Steam.sendLobbyChatMsg(Global.LOBBY_ID, message): display_message("Failed to send message.")
	chat_input.text = ""

func display_message(message: String) -> void:
	chat_output.add_text("\n%s" % message)

func _on_lobby_created(success: int, lobby_id: int) -> void:
	if success == 1:
		Global.LOBBY_ID = lobby_id
		var lobby_name: String = lobby_name_input.text
		display_message("Created Lobby: %s" % lobby_name)
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		Steam.setLobbyData(lobby_id, "host", str(Steam.getSteamID()))
		lobby_name_label.text = lobby_name
	else:
		display_message("Failed to create lobby.")

func _on_lobby_match_list(lobby_ids: Variant) -> void:
	for child in lobby_list_container.get_children(): child.queue_free()
	for lobby_id: int in lobby_ids:
		var name := Steam.getLobbyData(lobby_id, "name")
		var count := Steam.getNumLobbyMembers(lobby_id)
		var btn := Button.new()
		btn.text = "Lobby %s: %s (%d players)" % [lobby_id, name, count]
		btn.size = Vector2(800, 50)
		btn.name = "lobby_%s" % str(lobby_id)
		btn.connect("pressed", Callable(self, "join_lobby").bind(lobby_id))
		lobby_list_container.add_child(btn)

func _on_lobby_joined(lobby_id: int, _perm: Variant, _locked: bool, _response: Variant) -> void:
	Global.LOBBY_ID = lobby_id
	lobby_name_label.text = Steam.getLobbyData(lobby_id, "name")
	set_lobby_members()

func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
	display_message("%s invited you to a lobby." % Steam.getFriendPersonaName(friend_id))
	join_lobby(lobby_id)

func _on_lobby_data_update(_success: bool, lobby_id: int, member_id: int) -> void:
	var ready_val := Steam.getLobbyMemberData(lobby_id, member_id, "ready")
	ready_states[member_id] = ready_val == "true"
	update_player_list()

func _on_lobby_chat_update(_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	match chat_state:
		1: display_message("%s joined the lobby." % Steam.getFriendPersonaName(changed_id))
		2: display_message("%s left the lobby." % Steam.getFriendPersonaName(changed_id))
		8: display_message("%s was kicked." % Steam.getFriendPersonaName(changed_id))
		16: display_message("%s was banned." % Steam.getFriendPersonaName(changed_id))
		_: display_message("Unknown change by %s" % Steam.getFriendPersonaName(changed_id))
	set_lobby_members()

func _on_lobby_message(_result: Variant, user_id: int, message: String, _type: String) -> void:
	display_message("%s: %s" % [Steam.getFriendPersonaName(user_id), message])

func leave_lobby() -> void:
	if Global.LOBBY_ID == 0: return
	display_message("Leaving lobby...")
	Steam.leaveLobby(Global.LOBBY_ID)
	Global.LOBBY_ID = 0
	lobby_name_label.text = "Lobby"
	player_count_label.text = "Players (0)"
	player_list_output.clear()
	for member:Dictionary in Global.LOBBY_MEMBERS:
		Steam.closeP2PSessionWithUser(member["steam-id"])
	Global.LOBBY_MEMBERS.clear()
	ready_states.clear()
	start_button.disabled = true

func _on_start_button_pressed() -> void:
	var lobby_host_id: String = Steam.getLobbyData(Global.LOBBY_ID, "host")
	var peer := SteamMultiplayerPeer.new()
	#peer.create_host() if str(multiplayer.get_unique_id()) == lobby_host_id else peer.creawate_client(multiplayer.get_unique_id())
	multiplayer.multiplayer_peer = peer
	Global.ACTIVE_PLAYERS = []
	for member: Dictionary in Global.LOBBY_MEMBERS:
		var id: int = multiplayer.get_unique_id()
		var name: String = member["steam-name"]
		var is_ready: bool = ready_states.get(id, false)
		var is_host := str(id) == lobby_host_id
		Global.IS_HOST = is_host
		Global.ACTIVE_PLAYERS.append({"id": id, "name": name, "ready": is_ready, "is_host": is_host})

	print_debug("ACTIVE_PLAYERS:", Global.ACTIVE_PLAYERS)
	get_tree().change_scene_to_file("res://scenes/world.tscn")

func _on_create_button_pressed() -> void: create_lobby()
func _on_join_button_pressed() -> void:
	lobby_popup.popup()
	Steam.addRequestLobbyListDistanceFilter(SearchDistance.Worldwide)
	display_message("Searching for lobbies...")
	Steam.requestLobbyList()
func _on_leave_button_pressed() -> void: leave_lobby()
func _on_send_button_pressed() -> void: send_chat_message()
func _on_close_button_pressed() -> void: lobby_popup.hide()
func _on_ready_button_pressed() -> void:
	var self_id := Steam.getSteamID()
	var is_ready: bool = !ready_states.get(self_id, false)
	Steam.setLobbyMemberData(Global.LOBBY_ID, "ready", str(is_ready))
	ready_states[self_id] = is_ready
	update_player_list()

func check_command_line() -> void:
	for arg in OS.get_cmdline_args():
		if Global.LOBBY_INVITE_ARG:
			join_lobby(int(arg))
		elif arg == "+connect_lobby":
			Global.LOBBY_INVITE_ARG = true
