extends Node

class_name  Player

var coordinates: Vector2:
	get: return coordinates
	set(value): coordinates = value
	
func _init(starting_coordinates: Vector2) -> void:
	coordinates = starting_coordinates

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
