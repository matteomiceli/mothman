extends Node

signal player_spawned(player: Node3D)
signal countdown_finished()
var player: Node3D = null

enum MODE {MULTIPLAYER, SINGLEPLAYER, NULL}
var game_mode: MODE = MODE.NULL
