extends Camera3D

var initial_position: Vector3

# TODO-MM: When we implement multiplayer, this target should be the average
# position between players currently in play. It should also change z distance
# based on the distance between players
var follow_target := Global.player

func _ready() -> void:
	initial_position = self.position
	follow_target = Global.player

func _physics_process(_delta: float) -> void:
	# TODO-MM: Eventually we'll probably want some custom handling for y tracking
	# as levels grow vertically
	self.position = lerp(initial_position, follow_target.position, .6)
	self.look_at(follow_target.position)
