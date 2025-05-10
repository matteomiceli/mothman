extends Node

func _ready() -> void:
	Global.countdown_finished.connect(_on_countdown_finished)

	# Pause game
	get_tree().paused = true

func _on_countdown_finished():
	start_game()

func start_game():
	get_tree().paused = false
