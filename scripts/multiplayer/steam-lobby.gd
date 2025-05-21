extends Control

enum LobbyStatus {Private, Friends, Public, Invisible}
enum SearchDistance {Close, Default, Far, Worldwide}
@onready var steam_name_label := $SteamName
@onready var lobby_name_input := $CreateButton/TextEdit
@onready var chat_input := $SendButton/TextEdit
@onready var lobby_name_label := $Chat/Label
@onready var chat_output := $Chat/RichTextLabel
@onready var player_count_label := $Players/Label
@onready var player_list_output := $Players/RichTextLabel
@onready var lobby_popup := $Popup
@onready var lobby_list_container := $Popup/Panel/Scroll/VBox

func _ready() -> void:
	print("Steam overlay enabled:", Steam.isOverlayEnabled())
	steam_name_label.text = Global.STEAM_NAME

	# Connect Steam signals
	Steam.connect("lobby_created", Callable(self, "_on_lobby_created"))
	Steam.connect("lobby_match_list", Callable(self, "_on_lobby_match_list"))
	Steam.connect("lobby_joined", Callable(self, "_on_lobby_joined"))
	Steam.connect("lobby_chat_update", Callable(self, "_on_lobby_chat_update"))
	Steam.connect("lobby_message", Callable(self, "_on_lobby_message"))
	Steam.connect("lobby_data_update", Callable(self, "_on_lobby_data_update"))
	Steam.connect("join_requested", Callable(self, "_on_lobby_join_requested"))

	check_command_line()

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

	var count := Steam.getNumLobbyMembers(Global.LOBBY_ID)
	player_count_label.text = "Players (%d)" % count
	print("Member count:", count)

	for i in count:
		var id := Steam.getLobbyMemberByIndex(Global.LOBBY_ID, i)
		var steamName := Steam.getFriendPersonaName(id)
		print("Member: %s (%s)" % [name, id])
		Global.LOBBY_MEMBERS.append({"steam-id": id, "steam-name": steamName})
		await get_tree().create_timer(0.3).timeout
		get_parent().announce_steam_id.rpc_id(1, Steam.getSteamID())
		#if multiplayer.is_server() -> void: 
			#get_parent().announce_steam_id(Steam.getSteamID()) 
		#else:
			#get_parent().announce_steam_id.rpc_id(1, Steam.getSteamID())

	update_player_list()

func update_player_list() -> void:
	player_list_output.clear()
	for member: Dictionary in Global.LOBBY_MEMBERS:
		player_list_output.add_text("%s\n" % member["steam-name"])

func send_chat_message() -> void:
	var message: String = chat_input.text
	if message.is_empty():
		return

	if !Steam.sendLobbyChatMsg(Global.LOBBY_ID, message):
		display_message("Failed to send message.")

	chat_input.text = ""

func display_message(message: String) -> void:
	chat_output.add_text("\n%s" % message)

func _on_lobby_created(success: int, lobby_id: int) -> void:
	if success == 1:
		Global.LOBBY_ID = lobby_id
		var lobby_name: String = lobby_name_input.text
		display_message("Created Lobby: %s" % lobby_name)
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		lobby_name_label.text = lobby_name
		
		get_parent().spawn_player(multiplayer.get_unique_id())
	else:
		display_message("Failed to create lobby.")

func _on_lobby_match_list(lobby_ids: Array[int]) -> void:
	for child in lobby_list_container.get_children():
		child.queue_free()

	for lobby_id: int in lobby_ids:
		var lobbyName := Steam.getLobbyData(lobby_id, "name")
		var count := Steam.getNumLobbyMembers(lobby_id)
		
		var btn := Button.new()
		btn.text = "Lobby %s: %s (%d players)" % [lobby_id, lobbyName, count]
		btn.size = Vector2(800, 50)
		btn.name = "lobby_%s" % str(lobby_id)
		btn.connect("pressed", Callable(self, "join_lobby").bind(lobby_id))

		lobby_list_container.add_child(btn)

func _on_lobby_joined(lobby_id: int, _perm: int, _locked: bool, _response: int) -> void:
	Global.LOBBY_ID = lobby_id
	var name := Steam.getLobbyData(lobby_id, "name")
	lobby_name_label.text = name
	print("Joined lobby:", name)

	await get_tree().create_timer(0.3).timeout # small delay to let multiplayer sync
	get_parent().request_spawn.rpc_id(1) # Ask host to spawn our player node

	set_lobby_members()

func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
	var friend_name := Steam.getFriendPersonaName(friend_id)
	display_message("%s invited you to a lobby." % friend_name)
	join_lobby(lobby_id)

func _on_lobby_data_update(lobby_id: int, member_id: int, success: bool) -> void:
	print("Lobby data updated | Success: %s | Lobby: %d | Member: %d" % [str(success), lobby_id, member_id])

func _on_lobby_chat_update(_lobby_id: int, changed_id: int, _making_change_id: int, chat_state: int) -> void:
	var name := Steam.getFriendPersonaName(changed_id)

	match chat_state:
		1: display_message("%s joined the lobby." % name)
		2: display_message("%s left the lobby." % name)
		8: display_message("%s was kicked." % name)
		16: display_message("%s was banned." % name)
		_: display_message("Unknown change by %s" % name)

	set_lobby_members()

func _on_lobby_message(_result: int, user_id: int, message: String, _type: int) -> void:
	var name := Steam.getFriendPersonaName(user_id)
	display_message("%s: %s" % [name, message])

func leave_lobby() -> void:
	if Global.LOBBY_ID == 0:
		return

	display_message("Leaving lobby...")
	Steam.leaveLobby(Global.LOBBY_ID)
	Global.LOBBY_ID = 0

	lobby_name_label.text = "Lobby"
	player_count_label.text = "Players (0)"
	player_list_output.clear()

	for member: Dictionary in Global.LOBBY_MEMBERS:
		Steam.closeP2PSessionWithUser(member["steam-id"])

	Global.LOBBY_MEMBERS.clear()

func _on_start_button_pressed() -> void:
	if Global.LOBBY_MEMBERS.size() > 0:
		self.hide()
		for member: Dictionary in Global.LOBBY_MEMBERS:
			print(member['steam-id'])
			get_parent().add_player_internal(member['steam-id'])

func _on_create_button_pressed() -> void:
	create_lobby()

func _on_join_button_pressed() -> void:
	lobby_popup.popup()
	Steam.addRequestLobbyListDistanceFilter(SearchDistance.Worldwide)
	display_message("Searching for lobbies...")
	Steam.requestLobbyList()

func _on_leave_button_pressed() -> void:
	leave_lobby()

func _on_send_button_pressed() -> void:
	send_chat_message()

func _on_close_pressed() -> void:
	lobby_popup.hide()

# Enables accepting steam invites out of process
func check_command_line() -> void:
	for arg in OS.get_cmdline_args():
		if Global.LOBBY_INVITE_ARG:
			join_lobby(int(arg))
		elif arg == "+connect_lobby":
			Global.LOBBY_INVITE_ARG = true
