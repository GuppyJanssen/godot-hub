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
	
	# RunState: dode vijanden, gehaalde kamers en speeltijd terughalen.
	# Bestaat er nog geen RunState-bestand (een save van voor deze wijziging), begin dan schoon.
	if not RunState.load_run():
		RunState.start_new_run()
	
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
	# De seed uit het invulveld (leeg = willekeurig). Zelfde seed = zelfde oorlog en kamers.
	print("MAIN MENU: New Run geactiveerd. Red openstaande buit en forceer schone lei...")
	# Stond er nog een run open? Dan gaat die buit eerst naar de kluis, daarna begint de nieuwe run
	# (start_new_run wist RunState.loot). Na een herstart laadt RunState eerst de oude run in.
	if RunState.loot.is_empty() and RunState.has_saved_run():
		RunState.load_run()
	LootResources.bank_run_loot()
	RunState.start_new_run(1, _read_seed())
	
	var slot_folder = "user://" + Game.active_save_slot + "/"
	var run_file = slot_folder + "current_run.json"
	
	# =========================================================================
	# 2. HARD-LOCK RESETS & SCHONE LEI CONFORM BLUEPRINT
	# =========================================================================
	print("MAIN MENU: Start de hard-lock resets...")
	if is_instance_valid(Game):
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


# Leest het seed-veld. Leeg = -1 (willekeurig). Een getal blijft dat getal; tekst (bijvoorbeeld
# "maik") wordt omgerekend naar een getal, zodat ook een woord als seed werkt.
func _read_seed() -> int:
	var field: LineEdit = find_child("SeedInput", true, false) as LineEdit
	if field == null:
		return -1
	var text: String = field.text.strip_edges()
	if text == "":
		return -1
	if text.is_valid_int():
		return absi(text.to_int())
	return absi(hash(text)) % 1000000000
