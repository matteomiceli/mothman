extends Node

signal player_spawned()
signal countdown_finished()
var player: Node3D = null

enum MODE {MULTIPLAYER, SINGLEPLAYER, STEAM_MULTIPLAYER, NULL}
var game_mode: MODE = MODE.NULL

# Steam
var APP_ID := 480 # Spacewar, dev app id
var OWNED := false
var ONLINE := false
var STEAM_ID := 0
var STEAM_NAME := ""
var LOBBY_ID := 0
var LOBBY_MEMBERS := []
var LOBBY_INVITE_ARG := false
var MAX_LOBBY_PLAYERS := 8

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
