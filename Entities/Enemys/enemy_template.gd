extends CharacterBody2D # Of StaticBody2D als hij stilstaat
class_name EnemyTemplate

# --- UNIVERSELE DYNAMISCHE SLEUTEL ---
# Hiermee typt het team in de Inspector simpelweg een getal (1, 2, 3) 
# en de database zoekt AUTOMATISCH de juiste Excel-rij op!
@export_range(1, 6) var enemy_type: int = 1

# --- INTERNE LOGICA TELLERS (Als lege hulzen!) ---
var max_health: int = 50
var current_health: int = 50
var speed: float = 100.0
var damage: int = 10

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# Voeg de node direct toe aan de universele targets-groep voor kogels
	add_to_group("targets")
	
	# We bouwen de CSV-sleutel dynamisch op (enemy_test_1, enemy_test_2, etc.)
	var csv_key = "enemy_test_" + str(enemy_type)
	
	if csv_key in MasterDatabase.enemy_data:
		var e_data = MasterDatabase.enemy_data[csv_key]
		var e_stats = e_data["base_stats"]
		
		# We laden alle stats nu 100% waterdicht in vanuit jullie Google Spreadsheet!
		max_health = int(e_stats.get("health", 50))
		speed = float(e_stats.get("speed", 100.0))
		damage = int(e_stats.get("damage", 10))
		
		if "loot_amount_blocks" in e_stats:
			set_meta("loot_blocks", int(e_stats["loot_amount_blocks"]))
			
		print(name, " (Template) succesvol geboren via CSV! HP: ", max_health, " Speed: ", speed)
	else:
		# Veilige backup mocht de spreadsheet-sleutel een typefout hebben
		max_health = 50
		speed = 100.0
		damage = 10
		set_meta("loot_blocks", 3)
		
	# Dwing de start-HP naar het maximale niveau uit de CSV
	current_health = max_health


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
