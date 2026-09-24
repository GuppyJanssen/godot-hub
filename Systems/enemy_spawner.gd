extends Marker2D
class_name EnemySpawner

@export var enemy_scene: PackedScene = null


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	
	if enemy_scene == null:
		var safe_path = "res://Entities/Objects/test_body.tscn"
		if ResourceLoader.exists(safe_path):
			enemy_scene = load(safe_path)
			
	if not is_inside_tree() or get_tree() == null: return
	
	var active_scene = get_tree().current_scene
	if not active_scene or not is_instance_valid(active_scene): return
	
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	# GECORRIGEERD: Genereert nu exact het ID format 'Enemy_X.0_Y.0' conform jullie logboek!
	var my_id = "Enemy_" + str(snapped(global_position.x, 0.1)) + "_" + str(snapped(global_position.y, 0.1))
	# Mocht snapped() geen .0 toevoegen, dwingen we het via een string-fallback:
	if not ".0" in my_id:
		my_id = "Enemy_" + str(int(global_position.x)) + "_0_" + str(int(global_position.y)) + "_0"
	
	var should_skip_spawn: bool = false
	
	if FileAccess.file_exists(full_path):
		var spawner_file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(spawner_file.get_as_text()) == OK:
			var data = json.get_data()
			if data.has("target_damage_taken") and data["target_damage_taken"].has(room_key):
				var room_damage = data["target_damage_taken"][room_key]
				if room_damage.has(my_id):
					should_skip_spawn = true
		spawner_file.close()
		
	if should_skip_spawn:
		print("SPAWNER: Locatie ", my_id, " is al leeggeveegd in ", room_key, ". Spawn overgeslagen.")
		queue_free()
		return
		
	if enemy_scene:
		var inst = enemy_scene.instantiate()
		inst.name = my_id
		inst.global_position = global_position
		
		active_scene.add_child(inst)
		
		inst.add_to_group("targets")
		inst.add_to_group("enemies") 
		print("SPAWNER: Vijand '", inst.name, "' succesvol gegenereerd op locatie.")
