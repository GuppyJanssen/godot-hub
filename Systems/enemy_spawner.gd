extends Marker2D
class_name EnemySpawner

@export var enemy_scene: PackedScene = null

# --- NIEUWE CONFIGURATIE OPTIES (Direct aanpasbaar in de Inspector!) ---
@export var total_enemies_to_spawn: int = 1      # Hoeveel vijanden mag deze spawner TOTAAL uitspugen? (-1 = oneindig)
@export var spawn_interval_seconds: float = 3.0  # Hoeveel seconden ademruimte zit er tussen de live spawns?
@export var spawn_on_start: bool = true          # Moet de allereerste vijand direct bij het laden verschijnen?

# Interne tellers voor de fabriek-logica
var enemies_spawned_count: int = 0
var spawn_timer: Timer = null
var active_scene: Node = null
var my_id: String = ""
var room_key: String = ""


func _ready() -> void:
	# Wacht netjes tot de core systemen online staan
	await get_tree().process_frame
	await get_tree().process_frame
	
	if enemy_scene == null:
		var safe_path = "res://Entities/Objects/test_body.tscn"
		if ResourceLoader.exists(safe_path):
			enemy_scene = load(safe_path)
			
	if not is_inside_tree() or get_tree() == null: return
	
	active_scene = get_tree().current_scene
	if not active_scene or not is_instance_valid(active_scene): return
	
	room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	# Unieke ID generatie conform de SSoT database logs
	my_id = "Enemy_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	var spawner_already_destroyed: bool = false
	
	# Controleer in de JSON of deze spawner/fabriek in een eerdere kamer-sessie al is gesloopt
	if FileAccess.file_exists(full_path):
		var spawner_file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(spawner_file.get_as_text()) == OK:
			var data = json.get_data()
			if data.has("target_damage_taken") and data["target_damage_taken"].has(room_key):
				var room_damage = data["target_damage_taken"][room_key]
				# Als de ID bestaat en de geregistreerde waarde is de doodswaarde (>= 50), blijft hij leeg
				if room_damage.has(my_id) and float(room_damage[my_id]) >= 50.0:
					spawner_already_destroyed = true
		spawner_file.close()
		
	if spawner_already_destroyed:
		print("SPAWNER: Object ", my_id, " is permanent vernietigd in ", room_key, ". Geen spawns meer.")
		queue_free()
		return
		
	# --- FABRIEK LOGICA INITIALISEREN ---
	if spawn_on_start:
		spawn_single_enemy()
		
	# Als de spawner meer dan 1 kogel/vijand moet spuwen of oneindig doorgaat (-1), zetten we een timer aan
	if total_enemies_to_spawn > 1 or total_enemies_to_spawn == -1:
		_setup_spawn_timer()


func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval_seconds
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)


func _on_spawn_timer_timeout() -> void:
	# Als het maximale aantal vijanden voor deze spawner is bereikt, stopt de timer automatisch
	if total_enemies_to_spawn != -1 and enemies_spawned_count >= total_enemies_to_spawn:
		if is_instance_valid(spawn_timer):
			spawn_timer.stop()
		return
		
	spawn_single_enemy()


func spawn_single_enemy() -> void:
	if not enemy_scene or not is_instance_valid(active_scene): return
	
	var inst = enemy_scene.instantiate()
	
	# TOEKOMSTGERICHT: Als dit 1 specifieke vijand is, krijgt hij de hoofd-ID.
	# Als de fabriek door blijft spuwen, krijgt elke grunt een uniek volgnummer erachter.
	if total_enemies_to_spawn == 1:
		inst.name = my_id
	else:
		inst.name = my_id + "_grunt_" + str(enemies_spawned_count)
		
	inst.global_position = global_position
	active_scene.add_child(inst)
	
	inst.add_to_group("targets")
	inst.add_to_group("enemies")
	
	enemies_spawned_count += 1
	print("SPAWNER: Vijand '", inst.name, "' live op het veld gezet (Totaal: ", enemies_spawned_count, ")")
