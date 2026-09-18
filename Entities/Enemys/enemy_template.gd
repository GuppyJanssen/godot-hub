extends CharacterBody2D # Verander naar StaticBody2D als het een stilstaand blokje is!

class_name EnemyTemplate

# --- DATA RESOURCE ---
# Hier sleep je rechts in de Inspector jullie gemaakte EnemyStats.tres bestand in!
@export var enemy_stats: EnemyStats

# --- INTERNE LOGICA TELLERS ---
var max_health: int = 50
var current_health: int = 50

@onready var sprite: Sprite2D = $Sprite2D


# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	# Voeg de node direct toe aan de universele Save-groep
	add_to_group("targets")
	
	# Laad de basis-eigenschappen in vanuit de gekoppelde ResourceBlauwdruk
	if enemy_stats:
		max_health = enemy_stats.max_health
		# Alleen vullen met max_health als het SaveSystem de HP nog niet heeft aangepast bij het laden!
		if current_health == 50:
			current_health = max_health
	else:
		push_warning("Waarschuwing: Geen EnemyStats resource gekoppeld aan " + name)


# --- EIGEN FUNCTIES (SCHADE EN BEWEGING) ---

func take_damage(amount: int, is_loading: bool = false) -> void:
	current_health -= amount
	print(name, " verwerkt schade! Resterende HP: ", current_health)
	
	if is_loading:
		# Bevries sensoren tijdens de laad-frame om dubbele hits te voorkomen
		set_physics_process(false)
		if has_node("HitBox"):
			$HitBox.set_deferred("monitoring", false)
			$HitBox.set_deferred("monitorable", false)
	else:
		# Alleen flitsen als het een live kogelhit is
		flash_white()
		
	# Als de HP op of onder de 0 komt, ruimen we de vijand op
	if current_health <= 0:
		print(name, " is succesvol verslagen!")
		current_health = 0
		remove_from_group("targets") # Voorkom dat hij nog gescand wordt bij een save
		queue_free()


func flash_white() -> void:
	if sprite:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		await get_tree().create_timer(0.055).timeout
		sprite.modulate = Color.WHITE


func _on_hit_box_area_entered(area: Area2D) -> void:
	# Controleer of het een kogel is
	if "current_stats" in area:
		take_damage(10, false)
		area.queue_free()
