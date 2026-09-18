extends Node

const SAVE_DIR: String = "user://Saves/"

# --- 1. PERMANENTE VOORTGANG (META PROGRESSIE & SKILLS) ---

func save_meta_progress(meta_resource: Resource) -> void:
	if Game.active_save_slot == "": return
	var slot_dir: String = "user://" + Game.active_save_slot + "/"
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_absolute(slot_dir)
		
	var save_dict: Dictionary = {
		"currency_1": meta_resource.currency_1 if "currency_1" in meta_resource else 0,
		"currency_2": meta_resource.currency_2 if "currency_2" in meta_resource else 0,
		"currency_3": meta_resource.currency_3 if "currency_3" in meta_resource else 0,
		"skill_1_level": meta_resource.skill_1_level if "skill_1_level" in meta_resource else 0,
		"skill_2_level": meta_resource.skill_2_level if "skill_2_level" in meta_resource else 0
	}
	
	var file = FileAccess.open(slot_dir + "meta_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()


func load_meta_progress(meta_resource: Resource) -> void:
	if Game.active_save_slot == "": return
	var full_path: String = "user://" + Game.active_save_slot + "/meta_data.json"
	if not FileAccess.file_exists(full_path): return
	
	var file = FileAccess.open(full_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var save_dict: Dictionary = json.get_data()
		if save_dict.has("currency_1"): meta_resource.currency_1 = save_dict["currency_1"]
		if save_dict.has("currency_2"): meta_resource.currency_2 = save_dict["currency_2"]
		if save_dict.has("currency_3"): meta_resource.currency_3 = save_dict["currency_3"]
		if save_dict.has("skill_1_level"): meta_resource.skill_1_level = save_dict["skill_1_level"]
		if save_dict.has("skill_2_level"): meta_resource.skill_2_level = save_dict["skill_2_level"]
	file.close()


func get_loaded_meta_progress() -> Resource:
	var meta_res = load("res://Resources/meta_progress.gd").new()
	if Game.active_save_slot != "":
		var full_path: String = "user://" + Game.active_save_slot + "/meta_data.json"
		if FileAccess.file_exists(full_path):
			var file = FileAccess.open(full_path, FileAccess.READ)
			var json = JSON.new()
			if json.parse(file.get_as_text()) == OK:
				var save_dict: Dictionary = json.get_data()
				if save_dict.has("currency_1"): meta_res.currency_1 = save_dict["currency_1"]
				if save_dict.has("currency_2"): meta_res.currency_2 = save_dict["currency_2"]
				if save_dict.has("currency_3"): meta_res.currency_3 = save_dict["currency_3"]
				if save_dict.has("skill_1_level"): meta_res.skill_1_level = save_dict["skill_1_level"]
				if save_dict.has("skill_2_level"): meta_res.skill_2_level = save_dict["skill_2_level"]
			file.close()
	return meta_res


func add_and_save_run_loot(xp_won: int, currency_won: int) -> void:
	if Game.active_save_slot == "": return
	var current_meta = get_loaded_meta_progress()
	current_meta.currency_1 += xp_won
	current_meta.currency_2 += currency_won
	save_meta_progress(current_meta)


# --- 2. TIJDELIJKE RUN SAVE LOGICA (HERSTELD!) ---

func save_current_run(player_node: Player) -> void:
	if Game.active_save_slot == "": return
	var slot_dir: String = "user://" + Game.active_save_slot + "/"
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_absolute(slot_dir)
		
	var target_damage_taken: Dictionary = {}
	for target in player_node.get_tree().get_nodes_in_group("targets"):
		if "current_health" in target and "max_health" in target:
			var damage = target.max_health - target.current_health
			target_damage_taken[target.name] = damage
		else:
			target_damage_taken[target.name] = 0
			
	var run_data: Dictionary = {
		"player_position_x": player_node.global_position.x,
		"player_position_y": player_node.global_position.y,
		"player_velocity_x": player_node.velocity.x,
		"player_velocity_y": player_node.velocity.y,
		"player_hp": player_node.stats.current_health if player_node.stats else 100,
		"run_xp": player_node.run_xp_earned,
		"run_currency": player_node.run_currency_earned,
		"target_damage_taken": target_damage_taken
	}
	
	var file = FileAccess.open(slot_dir + "current_run.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(run_data, "\t"))
		file.close()
		print("Run én schade-status van de wereld succesvol geparkeerd op schijf!")


func load_current_run(player_node: Player) -> void:
	if Game.active_save_slot == "": return
	var full_path: String = "user://" + Game.active_save_slot + "/current_run.json"
	if not FileAccess.file_exists(full_path): return
	
	var file = FileAccess.open(full_path, FileAccess.READ)
	var json = JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var run_data: Dictionary = json.get_data()
		
		if run_data.has("player_position_x") and run_data.has("player_position_y"):
			player_node.global_position = Vector2(run_data["player_position_x"], run_data["player_position_y"])
		if run_data.has("player_velocity_x") and run_data.has("player_velocity_y"):
			player_node.velocity = Vector2(run_data["player_velocity_x"], run_data["player_velocity_y"])
		if run_data.has("player_hp") and player_node.stats:
			player_node.stats.current_health = run_data["player_hp"]
			
		if run_data.has("run_xp"): player_node.run_xp_earned = run_data["run_xp"]
		if run_data.has("run_currency"): player_node.run_currency_earned = run_data["run_currency"]
		
		if run_data.has("target_damage_taken"):
			var damage_list: Dictionary = run_data["target_damage_taken"]
			var active_targets = player_node.get_tree().get_nodes_in_group("targets")
			
			for target in active_targets:
				if target is StaticBody2D or target is CharacterBody2D:
					if damage_list.has(target.name):
						var damage_to_apply = damage_list[target.name]
						if damage_to_apply > 0:
							if target.has_method("take_damage"):
								target.take_damage(damage_to_apply, true)
					else:
						if target.has_method("take_damage") and "max_health" in target:
							target.take_damage(target.max_health, true)
							
		print("Run succesvol hervat! Alle schade is exact één keer verdeeld.")
	file.close()


func delete_current_run_save() -> void:
	if Game.active_save_slot == "": return
	var full_path: String = "user://" + Game.active_save_slot + "/current_run.json"
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)
