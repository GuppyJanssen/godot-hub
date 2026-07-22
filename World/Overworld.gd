extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Load player in scene
	print("Loading player in scene")
	var player: Player = Player.new(Vector2(100,100))
	# Place player in scene
	add_child(player)
	# TODO
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
