extends Node

signal player_spawned(player: Node3D)
signal countdown_finished()
var player: Node3D = null

enum MODE {MULTIPLAYER, SINGLEPLAYER, STEAM_MULTIPLAYER, NULL}
var game_mode: MODE = MODE.NULL

var ACTIVE_PLAYERS := []

# Steam
var APP_ID := 480 # Spacewar, dev app id
var OWNED := false
var ONLINE := false
var STEAM_ID := 0
var STEAM_NAME := ""
var LOBBY_ID := 0
var LOBBY_INVITE_ARG := false
var MAX_LOBBY_PLAYERS := 8
var IS_HOST := false

func _ready() -> void:
	print("""
████████╗ █████╗  ███████╗
╚══██╔══╝██╔══██╗██╔═════╝
   ██║   ███████║██║  ███╗
   ██║   ██╔══██║██║   ██║
   ██║   ██║  ██║╚██████╔╝
   ╚═╝   ╚═╝  ╚═╝ ╚═════╝ 
	""")
