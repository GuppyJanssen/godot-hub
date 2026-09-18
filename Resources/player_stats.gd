extends Resource
class_name PlayerStats

@export var health: int = 100
@export var speed: float = 300.0
@export var acceleration: float = 1200.0
@export var friction: float = 100.0
@export var rotation_speed: float = 10.0

# NIEUW: Dit bewaart de live HP die tijdens het spelen verandert (en die we gaan opslaan!)
var current_health: int = 100 
var current_speed: float = 300.0
var current_acceleration: float = 1200.0
var current_friction: float = 100.0
var current_rotation_speed: float = 10.0
