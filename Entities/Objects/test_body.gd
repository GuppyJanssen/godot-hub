extends StaticBody2D

# --- VARIABELEN (Puur als lege hulzen, de CSV vult ze bij de geboorte!) ---
var max_health: int = 50
var current_health: int = 50

# Deze export mag blijven, hiermee kies je in de editor welke rij uit de Excel deze vijand is (1, 2, etc.)
@export_range(1, 6) var test_body_type: int = 1

@onready var sprite: Sprite2D = find_child("*Sprite*", true, false) as Sprite2D


func _ready() -> void:
	add_to_group("targets")
	
	# We bepalen de CSV-sleutel op basis van het type (enemy_test_1, enemy_test_2, etc.)
	var csv_key = "enemy_test_" + str(test_body_type)
	
	if csv_key in MasterDatabase.enemy_data:
		var e_data = MasterDatabase.enemy_data[csv_key]
		var e_stats = e_data["base_stats"]
		
		# We halen de HP en loot-hoeveelheid direct live uit de Google Spreadsheet!
		if "health" in e_stats: 
			max_health = int(e_stats["health"])
		
		if "loot_amount_blocks" in e_stats:
			set_meta("loot_blocks", int(e_stats["loot_amount_blocks"]))
			
		print(name, " succesvol geboren! HP geladen uit SSoT CSV: ", max_health)
	else:
		# Veilige fallback voor als de Excel-sleutel ontbreekt
		max_health = 50
		set_meta("loot_blocks", 3)
		
	current_health = max_health
	# --- SSoT GEBOORTE-CHECK ---
	# De vijand controleert direct bij zijn eigen ready-frame of hij in de JSON-save staat als 'verslagen'
	await get_tree().process_frame # Wacht heel even tot de LevelManager de juiste kamer-index heeft
	
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var run_data = json.get_data()
			if run_data.has("target_damage_taken") and run_data["target_damage_taken"].has(room_key):
				var active_room_damage = run_data["target_damage_taken"][room_key]
				
				# Als onze exacte node-naam (test_body of test_body2) in de schadelijst staat als 'dood' (HP over: 0)
				if active_room_damage.has(name):
					var damage_taken = int(active_room_damage[name])
					if damage_taken >= 50: # Veronderstelt jullie max HP van 50
						print("SSoT BEVEILIGING: ", name, " hoort dood te zijn in ", room_key, ". queue_free() geactiveerd!")
						file.close()
						queue_free() # Wis de herrezen vijand onmiddellijk!
						return
		file.close()


# --- GECORRIGEERD EN ENORM BELANGRIJK: Accepteert nu keurig alle 3 de argumenten! ---
func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0: 
		return # Al dood? Dan negeren we verdere kogels direct
		
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health, "/", max_health)
	
	# Als jullie een wit-flits methode hebben, roepen we die hier veilig aan via de bool!
	if flash and has_method("flash_white"):
		call("flash_white")
	elif flash and sprite:
		# Simpel en sappig arcade flits-alternatief als flash_white ontbreekt:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		await get_tree().create_timer(0.055, false).timeout
		sprite.modulate = Color.WHITE
	
	# Check of de genadeslag is gevallen
	if current_health <= 0:
		# GECORRIGEERD: We gebruiken call_deferred om de loot-aanmaak en de vernietiging 
		# veilig uit te stellen tot NA de physics-berekening. Dit voorkomt eventuele boom-crashes!
		call_deferred("_deferred_death", hit_dir)


# Splinternieuwe hulpfunctie voor de veilige, uitgestelde dood
func _deferred_death(hit_dir: Vector2) -> void:
	# 1. GECORRIGEERD: Meld het overlijden EERST aan de database voordat we queue_free() aanroepen!
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	
	# Laad het SaveSystem handmatig in om de 'not declared' Autoload-error te vermoorden
	var save_system_script = load("res://Systems/SaveSystem.gd")
	if save_system_script:
		var save_system_instance = save_system_script.new()
		if save_system_instance:
			if not save_system_instance.dead_enemies_cache.has(room_key):
				save_system_instance.dead_enemies_cache[room_key] = []
			if not name in save_system_instance.dead_enemies_cache[room_key]:
				save_system_instance.dead_enemies_cache[room_key].append(name)
				print("VIJAND: Overlijden van ", name, " succesvol geregistreerd voor ", room_key)

	# 2. Drop de buit en verwijder de node veilig uit de scene
	_drop_specific_loot(hit_dir)
	queue_free()

# --- SAPPIGE LOOT EXPLOSIE MATH ---
func _drop_specific_loot(hit_dir: Vector2) -> void:
	var loot_scene = load("res://Entities/Objects/loot_drop.tscn")
	if not loot_scene: 
		return
	
	# Haal het aantal vallende blokjes live op uit de metadata van de CSV
	var total_drops = get_meta("loot_blocks", 3)
	
	for i in range(total_drops):
		var loot_instance = loot_scene.instantiate()
		var rand_amount = randi_range(5, 15)
		loot_instance.init_loot(test_body_type, rand_amount)
		
		# ARCADE JUICE IMPULS: We knallen de grondstoffen in de richting van het schot!
		if loot_instance.has_method("set_impact_direction"):
			# We voegen een flinke dosis willekeur toe voor een prachtig waaier-effect
			var scatter = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			var final_impulse = (hit_dir + scatter).normalized()
			loot_instance.set_impact_direction(final_impulse)
		
		# Plaats het blokje rondom de vijand en voeg toe aan de kamer
		loot_instance.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		get_tree().current_scene.add_child(loot_instance)
