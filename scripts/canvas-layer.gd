extends CanvasLayer

@onready var countdown_label := $CountdownLabel

var countdown_time := 3
var timer: Timer = null

func _ready() -> void:
	countdown_label.text = str(countdown_time)
	timer = Timer.new()
	timer.wait_time = 1.0
	timer.one_shot = false
	timer.timeout.connect(_on_timer_timeout)
	add_child(timer)
	timer.start()

func _on_timer_timeout() -> void:
	countdown_time -= 1

	if countdown_time > 0:
		countdown_label.text = str(countdown_time)
	else:
		timer.stop()
		hide()
		Global.emit_signal("countdown_finished")
