extends Resource
class_name PlayerStats

@export_category("Gezondheid & Energie")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_shield: int = 50
@export var current_shield: int = 50
@export var max_energy: int = 100
@export var current_energy: int = 100

# Grondstoffen staan niet meer hier: de kluis in MetaProgress.resources, de run-buit in RunState.loot.

@export_category("Live Beweging (Run)")
@export var current_speed: float = 300.0
@export var current_acceleration: float = 1200.0
@export var current_friction: float = 1200.0
@export var current_rotation_speed: float = 10.0
@export var dash_enabled: bool = false

@export_category("Magneet & Buit")
@export var current_pickup_radius: float = 30.0    # Basis-straal voor direct oppakken
@export var loot_magnet_applied: bool = false   # Standaard geen magneet aan
@export var current_magnet_radius: float = 150.0   # Straal waarin loot naar je toe zuigt
@export var current_magnet_force: float = 400.0    # Snelheid van het toezuigen
