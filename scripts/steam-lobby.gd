extends Node2D

enum lobby_status {Private, Friends, Public, Invisible}
enum search_distance {Close, Default, Far, Worldwide}

@onready var steamName = $SteamName
@onready var lobbySetName = $CreateButton/TextEdit
@onready var chatInput = $SendButton/TextEdit
@onready var lobbyGetName = $Chat/Label
@onready var lobbyOutput = $Chat/RichTextLabel
@onready var playerCount = $Players/Label
@onready var playerList = $Players/RichTextLabel
@onready var lobbyPopup = $Popup
@onready var lobbyList = $Popup/Panel/Scroll/VBox

func _ready():
	print("Steam overlay enabled: ", Steam.isOverlayEnabled())
	steamName.text = Global.STEAM_NAME
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
		Steam.createLobby(lobby_status.Public, Global.MAX_LOBBY_PLAYERS)

func join_lobby(lobbyId):
	print('join lobby called with lobbyId %s' % lobbyId)
	lobbyPopup.hide()
	var name = Steam.getLobbyData(lobbyId, "name")
	display_message("Joining lobby \"%s\"..." % name)
	
	Global.LOBBY_MEMBERS.clear()
	Global.LOBBY_ID = lobbyId
	
	Steam.joinLobby(lobbyId)
	set_lobby_members()

func set_lobby_members():
	Global.LOBBY_MEMBERS.clear()
	var memberCount = Steam.getNumLobbyMembers(Global.LOBBY_ID)
	playerCount.set_text("Players (%s)" % str(memberCount))
	print('membercount'+str(memberCount))
	for member in range(0, memberCount):
		print('lobid%s'%Global.LOBBY_ID)
		var MEMBER_STEAM_ID = Steam.getLobbyMemberByIndex(Global.LOBBY_ID, member)
		var MEMBER_STEAM_NAME = Steam.getFriendPersonaName(MEMBER_STEAM_ID)
		print("<|%s, %s|>" % [MEMBER_STEAM_ID, MEMBER_STEAM_NAME])
		add_player_list(MEMBER_STEAM_ID, MEMBER_STEAM_NAME) 
	
func add_player_list(steamId, steamName):
	print("add playing %s %s" % [steamId, steamName])
	Global.LOBBY_MEMBERS.append({"steam-id":steamId, "steam-name":steamName})
	playerList.clear()
	for member in Global.LOBBY_MEMBERS:
		playerList.add_text("%s\n" % str(member['steam-name']))

func send_chat_message():
	var message = chatInput.text
	var sent = Steam.sendLobbyChatMsg(Global.LOBBY_ID, message)
	if not sent:
		display_message("ERROR: Chat message failed to send.")
	chatInput.text = ""

func display_message(message):
	lobbyOutput.add_text("\n%s" % str(message))

func _on_lobby_created(connect, lobbyId):
	if (connect == 1):
		Global.LOBBY_ID = lobbyId
		display_message("Created Lobby: %s" % lobbySetName.text)
		print(lobbyId)
		
	Steam.setLobbyData(lobbyId, "name", lobbySetName.text)
	var name = Steam.getLobbyData(lobbyId, "name")
	lobbyGetName.text = str(name)

func _on_lobby_match_list(lobbyIds):
	for lobbyId in lobbyIds:
		var lobbyName = Steam.getLobbyData(lobbyId, "name")
		var lobbyMembers = Steam.getNumLobbyMembers(lobbyId)
		var LOBBY_BUTTON = Button.new()
		LOBBY_BUTTON.set_text("Lobby %s: %s, [%d] Player(s)" % [lobbyId, lobbyName, lobbyMembers])
		LOBBY_BUTTON.set_size(Vector2(800,50))
		LOBBY_BUTTON.set_name("lobby_%s" % str(lobbyId))
		LOBBY_BUTTON.connect("pressed", Callable(self, "join_lobby").bind(lobbyId))
		
		lobbyList.add_child(LOBBY_BUTTON)
		
func _on_lobby_joined(lobbyId, permissions, locked, response):
	Global.LOBBY_ID = lobbyId
	var name = Steam.getLobbyData(lobbyId, "name")
	lobbyGetName.text = str(name)
	print('calling')
	set_lobby_members()

func _on_lobby_join_requested(lobbyId, friendId):
	display_message("Joining %s\'s lobby" % Steam.getFriendPersonaName(friendId))
	join_lobby(lobbyId)

func _on_lobby_data_update(success, lobbyId, memberId, key):
	print("Success: %s, LobbyId: %s, MemberId: %s, Key %s" % [success, lobbyId, memberId, key])

func _on_lobby_chat_update(lobbyId, changedId, makingChangeId, chatState):
	var changer = Steam.getFriendPersonaName(changedId)
	if chatState == 1:
		display_message("%s has joined the lobby" % changer)
	elif chatState == 2:
		display_message("%s has left the lobby" % changer)
	elif chatState == 8:
		display_message("%s has been kicked from the lobby" % changer)
	elif chatState == 16:
		display_message("%s has been banned from the lobby" % changer)
	else:
		display_message("%s did something unknown" % changer)
		
	set_lobby_members()

func _on_lobby_message(result, user, message, type):
	var sender = Steam.getFriendPersonaName(user)
	display_message("%s: %s" % [sender, message])
	
func leave_lobby():
	if Global.LOBBY_ID != 0:
		display_message('Leaving lobby...')
		Steam.leaveLobby(Global.LOBBY_ID)
		Global.LOBBY_ID = 0
		
		lobbyGetName.text = "Lobby"
		playerCount.text = "Players (0)"
		playerList.clear()
		
		for member in Global.LOBBY_MEMBERS:
			Steam.closeP2PSessionWithUser(member['steam-id'])
			
		Global.LOBBY_MEMBERS.clear()
		
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_create_button_pressed() -> void:
	create_lobby()

func _on_join_button_pressed() -> void:
	lobbyPopup.popup()
	Steam.addRequestLobbyListDistanceFilter(search_distance.Worldwide)
	display_message('Searching for lobbies...')
	Steam.requestLobbyList()

func _on_leave_button_pressed() -> void:
	leave_lobby()

func _on_send_button_pressed() -> void:
	send_chat_message()

func _on_close_pressed() -> void:
	lobbyPopup.hide()

# For accepting steam invites out of process
func check_command_line():
	var ARGS = OS.get_cmdline_args()
	if ARGS.size() > 0:
		for arg in ARGS:
			if Global.LOBBY_INVITE_ARG:
				join_lobby(int(arg))
			if arg == "+connect_lobby":
				Global.LOBBY_INVITE_ARG = true
