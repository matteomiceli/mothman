extends Node

signal player_spawned()
signal countdown_finished()
var player: Node3D = null

enum MODE {MULTIPLAYER, SINGLEPLAYER, NULL}
var game_mode: MODE = MODE.NULL

var APP_ID := 480 # Spacewar, dev app id
var OWNED := false
var ONLINE := false
var STEAM_ID := 0
var STEAM_NAME := ""
var LOBBY_ID := 0
var LOBBY_MEMBERS := []
var LOBBY_INVITE_ARG := false
var MAX_LOBBY_PLAYERS := 8

func _init() -> void:
	OS.set_environment("SteamAppId", str(APP_ID))
	OS.set_environment("SteamGameId", str(APP_ID))

func _ready() -> void:
	var init: Dictionary = Steam.steamInitEx(APP_ID)
	if init['status'] != 0:
		print("Failed to instantiate Steam: %s. Shutting down..." % init['verbal'])
		get_tree().quit()
		
	if not Steam.isSubscribed():
		print("Person does not own this game.")
		get_tree().quit()
	
	ONLINE = Steam.loggedOn()
	STEAM_ID = Steam.getSteamID()
	STEAM_NAME = Steam.getPersonaName()
	print("Steam initialized.\n online: %s, steam_id: %s, steam_name: %s" % [ONLINE, STEAM_ID, STEAM_NAME])

func _process(_delta: float) -> void:
	Steam.run_callbacks()

func print_full_tree() -> void:
	var root := get_tree().root
	_print_tree_recursive(root, 0)

func _print_tree_recursive(node: Node, indent: int) -> void:
	var padding := ""
	for i in range(indent):
		padding += "  "
	print(padding + node.name + " (" + node.get_class() + ")")
	for child in node.get_children():
		_print_tree_recursive(child, indent + 1)
