extends Control

# --- GECORRIGEERD: Main Menu Opstart-as ---
func _ready() -> void:
	# Bepaal of er een actieve run openstaat op de schijf (Net als bij jullie Continue-knop!)
	var slot_folder = "user://" + Game.active_save_slot + "/"
	var run_file = slot_folder + "current_run.json"
	var has_active_run: bool = FileAccess.file_exists(run_file)
	
	# Zoek de Skill Tree knop op in het hoofdmenu
	# Pas deze naam aan als jullie knop in de scèneboom anders heet (bijv. SkillTreeButton)
	var skill_tree_btn = find_child("SkillTreeButton", true, false) as Button
	if not is_instance_valid(skill_tree_btn):
		skill_tree_btn = find_child("*Skill*", true, false) as Button
		
	if is_instance_valid(skill_tree_btn):
		# JOUW LOGICA: De Skill Tree is UITSLUITEND zichtbaar als er GEEN actieve run draait!
		skill_tree_btn.visible = not has_active_run
		print("MAIN MENU: Skill Tree knop zichtbaarheid ingesteld op: ", skill_tree_btn.visible)



# --- SAMENGEVOEGD: De Sluitende Continue Motor ---
func _on_continue_button_pressed() -> void:
	print("MAIN MENU: Continue geactiveerd. Laden van bestaande run...")
	
	var full_path = "user://" + Game.active_save_slot + "/current_run.json"
	
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			var run_data = json.get_data()
			
			# SSoT GEHEUGENSTREEK: Haal de opgeslagen Ring en Kamer live van de schijf!
			if is_instance_valid(LevelManager):
				if run_data.has("current_layer"):
					LevelManager.current_layer = int(run_data["current_layer"])
				elif run_data.has("level_index"): 
					LevelManager.current_layer = int(run_data["level_index"])
					
				if run_data.has("current_room_index"):
					LevelManager.current_room_index = int(run_data["current_room_index"])
				elif run_data.has("room_index"):
					LevelManager.current_room_index = int(run_data["room_index"])
					
				print("MAIN MENU: Locatie succesvol hersteld! Router gezet op Ring: ", LevelManager.current_layer, " | Kamer: ", LevelManager.current_room_index)
		file.close()
	
	# Vertel de hub en de Player dat we een bestaande run hervatten (dit activeert de pixel-spawn en herstelt de +winst!)
	Game.should_load_run = true
	get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")


# --- GECORRIGEERDE NIEUWE RUN AFHANDELING ---
func _on_new_run_button_pressed() -> void:
	print("MAIN MENU: New Run geactiveerd. Red openstaande buit en forceer schone lei...")
	
	var slot_folder = "user://" + Game.active_save_slot + "/"
	var player_data_path = slot_folder + "Player_Data.tres"
	var run_file = slot_folder + "current_run.json"
	
	# =========================================================================
	# 1. WATERDICHTE SSoT OVERBOEKING: Lees de buit rechtstreeks uit de Live Resource!
	# =========================================================================
	if ResourceLoader.exists(player_data_path):
		var raw_stats = ResourceLoader.load(player_data_path)
		var save_sys = load("res://Systems/SaveSystem.gd").new()
		
		# Als er een run-bestand openstond, halen we de buit uit de Hub metadata
		if FileAccess.file_exists(run_file) and is_instance_valid(Game) and save_sys and save_sys.has_method("get_loaded_meta_progress"):
			var open_olrite = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
			var open_metal  = int(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else 0
			var open_keep   = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
			var open_elem1  = int(Game.get_meta("run_loot_element1")) if Game.has_meta("run_loot_element1") else 0
			var open_elem2  = int(Game.get_meta("run_loot_element2")) if Game.has_meta("run_loot_element2") else 0
			var open_elem3  = int(Game.get_meta("run_loot_element3")) if Game.has_meta("run_loot_element3") else 0
			
			var meta = save_sys.get_loaded_meta_progress()
			if meta and (open_olrite > 0 or open_metal > 0 or open_keep > 0 or open_elem1 > 0 or open_elem2 > 0 or open_elem3 > 0):
				print("-> Openstaande buit gevonden! Boek over naar de Hoofdkluis...")
				
				# Rotsvaste overboeking naar de main wallet variabelen van de kluis
				if "currency_olrite" in meta: meta.currency_olrite += open_olrite
				elif "currency_1" in meta: meta.currency_1 += open_olrite
				
				if "currency_metal" in meta: meta.currency_metal += open_metal
				elif "currency_2" in meta: meta.currency_2 += open_metal
				
				if "currency_keepium" in meta: meta.currency_keepium += open_keep
				elif "currency_3" in meta: meta.currency_3 += open_keep
				
				if "currency_element1" in meta: meta.currency_element1 += open_elem1
				elif "currency_4" in meta: meta.currency_4 += open_elem1
				
				if "currency_element2" in meta: meta.currency_element2 += open_elem2
				elif "currency_5" in meta: meta.currency_5 += open_elem2
				
				if "currency_element3" in meta: meta.currency_element3 += open_elem3
				elif "currency_6" in meta: meta.currency_6 += open_elem3
				
				# Sla de verwerkte buit definitief op naar de harde schijf
				if save_sys.has_method("save_meta_progress"):
					save_sys.save_meta_progress(meta)
					print("-> SSoT: Hoofdsaldo succesvol verhoogd op de harde schijf!")

	# =========================================================================
	# 2. HARD-LOCK RESETS & SCHONE LEI CONFORM BLUEPRINT
	# =========================================================================
	print("MAIN MENU: Start de hard-lock resets...")
	if is_instance_valid(Game):
		Game.set_meta("run_loot_olrite", 0)
		Game.set_meta("run_loot_metal", 0)
		Game.set_meta("run_loot_keepium", 0)
		Game.set_meta("run_loot_element1", 0)
		Game.set_meta("run_loot_element2", 0)
		Game.set_meta("run_loot_element3", 0)
		Game.should_load_run = false
		
		# Schoon de statusbalken-cache op voor de nieuwe run
		Game.remove_meta("transit_health")
		Game.remove_meta("transit_shield")
		Game.remove_meta("transit_energy")
		
	# Wis de JSON van de schijf zodat continue verdwijnt
	if FileAccess.file_exists(run_file):
		DirAccess.remove_absolute(run_file)
		
	# Reset ook de LevelManager zodat de opbouw vanaf nul begint
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
		
	get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")


func _on_skill_tree_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Systems/SkillTree.tscn")



func _on_new_game_button_pressed() -> void:
	print("MAIN MENU: New Game geactiveerd. Permanente slot-cache wordt gewist...")
	
	# GECORRIGEERD: Wis de permanente schijf-keuze, zodat het pre-menu direct een schone lei start
	var save_system = load("res://Systems/SaveSystem.gd").new()
	if save_system and save_system.has_method("save_last_used_slot"):
		save_system.save_last_used_slot("")
	
	# Schakel nu pas veilig door naar het slot-selectiescherm
	get_tree().change_scene_to_file("res://Systems/pre_menu.tscn")



func _on_exit_button_pressed() -> void:
	get_tree().quit()
