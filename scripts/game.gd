extends Node3D

func _init():
	if Global.game_mode == Global.MODE.STEAM_MULTIPLAYER:
		OS.set_environment("SteamAppId", str(Global.APP_ID))
		OS.set_environment("SteamGameId", str(Global.APP_ID))

func _ready() -> void:
	if Global.game_mode == Global.MODE.STEAM_MULTIPLAYER:
		init_steam()

func _process(_delta: float) -> void:
	if Global.game_mode == Global.MODE.STEAM_MULTIPLAYER:
		Steam.run_callbacks()

func _on_singleplayer_pressed():
	Global.game_mode = Global.MODE.SINGLEPLAYER
	$Mode.add_child(preload("res://scenes/singleplayer.tscn").instantiate())
	$Menu.hide()


func _on_multiplayer_pressed():
	Global.game_mode = Global.MODE.MULTIPLAYER
	$Mode.add_child(preload("res://scenes/multiplayer.tscn").instantiate())
	$Menu.hide()


func init_steam() ->  void:
	var init: Dictionary = Steam.steamInitEx(Global.APP_ID)
	if init['status'] != 0:
		print("Failed to instantiate Steam: %s. Shutting down..." % init['verbal'])
		get_tree().quit()
		
	if not Steam.isSubscribed():
		print("Person does not own this game.")
		get_tree().quit()
	
	Global.ONLINE = Steam.loggedOn()
	Global.STEAM_ID = Steam.getSteamID()
	Global.STEAM_NAME = Steam.getPersonaName()
	print("Steam initialized.\n online: %s, steam_id: %s, steam_name: %s" % [Global.ONLINE, Global.STEAM_ID, Global.STEAM_NAME])
