extends Node
# SINGLE SOURCE OF TRUTH: SaveSystem (Kogelvrije Dodenlijst-Modus)

# NIEUW: Houdt live tijdens de run bij welke specifieke vijand-ID's zijn gesloopt!
var dead_enemies_cache: Dictionary = {}
const SAVE_DIR: String = "user://Saves/"


func get_loaded_meta_progress() -> Resource:
	var meta_res = load("res://Resources/meta_progress.gd").new()
	var full_path = "user://" + Game.active_save_slot + "/meta_data.json"
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var save_dict = json.get_data()
			for i in range(1, 7):
				var key = "currency_" + str(i)
				if save_dict.has(key): meta_res.set(key, save_dict[key])
			if save_dict.has("skills_data"): meta_res.skills_data = save_dict["skills_data"]
		file.close()
	return meta_res


func save_meta_progress(meta_resource: Resource) -> void:
	if Game.active_save_slot == "": return
	var slot_dir = "user://" + Game.active_save_slot + "/"
	if not DirAccess.dir_exists_absolute(slot_dir): DirAccess.make_dir_absolute(slot_dir)
	
	var save_dict = {
		"currency_1": meta_resource.currency_1, "currency_2": meta_resource.currency_2,
		"currency_3": meta_resource.currency_3, "currency_4": meta_resource.currency_4,
		"currency_5": meta_resource.currency_5, "currency_6": meta_resource.currency_6,
		"skills_data": meta_resource.skills_data
	}
	var file = FileAccess.open(slot_dir + "meta_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()


func add_and_save_run_loot(c1: int, c2: int, c3: int, c4: int, c5: int, c6: int) -> void:
	var meta = get_loaded_meta_progress()
	if meta:
		meta.currency_1 += c1; meta.currency_2 += c2; meta.currency_3 += c3
		meta.currency_4 += c4; meta.currency_5 += c5; meta.currency_6 += c6
		save_meta_progress(meta)


func save_current_run(player_node: CharacterBody2D) -> void:
	if Game.active_save_slot == "" or not is_instance_valid(player_node): return
	var slot_dir = "user://" + Game.active_save_slot + "/"
	var full_path = slot_dir + "current_run.json"
	
	var existing_damage = {}
	
	if FileAccess.file_exists(full_path):
		var read_file = FileAccess.open(full_path, FileAccess.READ)
		if is_instance_valid(read_file):
			var json = JSON.new()
			if json.parse(read_file.get_as_text()) == OK:
				var data = json.get_data()
				if data.has("target_damage_taken"): existing_damage = data["target_damage_taken"]
			read_file.close()
		
	var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	
	var room_damage_dict = {}
	if existing_damage.has(room_key):
		room_damage_dict = existing_damage[room_key]
		
	var active_targets = player_node.get_tree().get_nodes_in_group("targets")
	for target in active_targets:
		if is_instance_valid(target) and "current_health" in target:
			room_damage_dict[target.name] = target.max_health - target.current_health
			
	if "dead_enemies_cache" in self and dead_enemies_cache.has(room_key):
		for dead_id in dead_enemies_cache[room_key]:
			room_damage_dict[dead_id] = 50
			
	existing_damage[room_key] = room_damage_dict
	
	# DE LOOT-SCAN IS HIER VOLLEDIG VERWIJDERD!
	var run_data = {
		"player_position_x": player_node.global_position.x, "player_position_y": player_node.global_position.y,
		"player_hp": player_node.stats.current_health if player_node.stats else 100,
		"run_currency": player_node.run_currency_olrite,
		"current_layer": LevelManager.current_layer, "current_room_index": LevelManager.current_room_index,
		"target_damage_taken": existing_damage
	}
	
	var write_file = FileAccess.open(full_path, FileAccess.WRITE)
	if is_instance_valid(write_file):
		write_file.store_string(JSON.stringify(run_data, "\t"))
		write_file.close()
		print("SAVESYSTEM: Status voor ", room_key, " succesvol opgeslagen zonder loot-cache.")



func load_current_run(player_node: CharacterBody2D) -> void:
	if Game.active_save_slot == "" or not is_instance_valid(player_node): return
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	if not FileAccess.file_exists(full_path): return
	
	var file = FileAccess.open(full_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var data = json.get_data()
		var room_key = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
		
		if LevelManager.is_loading_from_continue:
			player_node.global_position = Vector2(data.get("player_position_x", 960), data.get("player_position_y", 540))
			
		if data.has("run_currency") and player_node.stats:
			player_node.run_currency_olrite = int(data["run_currency"])
			player_node.stats.currency_olrite = player_node.run_currency_olrite
			
		# Herstel de HP van de vijanden. Als ze al dood waren, queue_free()!
		if data.has("target_damage_taken") and data["target_damage_taken"].has(room_key):
			var d_map = data["target_damage_taken"][room_key]
			for target in player_node.get_tree().get_nodes_in_group("targets"):
				if d_map.has(target.name):
					target.current_health = max(0, target.max_health - int(d_map[target.name]))
					if target.current_health <= 0: target.queue_free()
					

	file.close()


func delete_current_run_save() -> void:
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	if FileAccess.file_exists(full_path): DirAccess.remove_absolute(full_path)

# Slaat het laatst gebruikte slot permanent op de schijf op
func save_last_used_slot(slot_name: String) -> void:
	var file = FileAccess.open("user://app_config.json", FileAccess.WRITE)
	if file:
		var config_data = {"last_slot": slot_name}
		file.store_string(JSON.stringify(config_data))
		file.close()

# Leest het laatst gebruikte slot uit van de schijf
func load_last_used_slot() -> String:
	if FileAccess.file_exists("user://app_config.json"):
		var file = FileAccess.open("user://app_config.json", FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var config_data = json.get_data()
			if config_data.has("last_slot"):
				file.close()
				return config_data["last_slot"]
		file.close()
	return ""
