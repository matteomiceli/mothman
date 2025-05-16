extends Node

signal player_spawned(player: Node3D)
signal countdown_finished()
var player: Node3D = null

enum MODE {MULTIPLAYER, SINGLEPLAYER, NULL}
var game_mode: MODE = MODE.NULL

var OWNED = false
var ONLINE = false
var STEAM_ID = 0
var STEAM_NAME = ""
var DATA
var LOBBY_ID = 0
var LOBBY_MEMBERS = []
var LOBBY_INVITE_ARG = false
var MAX_LOBBY_PLAYERS = 8

func _ready():
	var init: Dictionary = Steam.steamInitEx(480)
	if init['status'] != 0:
		print("Failed to instantiate Steam: %s. Shutting down..." % init['verbal'])
		get_tree().quit()
		
	ONLINE = Steam.loggedOn()
	STEAM_ID = Steam.getSteamID()
	STEAM_NAME = Steam.getPersonaName()
	OWNED = Steam.isSubscribed()
	
	if OWNED == false:
		print("Person does not own this game.")
		get_tree().quit()
		
	print("Steam initialized.\n online: %s, steam_id: %s, steam_name: %s" % [ONLINE, STEAM_ID, STEAM_NAME])

func _process(delta):
	Steam.run_callbacks()
