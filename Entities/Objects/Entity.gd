# Let op! Alleen implementaties van Entity gebruiken, dit is een basis class om te extenden

@abstract 
class_name GameEntity
extends Node

var health: float:
	get: return health
	set(value): health = value
var damage: float:
	get: return damage
	set(value): damage = value
var entity_type: String
var coordinates: Vector2:
	get: return coordinates
	set(value): coordinates = value

func _init(entity_data: JSON) -> void:
	health = entity_data[entity_type]["health"].to_float()
	damage = entity_data[entity_type]["damage"].to_float()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
