extends Control

# --- GECORRIGEERD: Main Menu Opstart-as ---
func _ready() -> void:
	# Bepaal of er een actieve run openstaat op de schijf (Net als bij jullie Continue-knop!)
	var has_active_run: bool = SaveSystem.has_current_run()
	
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
	
	var run_data: Dictionary = SaveSystem.read_json(SaveSystem.slot_file(SaveSystem.RUN_FILE))
	if not run_data.is_empty() and is_instance_valid(LevelManager):
		# Ring en kamer uit de save, begrensd tot wat er in de wereld bestaat.
		var max_layer: int = LevelManager.LAYER_WIDTHS.size() - 1
		var layer: int = SaveSystem._safe_int(run_data.get("current_layer", run_data.get("level_index", 0)))
		LevelManager.current_layer = clampi(layer, 0, max_layer)
		var width: int = LevelManager.LAYER_WIDTHS[LevelManager.current_layer]
		var room_index: int = SaveSystem._safe_int(run_data.get("current_room_index", run_data.get("room_index", 0)))
		LevelManager.current_room_index = clampi(room_index, 0, width - 1)
		print("MAIN MENU: Locatie hersteld: Ring ", LevelManager.current_layer, " | Kamer ", LevelManager.current_room_index)

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
	SaveSystem.new().delete_current_run_save()
		
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
