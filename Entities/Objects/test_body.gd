extends StaticBody2D

# --- VARIABELEN ---
@export var max_health: int = 50
var current_health: int = 50

# NIEUW: Voeg de type-schakelaar toe (1=Olrite, 2=Metal, 3=Keepium, 4=E1, 5=E2, 6=E3)
@export_range(1, 6) var test_body_type: int = 1

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Zorg dat elk blokje ALTIJD in de groep 'targets' zit
	add_to_group("targets")
	current_health = max_health


# --- EIGEN FUNCTIES ---

# GECORRIGEERD: We voegen 'hit_direction' toe als optioneel argument onderaan
func take_damage(amount: int, is_loading: bool = false, hit_direction: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0:
		return
		
	if is_loading == true:
		current_health = max(0, current_health - amount)
		if current_health <= 0:
			queue_free()
		return
		
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health)
	
	if has_method("flash_white"):
		flash_white()
		
	if current_health <= 0:
		# REPARATIE: We gebruiken nu call_deferred, maar sturen de hit_direction veilig mee!
		call_deferred("_drop_specific_loot", hit_direction)
		queue_free()


func flash_white() -> void:
	sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
	await get_tree().create_timer(0.055).timeout
	sprite.modulate = Color.WHITE


# GECORRIGEERD: Deze functie ontvangt nu de richting van de klap
func _drop_specific_loot(hit_dir: Vector2) -> void:
	var loot_scene = load("res://Entities/Objects/loot_drop.tscn")
	if not loot_scene: 
		push_error("Fout: loot_drop.tscn niet gevonden!")
		return
	
	for i in range(3):
		var loot_instance = loot_scene.instantiate()
		
		var rand_amount = randi_range(5, 15)
		loot_instance.init_loot(test_body_type, rand_amount)
		
		# We geven de kogelrichting mee aan het blokje buit bij het initialiseren!
		if loot_instance.has_method("set_impact_direction"):
			loot_instance.set_impact_direction(hit_dir)
		
		loot_instance.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-10, 10))
		get_tree().current_scene.add_child(loot_instance)
