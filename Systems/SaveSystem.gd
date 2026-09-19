extends Node

const SAVE_DIR: String = "user://Saves/"

# --- 1. PERMANENTE VOORTGANG (META PROGRESSIE & SKILLS) ---

func save_meta_progress(meta_resource: Resource) -> void:
	if Game.active_save_slot == "": return
	var slot_dir: String = "user://" + Game.active_save_slot + "/"
	if not DirAccess.dir_exists_absolute(slot_dir):
		DirAccess.make_dir_absolute(slot_dir)
		
	# We pakken de complete Dictionary met alle upgrades (1 t/m 100) in voor de JSON
	var save_dict: Dictionary = {
		"currency_1": meta_resource.currency_1 if "currency_1" in meta_resource else 0,
		"currency_2": meta_resource.currency_2 if "currency_2" in meta_resource else 0,
		"currency_3": meta_resource.currency_3 if "currency_3" in meta_resource else 0,
		"skills_data": meta_resource.skills_data if "skills_data" in meta_resource else {}
	}
	
	var file = FileAccess.open(slot_dir + "meta_data.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_dict, "\t"))
		file.close()
		print("Meta progressie inclusief alle upgrades succesvol opgeslagen op schijf!")


func load_meta_progress(meta_resource: Resource) -> void:
	if Game.active_save_slot == "": return
	var full_path: String = "user://" + Game.active_save_slot + "/meta_data.json"
	
	if not FileAccess.file_exists(full_path): 
		print("Geen bestaande meta-data gevonden. We starten op 0.")
		if "currency_1" in meta_resource: meta_resource.currency_1 = 0
		if "currency_2" in meta_resource: meta_resource.currency_2 = 0
		if "currency_3" in meta_resource: meta_resource.currency_3 = 0
		if "skills_data" in meta_resource: meta_resource.skills_data = {}
		return
		
	var file = FileAccess.open(full_path, FileAccess.READ)
	var json_string: String = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	if json.parse(json_string) == OK:
		var save_dict: Dictionary = json.get_data()
		if save_dict.has("currency_1"): meta_resource.currency_1 = save_dict["currency_1"]
		if save_dict.has("currency_2"): meta_resource.currency_2 = save_dict["currency_2"]
		if save_dict.has("currency_3"): meta_resource.currency_3 = save_dict["currency_3"]
		if save_dict.has("skills_data"): meta_resource.skills_data = save_dict["skills_data"]
		print("Meta-progressie succesvol ingeladen!")


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
				if save_dict.has("skills_data"): meta_res.skills_data = save_dict["skills_data"]
			file.close()
	return meta_res


# GECORRIGEERD: Krijgt de exacte in-game speeltijd door van het level zelf!
func add_and_save_run_loot(xp_won: int, currency_won: int, run_time_in_seconds: float) -> void:
	if Game.active_save_slot == "": return
	var current_meta = get_loaded_meta_progress()
	
	# 1. Schrijf de verdiende buit van de afgelopen run bij
	current_meta.currency_1 += xp_won
	current_meta.currency_2 += currency_won
	
	# 2. BEREKEN DE ACTIEVE SPEELTIJD (Geen invloed van het hoofdmenu!)
	# We rekenen de seconden om naar hele minuten (geen fracties, naar beneden afgerond)
	var total_minutes: int = floor(run_time_in_seconds / 60.0)
	print("TIJDSDRUK RUN STATS: De run duurde exact ", total_minutes, " hele minuten in-game.")
	
	#3 PAS DE TERUGLOOP DYNAMISCH TOE OP BASIS VAN INSPECTOR INSTELLINGEN
	if total_minutes > 0:
		for slot_name in current_meta.skills_data.keys():
			var skill_info = current_meta.skills_data[slot_name]
			if skill_info is Dictionary and skill_info.has("level"):
				var current_level = skill_info["level"]
				
				# Haal de verlies-snelheid dynamisch op uit de opgeslagen data (Inspector waarde)
				var loss_rate: int = skill_info["loss_per_minute"] if skill_info.has("loss_per_minute") else 1
				
				# Berekening: minuten gespeeld * jouw ingevoerde verliesfactor
				var points_to_deduct: int = total_minutes * loss_rate
				
				if points_to_deduct > 0:
					var new_level = max(0, current_level - points_to_deduct)
					current_meta.skills_data[slot_name]["level"] = new_level
					print("-> ", slot_name, " verloor ", points_to_deduct, " punten (Tempo: ", loss_rate, "/min). Stand: ", new_level, "/100")
	
	# 4. Sla de definitieve stand met de tijdaftrek nu pas veilig op
	save_meta_progress(current_meta)



# --- 2. TIJDELIJKE RUN SAVE LOGICA (SPELER & WERELD STATUS) ---

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
		print("Autosave! Huidige run succesvol geparkeerd.")


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
				if damage_list.has(target.name):
					var damage_to_apply = damage_list[target.name]
					
					# REPARATIE: In plaats van take_damage te herhalen (wat dubbele hits geeft),
					# overschrijven we de HP van het blokje direct mathematisch puur!
					if "current_health" in target and "max_health" in target:
						target.current_health = target.max_health - damage_to_apply
						
						# Als de HP hierdoor op of onder de 0 komt, ruimen we hem direct netjes op
						if target.current_health <= 0:
							target.queue_free()
				else:
					# Als een blokje helemaal ontbreekt in de lijst, was hij al dood
					target.queue_free()


func delete_current_run_save() -> void:
	if Game.active_save_slot == "": return
	var full_path: String = "user://" + Game.active_save_slot + "/current_run.json"
	if FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)
