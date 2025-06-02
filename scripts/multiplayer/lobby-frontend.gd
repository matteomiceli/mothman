extends Node2D

enum LobbyStatus { Private, Friends, Public, Invisible }
@onready var lobby_backend: Node = preload("res://scripts/multiplayer/lobby-backend.gd").new()
@onready var chat_manager: Node = preload("res://scripts/multiplayer/chat-manager.gd").new()

@onready var lobby_name_input := $CreateButton/TextEdit
@onready var steam_name_label := $SteamName
@onready var chat_button := $SendButton
@onready var chat_input := $SendButton/TextEdit
@onready var chat_output := $Chat/RichTextLabel
@onready var chat_label := $Chat/Label
@onready var player_list_label := $Players/Label 
@onready var player_list_output := $Players/RichTextLabel
@onready var ready_button := $ReadyButton
@onready var start_button := $StartButton
@onready var leave_button := $LeaveButton
@onready var create_button := $CreateButton
@onready var lobby_list_popup := $Popup
@onready var lobby_list_container := $Popup/Panel/Scroll/VBox

func _ready() -> void:
	add_child(lobby_backend)
	add_child(chat_manager)
	steam_name_label.text = Global.STEAM_NAME

	lobby_backend.set_multiplayer_authority(1)
	lobby_backend.members_updated.connect(_on_members_updated.rpc)
	lobby_backend.ready_states_updated.connect(_on_ready_states_updated.rpc)
	lobby_backend.lobby_created.connect(_on_lobby_created)
	lobby_backend.lobby_joined.connect(_on_lobby_joined)
	lobby_backend.lobby_left.connect(_on_lobby_left)
	lobby_backend.lobby_list_updated.connect(_on_lobby_list_updated)

	chat_manager.message_sent.connect(_on_message_sent)
	chat_manager.message_received.connect(_on_message_received)

	chat_input.editable = false
	chat_button.disabled = true
	leave_button.disabled = true
	ready_button.disabled = true
	create_button.disabled = true

func _on_lobby_list_updated(lobbies: Array) -> void:
	for child in lobby_list_container.get_children():
		child.queue_free()

	for lobby: Dictionary in lobbies:
		var btn := Button.new()
		btn.text = "Lobby %s: %s (%d players)" % [lobby.id, lobby.name, lobby.count]
		btn.pressed.connect(func() -> void:
			lobby_backend.join_lobby(lobby.id)
			lobby_list_popup.hide()
			chat_input.clear()
		)
		lobby_list_container.add_child(btn)


@rpc("call_local")
func _on_members_updated(members: Array) -> void:
	player_list_output.clear()
	player_list_label.text = "Players (%d)" % members.size()
	for member: Dictionary in members:
		player_list_output.append_text("%s\n" % member["steam_name"])

@rpc("call_local")
func _on_ready_states_updated(ready_states: Dictionary) -> void:
	player_list_output.clear()
	var all_ready := true
	var host_id := int(Steam.getLobbyData(lobby_backend.lobby_id, "host"))
	var is_host := (Steam.getSteamID() == host_id)
	
	for member: Dictionary in lobby_backend.members:
		var steam_id: int = member["steam_id"]
		var steam_name: String = member["steam_name"]
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
		leave_button.disabled = false
		ready_button.disabled = false
	else:
		display_message("Failed to create lobby.")

func _on_lobby_joined(lobby_id: int) -> void:
	chat_output.clear()
	var lobby_name: String = lobby_backend.get_lobby_name()
	display_message("Joined lobby %s" % lobby_name)
	lobby_backend.set_lobby_members()
	chat_label.text = lobby_name
	chat_button.disabled = false
	chat_input.editable = true
	chat_input.clear()
	leave_button.disabled = false
	ready_button.disabled = false
	
func _on_lobby_left() -> void:
	chat_button.disabled = true
	chat_input.editable = false
	chat_input.clear()
	chat_output.clear()
	leave_button.disabled = true
	ready_button.disabled = true
	
func _on_message_received(user_id: int, message: String) -> void:
	if lobby_backend.lobby_id != 0:
		var name := Steam.getFriendPersonaName(user_id)
		chat_output.add_text("\n%s: %s" % [name, message])

func _on_message_sent(user_id: int, message: String) -> void:
	_on_message_received(user_id, message)

func display_message(message: String) -> void:
	chat_output.add_text("\n%s" % message)

func _on_text_edit_text_changed() -> void:
	create_button.disabled = lobby_name_input.text.is_empty()

func _on_create_button_pressed() -> void:
	lobby_backend.create_lobby(LobbyStatus.Public, Global.MAX_LOBBY_PLAYERS, lobby_name_input.text)
	lobby_name_input.clear()

func _on_browse_button_pressed() -> void:
	lobby_list_popup.popup()
	lobby_backend.request_lobby_list()

func _on_leave_button_pressed() -> void:
	lobby_backend.leave_lobby()
	chat_label.text = ""

func _on_send_button_pressed() -> void:
	chat_manager.send_message(lobby_backend.lobby_id, chat_input.text)
	chat_input.text = ""

func _on_ready_button_pressed() -> void:
	lobby_backend.set_ready_states()

func _on_close_button_pressed() -> void:
	lobby_list_popup.hide()

func _on_start_button_pressed() -> void:
	# Only host should ever be able to press this, but double-check
	var my_steam_id := Steam.getSteamID()
	var host_steam_id := int(Steam.getLobbyData(lobby_backend.lobby_id, "host"))
	if my_steam_id != host_steam_id:
		return  # Not host, ignore
		
	for member: Dictionary in lobby_backend.members:
		var player_info := {
			"steam_id": member.get("steam_id", 0),
			"steam_name": member.get("steam_name", ""),
			"hoody_color": Color(0,0,0),
			"peer_id": NetworkManager.steam_to_peer[member.get("steam_id")]
		}
		Global.ACTIVE_PLAYERS.append(player_info)

	NetworkManager.rpc("sync_active_players", Global.ACTIVE_PLAYERS)
	
	print("Ready to plunder...")
	get_tree().change_scene_to_file("res://scenes/world.tscn")
