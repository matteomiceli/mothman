extends Node3D

func _on_singleplayer_pressed():
	$Mode.add_child(preload("res://scenes/singleplayer.tscn").instantiate())
	$Menu.hide()


func _on_multiplayer_pressed():
	$Mode.add_child(preload("res://scenes/Multiplayer.tscn").instantiate())
	$Menu.hide()