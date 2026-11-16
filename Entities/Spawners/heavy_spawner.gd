extends CharacterBody2D
class_name HeavyEnemySpawner


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
var room_layer: int = 0
var room_index: int = 0
var is_destroyed: bool = false
var restored_timer_left: float = 0.0  # resterende tijd tot de volgende grunt, na het laden

@onready var sprite: Sprite2D = find_child("*Sprite*", true, false) as Sprite2D


func _ready() -> void:
	# 1. DOELWIT REGISTRATIE
	add_to_group("targets")
	add_to_group("saveable")  # deze fabriek wil onthouden worden (zie game_room.gd)
	spawner_current_health = spawner_max_health
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	if enemy_scene == null:
		var safe_path = "res://Entities/Objects/test_body.tscn"
		if ResourceLoader.exists(safe_path):
			enemy_scene = load(safe_path)
			
	if not is_inside_tree() or get_tree() == null: return
	active_scene = get_tree().current_scene
	
	room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	room_layer = LevelManager.current_layer
	room_index = LevelManager.current_room_index
	
	# GECORRIGEERD: De fabriek krijgt nu het unieke voorvoegsel 'Spawner_' 
	# Dit voorkomt dat hij dezelfde naam draagt als de eerste vijand!
	my_id = get_run_id()
	
	# Maak de zware fabriek visueel groter dan de basis variant!
	if is_instance_valid(sprite):
		sprite.scale = Vector2(1.5, 1.5)
	
	# Is deze fabriek deze run al gesloopt? RunState weet het.
	var spawner_already_destroyed: bool = RunState.is_dead(room_layer, room_index, my_id)
		
	if spawner_already_destroyed:
		print("SPAWNER: Object ", my_id, " is permanent kapot. Node verwijderd.")
		queue_free()
		return
		
	# Stond deze fabriek er al toen je de kamer verliet? Zet dan zijn HP en zijn teller terug.
	# De grunts die nog leefden, zet de kamer zelf terug (zie game_room.gd).
	var saved: Dictionary = RunState.get_saved_unit(room_layer, room_index, my_id)
	var was_restored: bool = not saved.is_empty()
	if was_restored:
		apply_run_state(saved)
		print("RUNSTATE: ", my_id, " teruggezet met HP ", spawner_current_health, "/", spawner_max_health)
	
	if spawn_on_start and not was_restored:
		spawn_single_enemy()
		
	if total_enemies_to_spawn > 1 or total_enemies_to_spawn == -1:
		_setup_spawn_timer()


func _setup_spawn_timer() -> void:
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval_seconds
	spawn_timer.autostart = true
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	# Na het laden: ga verder met de tijd die er nog op de klok stond.
	if restored_timer_left > 0.0:
		spawn_timer.start(restored_timer_left)
		restored_timer_left = 0.0


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# De naam waaraan deze fabriek herkend wordt: gebaseerd op zijn plek in de kamer.
func get_run_id() -> String:
	return "HeavySpawner_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"


# Wat deze fabriek wil bewaren.
func get_run_state() -> Dictionary:
	if is_destroyed:
		return {}  # kapot: niet bewaren, de dodenlijst regelt dat
	var timer_left: float = 0.0
	if is_instance_valid(spawn_timer):
		timer_left = spawn_timer.time_left
	return {
		"hp": spawner_current_health,
		"count": enemies_spawned_count,
		"timer_left": timer_left,
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	spawner_current_health = float(data.get("hp", spawner_max_health))
	enemies_spawned_count = int(data.get("count", 0))
	restored_timer_left = float(data.get("timer_left", 0.0))


func _on_spawn_timer_timeout() -> void:
	if is_destroyed: return
	# Na het laden liep de klok één keer korter. Zet hem terug op de normale tijd.
	if is_instance_valid(spawn_timer) and not is_equal_approx(spawn_timer.wait_time, spawn_interval_seconds):
		spawn_timer.start(spawn_interval_seconds)
	if total_enemies_to_spawn != -1 and enemies_spawned_count >= total_enemies_to_spawn:
		if is_instance_valid(spawn_timer): spawn_timer.stop()
		return
	spawn_single_enemy()


func spawn_single_enemy() -> void:
	if is_destroyed or not enemy_scene or not is_instance_valid(active_scene): return
	
	var inst = enemy_scene.instantiate()
	
	# GECORRIGEERD: De grunts behouden de pure 'Enemy_' prefix voor de SSoT database!
	var enemy_base_name = "HeavyEnemy_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	if total_enemies_to_spawn == 1:
		inst.name = enemy_base_name
	else:
		# Sla de heavies over die deze run al gedood zijn, zodat de fabriek verdergaat waar hij was.
		while RunState.is_dead(room_layer, room_index, enemy_base_name + "_heavy_" + str(enemies_spawned_count)):
			enemies_spawned_count += 1
		if total_enemies_to_spawn != -1 and enemies_spawned_count >= total_enemies_to_spawn:
			inst.free()
			return
		inst.name = enemy_base_name + "_heavy_" + str(enemies_spawned_count)
		
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
	
	# Onthoud in RunState dat deze fabriek kapot is.
	RunState.mark_dead(room_layer, room_index, my_id)
	print("SPAWNER: Destructie onthouden in RunState.")
				
	if is_instance_valid(spawn_timer):
		spawn_timer.stop()
		
	# Wis de node nu veilig aan de start van het volgende frame
	queue_free()
