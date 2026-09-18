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

# We voegen een extra 'is_loading' vinkje toe dat standaard op false staat
func take_damage(amount: int, is_loading: bool = false) -> void:
	current_health -= amount
	print(name, " verwerkt schade! Resterende HP: ", current_health)
	
	# Start het visuele knipper-effect ALLEEN als het een live kogel was, niet bij het laden!
	if not is_loading:
		flash_white()
	
	# Als de HP op of onder de 0 komt, ruimen we het blok op via jullie eigen logica
	if current_health <= 0:
		print(name, " is succesvol kapot gegaan!")
		current_health = 0
		remove_from_group("targets")
		queue_free()


func flash_white() -> void:
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	await get_tree().create_timer(0.055).timeout
	sprite.modulate = Color.WHITE


func _on_hit_box_area_entered(area: Area2D) -> void:
	if "current_stats" in area:
		# Live kogel hit: we roepen take_damage op de normale manier aan
		take_damage(10, false)
		area.queue_free()
