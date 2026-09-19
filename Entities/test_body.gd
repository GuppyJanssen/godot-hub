extends StaticBody2D

# --- VARIABELEN ---
@export var max_health: int = 50
var current_health: int = 50

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Zorg dat elk blokje ALTIJD in de groep 'targets' zit
	add_to_group("targets")
	current_health = max_health


# --- EIGEN FUNCTIES ---

# GECORRIGEERD: is_loading MOET standaard op false staan, anders doet niks meer damage!
func take_damage(amount: int, is_loading: bool = false) -> void:
	# REPARATIE: Als de vijand al dood is of wordt opgeruimd, 
	# negeren we ALLE spookhits en dubbele prints per direct!
	if current_health <= 0:
		return
		
	if is_loading == true:
		current_health = max(0, current_health - amount)
		if current_health <= 0:
			queue_free()
		return
		
	# --- VANAF HIER: NORMALE IN-GAME SCHADE ---
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health)
	
	if has_method("flash_white"):
		flash_white()
		
	if current_health <= 0:
		# Ruim de vijand direct netjes op
		queue_free()



func flash_white() -> void:
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	await get_tree().create_timer(0.055).timeout
	sprite.modulate = Color.WHITE
