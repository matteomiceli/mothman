extends Node

func _ready() -> void:
	Global.countdown_finished.connect(_on_countdown_finished)
	get_tree().paused = true
	
	# Debug to bypass countdown, remove
	start_game()

func _on_countdown_finished() -> void:
	start_game()

func start_game()-> void:
	get_tree().paused = false
