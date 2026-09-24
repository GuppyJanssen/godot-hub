extends CharacterBody2D
class_name NeutralEnemySpawner


@export var enemy_scene: PackedScene = null

# --- CONFIGURATIE OPTIES ---
@export var spawner_max_health: float = 150.0  # Hoeveel schade kan deze fabriek hebben?
@export var total_enemies_to_spawn: int = -1    # -1 = Oneindig doorgaan tot hij kapot is
@export var spawn_interval_seconds: float = 3.0
@export var spawn_on_start: bool = true

# Interne variabelen
var spawner_current_health: float = 150.0
var enemies_spawned_count: int = 0
var spawn_timer: Timer = null
var active_scene: Node = null
var my_id: String = ""
var room_key: String = ""
var is_destroyed: bool = false

@onready var sprite: Sprite2D = find_child("*Sprite*", true, false) as Sprite2D


func _ready() -> void:
	# Een neutrale spawner hoeft geen lasers op te vangen, dus NIET in 'targets'!
	spawner_current_health = spawner_max_health
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if enemy_scene == null:
		var safe_path = "res://Entities/Objects/test_body.tscn" # Tijdelijke fallback
		if ResourceLoader.exists(safe_path):
			enemy_scene = load(safe_path)
			
	if not is_inside_tree() or get_tree() == null: return
	active_scene = get_tree().current_scene
	
	room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	# Unieke database ID
	my_id = "NeutralSpawner_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	var object_already_destroyed: bool = false
	if FileAccess.file_exists(full_path):
		var spawner_file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(spawner_file.get_as_text()) == OK:
			var data = json.get_data()
			if data.has("target_damage_taken") and data["target_damage_taken"].has(room_key):
				var room_damage = data["target_damage_taken"][room_key]
				# Als het geplaatste gebouw/object in een eerdere sessie al is gesloopt, blijft het leeg
				if room_damage.has(my_id) and float(room_damage[my_id]) >= spawner_max_health:
					object_already_destroyed = true
		spawner_file.close()
		
	if object_already_destroyed:
		print("NEUTRAL SPAWNER: Object ", my_id, " was al permanent gesloopt. Geen spawn.")
		queue_free()
		return
		
	# BINGO: Eenmalige onzichtbare spawnactie!
	if enemy_scene and is_instance_valid(active_scene):
		var inst = enemy_scene.instantiate()
		inst.name = my_id # Het gebouw/object krijgt de ID van de spawner mee!
		inst.global_position = global_position
		active_scene.add_child(inst)
		
		# Voeg het object toe aan de groepen zodat je het kapot kunt schieten
		inst.add_to_group("targets")
		inst.add_to_group("enemies")
		print("NEUTRAL SPAWNER: Universeel object '", inst.name, "' succesvol achtergelaten op coördinaten.")
		
	# Ruim de onzichtbare spawner direct op; de test_body staat nu zelfstandig op het veld!
	queue_free()


func spawn_single_enemy() -> void:
	if is_destroyed or not enemy_scene or not is_instance_valid(active_scene): return
	
	var inst = enemy_scene.instantiate()
	
	# GECORRIGEERD: De grunts behouden de pure 'Enemy_' prefix voor de SSoT database!
	var enemy_base_name = "NeutralEnemy_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	if total_enemies_to_spawn == 1:
		inst.name = enemy_base_name
	else:
		inst.name = enemy_base_name + "_thing_" + str(enemies_spawned_count)
		
	inst.global_position = global_position + Vector2(randf_range(-20, 20), randf_range(20, 40))
	active_scene.add_child(inst)
	
	inst.add_to_group("targets")
	inst.add_to_group("enemies")
	enemies_spawned_count += 1


# --- SCHADE OPVANGEN EN PERMANENTE VERNIETIGING ---
func take_damage(amount: int, flash: bool = true, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	if is_destroyed or spawner_current_health <= 0: return
	
	spawner_current_health = max(0, spawner_current_health - amount)
	print("SPAWNER ", my_id, " GERAAKT! HP over: ", spawner_current_health, "/", spawner_max_health)
	
	# Arcade flits-effect op de fabriek zelf
	if flash and sprite:
		sprite.modulate = Color(4.0, 4.0, 4.0, 1.0)
		await get_tree().create_timer(0.055, false).timeout
		sprite.modulate = Color.WHITE
		
	if spawner_current_health <= 0:
		is_destroyed = true
		call_deferred("_deferred_destruction")


func _deferred_death(_hit_dir: Vector2) -> void:
	# Fallback: Mocht een kogel per ongeluk _deferred_death aanroepen in plaats van take_damage
	take_damage(999, false)


# GECORRIGEERD: Smijt de spawner direct uit de groepen zodat de barrières direct openvliegen!
func _deferred_destruction() -> void:
	print("SPAWNER: ", my_id, " is volledig BESCHOTEN en VERNIETIGD!")
	
	# BINGO: Haal de node direct administratief uit de groepen. 
	# Hierdoor ziet game_room.gd per direct 0 vijanden en zakken de muren direct in!
	if is_in_group("targets"): remove_from_group("targets")
	if is_in_group("enemies"): remove_from_group("enemies")
	
	# Meld de vernietiging met de maximale schade-waarde aan het SaveSystem
	var save_system_script = load("res://Systems/SaveSystem.gd")
	if save_system_script:
		var save_instance = save_system_script.new()
		if save_instance:
			if not save_instance.dead_enemies_cache.has(room_key):
				save_instance.dead_enemies_cache[room_key] = []
			if not my_id in save_instance.dead_enemies_cache[room_key]:
				save_instance.dead_enemies_cache[room_key].append(my_id)
				print("SPAWNER: Destructie succesvol opgeslagen in dead_enemies_cache.")
				
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
		
	# Wis de node nu veilig aan de start van het volgende frame
	queue_free()
