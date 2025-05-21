extends Node3D

func _on_singleplayer_pressed() -> void:
	Global.game_mode = Global.MODE.SINGLEPLAYER
	remove_child($Multiplayer)
	$Menu.hide()


func _on_multiplayer_pressed() -> void:
	Global.game_mode = Global.MODE.MULTIPLAYER
	remove_child($Singleplayer)
	$Menu.hide()
