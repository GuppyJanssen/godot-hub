extends CharacterBody2D
# SSoT TEST-VIJAND: Geconsolideerd met Bewegings-AI, CSV-Geboorte & Loot-Explosies

# --- VARIABELEN (Gekoppeld aan de database) ---
var max_health: int = 50
var current_health: int = 50

# Bewegingsstats (Snelheid waarmee ze achter je aan jagen)
@export var movement_speed: float = 140.0
@export var rotation_speed: float = 4.0

# Editor-keuze voor welk Excel-type deze vijand is
@export_range(1, 6) var test_body_type: int = 1

@onready var sprite: Sprite2D = find_child("*Sprite*", true, false) as Sprite2D


func _ready() -> void:
	add_to_group("targets")
	add_to_group("enemies")
	
	# 1. DATA LADEN UIT DE SINGLE SOURCE OF TRUTH (SSoT) CSV
	var csv_key = "enemy_test_" + str(test_body_type)
	if csv_key in MasterDatabase.enemy_data:
		var e_data = MasterDatabase.enemy_data[csv_key]
		var e_stats = e_data["base_stats"]
		
		if "health" in e_stats: 
			max_health = int(e_stats["health"])
		if "loot_amount_blocks" in e_stats:
			set_meta("loot_blocks", int(e_stats["loot_amount_blocks"]))
			
		print(name, " succesvol geboren! HP geladen uit SSoT CSV: ", max_health)
	else:
		max_health = 50
		set_meta("loot_blocks", 3)
		
	current_health = max_health
	
	# 2. SSoT GEBOORTE-CHECK (Voorkomt herrijzenis uit de dood)
	await get_tree().process_frame
	
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var run_data = json.get_data()
			if run_data.has("target_damage_taken") and run_data["target_damage_taken"].has(room_key):
				var active_room_damage = run_data["target_damage_taken"][room_key]
				
				if active_room_damage.has(name):
					var damage_taken = int(active_room_damage[name])
					if damage_taken >= max_health:
						print("SSoT BEVEILIGING: ", name, " hoort dood te zijn in ", room_key, ". queue_free() geactiveerd!")
						file.close()
						queue_free()
						return
		file.close()


# --- 3. DYNAMISCHE BEWEGINGS-AI (60x per seconde) ---
func _physics_process(delta: float) -> void:
	var player = Game.active_player
	
	if is_instance_valid(player):
		# Bereken de richtingvector naar de speler toe
		var direction_to_player = (player.global_position - global_position).normalized()
		
		# Draai de neus/sprite van de vijand vlot richting de astronaut
		var target_angle = direction_to_player.angle()
		global_rotation = rotate_toward(global_rotation, target_angle, rotation_speed * delta)
		
		# Geef de snelheid mee aan de CharacterBody2D en glijd over het veld
		velocity = direction_to_player * movement_speed
		move_and_slide()
	else:
		# Rem rustig af tot stilstand als de speler dood of onzichtbaar is
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()


# --- 4. SCHADE-AFHANDELING EN ARCADE-FLITS ---
func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0: 
		return
		
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health, "/", max_health)
	
	if flash and has_method("flash_white"):
		call("flash_white")
	elif flash and sprite:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		await get_tree().create_timer(0.055, false).timeout
		sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		call_deferred("_deferred_death", hit_dir)


# GECORRIGEERD: Smijt de grunt direct uit de groepen zodat de deuren per direct openvliegen!
func _deferred_death(hit_dir: Vector2) -> void:
	# BINGO: Haal de node direct administratief uit de actieve groepen.
	# Dit voorkomt dat queue_free() de deurenteller in game_room.gd een frame lang gijzelt!
	if is_in_group("targets"): remove_from_group("targets")
	if is_in_group("enemies"): remove_from_group("enemies")
	
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	
	var save_system_script = load("res://Systems/SaveSystem.gd")
	if save_system_script:
		var save_system_instance = save_system_script.new()
		if save_system_instance:
			if not save_system_instance.dead_enemies_cache.has(room_key):
				save_system_instance.dead_enemies_cache[room_key] = []
			if not name in save_system_instance.dead_enemies_cache[room_key]:
				save_system_instance.dead_enemies_cache[room_key].append(name)
				print("VIJAND: Overlijden van ", name, " succesvol geregistreerd voor ", room_key)

	_drop_specific_loot(hit_dir)
	queue_free()


# --- 5. SAPPIGE LOOT EXPLOSIE ---
func _drop_specific_loot(hit_dir: Vector2) -> void:
	var loot_scene = load("res://Entities/Objects/loot_drop.tscn")
	if not loot_scene: 
		return
	
	var total_drops = get_meta("loot_blocks", 3)
	
	for i in range(total_drops):
		var loot_instance = loot_scene.instantiate()
		var rand_amount = randi_range(5, 15)
		loot_instance.init_loot(test_body_type, rand_amount)
		
		if loot_instance.has_method("set_impact_direction"):
			var scatter = Vector2(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5))
			var final_impulse = (hit_dir + scatter).normalized()
			loot_instance.set_impact_direction(final_impulse)
		
		loot_instance.global_position = global_position + Vector2(randf_range(-15, 15), randf_range(-15, 15))
		get_tree().current_scene.add_child(loot_instance)
