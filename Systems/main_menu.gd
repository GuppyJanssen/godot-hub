extends Control

# --- GECORRIGEERD: Main Menu Opstart-as ---
func _ready() -> void:
	print("MAIN MENU: Hoofdmenu geladen voor slot: ", Game.active_save_slot)
	
	# Forceer direct dat de hub weet dat we de run niet automatisch kapen, tenzij we op continue drukken
	Game.should_load_run = false
	
	var continue_btn = find_child("ContinueButton", true, false) as Button
	if not continue_btn:
		continue_btn = find_child("*Continue*", true, false) as Button
		
	if is_instance_valid(continue_btn):
		var slot_folder = "user://" + Game.active_save_slot + "/"
		var path_camel = slot_folder + "current_run.json"
		var path_lower = "user://" + Game.active_save_slot.to_lower() + "/current_run.json"
		
		# HIER GECORRIGEERD: We kijken UITSLUITEND of het bestand fysiek op de schijf bestaat!
		var file_exists: bool = FileAccess.file_exists(path_camel) or FileAccess.file_exists(path_lower)
		
		if file_exists:
			continue_btn.visible = true
			print("MAIN MENU: Fysieke run-save gevonden. Continue is ZICHTBAAR.")
		else:
			continue_btn.visible = false
			print("MAIN MENU: Geen run-save gevonden op de schijf. Continue is ONZICHTBAAR.")


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


# --- GECORRIGEERD: De Beveiligde New Run Opschoner ---
func _on_new_run_button_pressed() -> void:
	print("MAIN MENU: New Run geactiveerd. Forceer schone lei...")
	
	# HARD-LOCK RESETS: Wis de runtime-buffers in de Global Hub onvoorwaardelijk naar 0!
	# Dit garandeert dat de run start met (+0) winst op je scherm.
	if is_instance_valid(Game):
		Game.set_meta("run_loot_olrite", 0)
		Game.set_meta("run_loot_metal", 0)
		Game.set_meta("run_loot_keepium", 0)
		Game.set_meta("run_loot_element1", 0)
		Game.set_meta("run_loot_element2", 0)
		Game.set_meta("run_loot_element3", 0)
		Game.should_load_run = false
		
	# Wis ook de JSON van de schijf zodat continue wegblijft
	var slot_folder = "user://" + Game.active_save_slot + "/"
	var run_file = slot_folder + "current_run.json"
	if FileAccess.file_exists(run_file):
		DirAccess.remove_absolute(run_file)
		
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
