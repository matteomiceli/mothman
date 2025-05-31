# scripts/steam-lobby.gd
extends Node2D

enum LobbyStatus { Private, Friends, Public, Invisible }
@onready var lobby_manager: Node = preload("res://scripts/multiplayer/lobby-manager.gd").new()
@onready var chat_manager: Node = preload("res://scripts/multiplayer/chat-manager.gd").new()

@onready var steam_name_label := $SteamName
@onready var chat_button := $SendButton
@onready var chat_input := $SendButton/TextEdit
@onready var chat_output := $Chat/RichTextLabel
@onready var player_list_output := $Players/RichTextLabel
@onready var ready_button := $ReadyButton
@onready var start_button := $StartButton
@onready var lobby_list_popup := $Popup
@onready var lobby_list_container := $Popup/Panel/Scroll/VBox

func _ready() -> void:
	add_child(lobby_manager)
	add_child(chat_manager)
	steam_name_label.text = Global.STEAM_NAME

	# Connect signals from managers to UI
	lobby_manager.members_updated.connect(_on_members_updated)
	lobby_manager.ready_states_updated.connect(_on_ready_states_updated)
	lobby_manager.lobby_created.connect(_on_lobby_created)
	lobby_manager.lobby_joined.connect(_on_lobby_joined)
	lobby_manager.lobby_left.connect(_on_lobby_left)

	chat_manager.message_sent.connect(_on_message_sent)
	chat_manager.message_received.connect(_on_message_received)

	Steam.lobby_created.connect(_steam_lobby_created)
	Steam.lobby_joined.connect(_steam_lobby_joined)
	Steam.lobby_data_update.connect(_steam_lobby_data_update)
	Steam.lobby_message.connect(_steam_lobby_message)
	Steam.lobby_match_list.connect(_steam_lobby_match_list)

	ready_button.pressed.connect(_on_ready_button_pressed)
	
	chat_input.editable = false
	chat_button.disabled = true
	
func _on_members_updated(members: Array) -> void:
	# Update player list UI
	player_list_output.clear()
	for member: Dictionary in members:
		player_list_output.append_text("%s\n" % member["steam-name"])

func _on_ready_states_updated(ready_states: Dictionary) -> void:
	player_list_output.clear()
	var all_ready := true
	var my_id := Steam.getSteamID()
	var host_id := int(Steam.getLobbyData(lobby_manager.lobby_id, "host"))
	var is_host := (my_id == host_id)
	
	for member: Dictionary in lobby_manager.members:
		var steam_id: int = member["steam-id"]
		var steam_name: String = member["steam-name"]
		var ready: bool = ready_states.get(steam_id, false)
		var icon := "[color=green]✓[/color]" if ready else "[color=red]✗[/color]"
		player_list_output.append_text("%s %s\n" % [icon, steam_name])
		if !ready:
			all_ready = false
	
	start_button.disabled = !(all_ready and is_host)

func _on_lobby_created(success: int, lobby_id: int) -> void:
	if success == 1:
		display_message("Lobby created!")
		chat_button.disabled = false
		chat_input.editable = true
		chat_input.clear()
	else:
		display_message("Failed to create lobby.")

func _on_lobby_joined(lobby_id: int) -> void:
	display_message("Joined lobby %d" % lobby_id)
	lobby_manager.set_lobby_members()
	chat_button.disabled = false
	chat_input.editable = true
	chat_input.clear()

func _on_lobby_left() -> void:
	display_message("Left lobby.")
	chat_button.disabled = true
	chat_input.editable = false
	chat_input.clear()
	
func _on_message_received(user_id: int, message: String) -> void:
	if lobby_manager.lobby_id != 0:
		var name := Steam.getFriendPersonaName(user_id)
		chat_output.add_text("\n%s: %s" % [name, message])

func _on_message_sent(user_id: int, message: String) -> void:
	_on_message_received(user_id, message)

func _steam_lobby_created(success: int, lobby_id: int) -> void:
	lobby_manager.handle_lobby_created(success, lobby_id)

func _steam_lobby_joined(lobby_id: int, _perm: Variant, _locked: bool, _response: Variant) -> void:
	lobby_manager.handle_lobby_joined(lobby_id)

func _steam_lobby_data_update(_success: bool, lobby_id: int, member_id: int) -> void:
	lobby_manager.update_ready_from_lobby_data(member_id)

func _steam_lobby_message(_result: Variant, user_id: int, message: String, _type: String) -> void:
	chat_manager.receive_message(user_id, message)

func _steam_lobby_match_list(lobby_ids: Array) -> void:
	for child in lobby_list_container.get_children():
		child.queue_free()

	for lobby_id: int in lobby_ids:
		var name := Steam.getLobbyData(lobby_id, "name")
		var count := Steam.getNumLobbyMembers(lobby_id)
		var btn := Button.new()
		btn.text = "Lobby %s: %s (%d players)" % [lobby_id, name, count]
		btn.pressed.connect(func() -> void:
			lobby_manager.join_lobby(lobby_id)
			lobby_list_popup.hide()
		)
		lobby_list_container.add_child(btn)

func display_message(message: String) -> void:
	chat_output.add_text("\n%s" % message)

func _on_create_button_pressed() -> void:
	lobby_manager.create_lobby(LobbyStatus.Public, Global.MAX_LOBBY_PLAYERS)

func _on_join_button_pressed(lobby_id: int) -> void:
	lobby_manager.join_lobby(lobby_id)

func _on_leave_button_pressed() -> void:
	lobby_manager.leave_lobby()

func _on_send_button_pressed() -> void:
	chat_manager.send_message(lobby_manager.lobby_id, chat_input.text)
	chat_input.text = ""

func _on_ready_button_pressed() -> void:
	var my_id := Steam.getSteamID()
	var is_ready: bool = !(lobby_manager.ready_states.get(my_id, false))
	var key := "ready_%s" % my_id
	Steam.setLobbyMemberData(lobby_manager.lobby_id, key, str(is_ready))
	lobby_manager.set_ready_state(my_id, is_ready)

func _on_start_button_pressed() -> void:
	# Only host should ever be able to press this, but double-check
	var my_id := Steam.getSteamID()
	var host_id := int(Steam.getLobbyData(lobby_manager.lobby_id, "host"))
	if my_id != host_id:
		return  # Not host, ignore
	print("Ready to plunder...")
	get_tree().change_scene_to_file("res://scenes/world.tscn")
