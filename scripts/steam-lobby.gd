extends Node2D

enum LobbyStatus { Private, Friends, Public, Invisible }
enum SearchDistance { Close, Default, Far, Worldwide }

@onready var steam_name_label = $SteamName
@onready var lobby_name_input = $CreateButton/TextEdit
@onready var chat_input = $SendButton/TextEdit
@onready var lobby_name_label = $Chat/Label
@onready var chat_output = $Chat/RichTextLabel
@onready var player_count_label = $Players/Label
@onready var player_list_output = $Players/RichTextLabel
@onready var lobby_popup = $Popup
@onready var lobby_list_container = $Popup/Panel/Scroll/VBox

func _ready():
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

func create_lobby():
	if Global.LOBBY_ID == 0:
		Steam.createLobby(LobbyStatus.Public, Global.MAX_LOBBY_PLAYERS)

func join_lobby(lobby_id):
	print("Joining lobby:", lobby_id)
	lobby_popup.hide()

	var lobby_name = Steam.getLobbyData(lobby_id, "name")
	display_message("Joining lobby \"%s\"..." % lobby_name)

	Global.LOBBY_MEMBERS.clear()
	Global.LOBBY_ID = lobby_id

	Steam.joinLobby(lobby_id)
	set_lobby_members()

func set_lobby_members():
	Global.LOBBY_MEMBERS.clear()

	var count = Steam.getNumLobbyMembers(Global.LOBBY_ID)
	player_count_label.text = "Players (%d)" % count
	print("Member count:", count)

	for i in count:
		var id = Steam.getLobbyMemberByIndex(Global.LOBBY_ID, i)
		var name = Steam.getFriendPersonaName(id)
		print("Member: %s (%s)" % [name, id])
		Global.LOBBY_MEMBERS.append({ "steam-id": id, "steam-name": name })

	update_player_list()

func update_player_list():
	player_list_output.clear()
	for member in Global.LOBBY_MEMBERS:
		player_list_output.add_text("%s\n" % member["steam-name"])

func send_chat_message():
	var message = chat_input.text
	if message.is_empty():
		return

	if !Steam.sendLobbyChatMsg(Global.LOBBY_ID, message):
		display_message("Failed to send message.")

	chat_input.text = ""

func display_message(message):
	chat_output.add_text("\n%s" % message)

func _on_lobby_created(success, lobby_id):
	if success == 1:
		Global.LOBBY_ID = lobby_id
		var lobby_name = lobby_name_input.text
		display_message("Created Lobby: %s" % lobby_name)
		Steam.setLobbyData(lobby_id, "name", lobby_name)
		lobby_name_label.text = lobby_name
	else:
		display_message("Failed to create lobby.")

func _on_lobby_match_list(lobby_ids):
	for child in lobby_list_container.get_children():
		child.queue_free()

	for lobby_id in lobby_ids:
		var name = Steam.getLobbyData(lobby_id, "name")
		var count = Steam.getNumLobbyMembers(lobby_id)
		
		var btn = Button.new()
		btn.text = "Lobby %s: %s (%d players)" % [lobby_id, name, count]
		btn.size = Vector2(800, 50)
		btn.name = "lobby_%s" % str(lobby_id)
		btn.connect("pressed", Callable(self, "join_lobby").bind(lobby_id))

		lobby_list_container.add_child(btn)

func _on_lobby_joined(lobby_id, _perm, _locked, _response):
	Global.LOBBY_ID = lobby_id
	var name = Steam.getLobbyData(lobby_id, "name")
	lobby_name_label.text = name
	print("Joined lobby:", name)
	set_lobby_members()

func _on_lobby_join_requested(lobby_id, friend_id):
	var friend_name = Steam.getFriendPersonaName(friend_id)
	display_message("%s invited you to a lobby." % friend_name)
	join_lobby(lobby_id)

func _on_lobby_data_update(success, lobby_id, member_id, key):
	print("Lobby data updated | Success: %s | Lobby: %s | Member: %s | Key: %s" % [success, lobby_id, member_id, key])

func _on_lobby_chat_update(_lobby_id, changed_id, _making_change_id, chat_state):
	var name = Steam.getFriendPersonaName(changed_id)

	match chat_state:
		1: display_message("%s joined the lobby." % name)
		2: display_message("%s left the lobby." % name)
		8: display_message("%s was kicked." % name)
		16: display_message("%s was banned." % name)
		_: display_message("Unknown change by %s" % name)

	set_lobby_members()

func _on_lobby_message(_result, user_id, message, _type):
	var name = Steam.getFriendPersonaName(user_id)
	display_message("%s: %s" % [name, message])

func leave_lobby():
	if Global.LOBBY_ID == 0:
		return

	display_message("Leaving lobby...")
	Steam.leaveLobby(Global.LOBBY_ID)
	Global.LOBBY_ID = 0

	lobby_name_label.text = "Lobby"
	player_count_label.text = "Players (0)"
	player_list_output.clear()

	for member in Global.LOBBY_MEMBERS:
		Steam.closeP2PSessionWithUser(member["steam-id"])

	Global.LOBBY_MEMBERS.clear()

# --- UI Events ---

func _on_start_button_pressed():
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_create_button_pressed():
	create_lobby()

func _on_join_button_pressed():
	lobby_popup.popup()
	Steam.addRequestLobbyListDistanceFilter(SearchDistance.Worldwide)
	display_message("Searching for lobbies...")
	Steam.requestLobbyList()

func _on_leave_button_pressed():
	leave_lobby()

func _on_send_button_pressed():
	send_chat_message()

func _on_close_pressed():
	lobby_popup.hide()

# Enables accepting steam invites out of process
func check_command_line():
	for arg in OS.get_cmdline_args():
		if Global.LOBBY_INVITE_ARG:
			join_lobby(int(arg))
		elif arg == "+connect_lobby":
			Global.LOBBY_INVITE_ARG = true
