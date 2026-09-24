extends CanvasLayer
# BEDIENING: Pauzemenu & Run Beëindiging (Volledig SSoT & Crashvrij)

@onready var save_system = load("res://Systems/SaveSystem.gd").new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Esc-toets
		toggle_pause()


func toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	visible = get_tree().paused
	if visible:
		print("PAUZEMENU: Game gepauzeerd.")


func _on_continue_button_pressed() -> void:
	toggle_pause()


# --- GECORRIGEERD: Main Menu Knop Slaat Nu Foutloos Op Via De Global Hub ---
func _on_main_menu_button_pressed() -> void:
	print("PAUZEMENU: Terugkeren naar Hoofdmenu via handmatige verlaat-knop. Run-state opslaan...")
	
	if is_instance_valid(Game) and is_instance_valid(Game.active_player):
		var slot_folder = "user://" + Game.active_save_slot + "/"
		var full_path = slot_folder + "current_run.json"
		var run_data = {}
		
		# Vul de JSON-save met de exacte live-coördinaten en de buit-stand van dit frame
		run_data["current_layer"] = LevelManager.current_layer
		run_data["current_room_index"] = LevelManager.current_room_index
		run_data["player_x"] = Game.active_player.global_position.x
		run_data["player_y"] = Game.active_player.global_position.y
		
		run_data["run_loot_olrite"] = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
		run_data["run_loot_metal"]  = int(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else 0
		run_data["run_loot_keepium"] = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
		
		var write_file = FileAccess.open(full_path, FileAccess.WRITE)
		if write_file:
			write_file.store_string(JSON.stringify(run_data, "\t"))
			write_file.close()
			print("PAUZEMENU: Run succesvol gebrand op schijf voor Continue.")
			
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")



# --- GECORRIGEERD: Surrender Knop Volledig Foutloos Zonder Shadowing Conflict ---
func _on_surrender_button_pressed() -> void:
	print("PAUZEMENU: Surrender geactiveerd! Run wordt permanent afgebroken...")
	
	# 1. OPTELSOM NAAR HOOFD-PORTEMONNEE (Kogelvrije boeking via de Meta Progress)
	if save_system and save_system.has_method("get_loaded_meta_progress") and is_instance_valid(Game):
		var meta = save_system.get_loaded_meta_progress()
		if meta:
			print("PAUZEMENU BANK: Bezig met storten van run-loot naar Meta-Kluis...")
			
			# BINGO: Haal eerst alle 6 de live run-winst tellers loepzuiver op uit de Global Hub metadata!
			var w_olrite = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
			var w_metal  = int(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else 0
			var w_keep   = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
			var w_elem1  = int(Game.get_meta("run_loot_element1")) if Game.has_meta("run_loot_element1") else 0
			var w_elem2  = int(Game.get_meta("run_loot_element2")) if Game.has_meta("run_loot_element2") else 0
			var w_elem3  = int(Game.get_meta("run_loot_element3")) if Game.has_meta("run_loot_element3") else 0
			
			# A: We verhogen de waarden in de Meta Progress kluis van de Skill Tree
			if "currency_olrite" in meta: meta.currency_olrite += w_olrite
			elif "currency_1" in meta: meta.currency_1 += w_olrite
			
			if "currency_metal" in meta: meta.currency_metal += w_metal
			elif "currency_2" in meta: meta.currency_2 += w_metal
			
			if "currency_keepium" in meta: meta.currency_keepium += w_keep
			elif "currency_3" in meta: meta.currency_3 += w_keep
			
			if "currency_element1" in meta: meta.currency_element1 += w_elem1
			elif "currency_4" in meta: meta.currency_4 += w_elem1
			
			if "currency_element2" in meta: meta.currency_element2 += w_elem2
			elif "currency_5" in meta: meta.currency_5 += w_elem2
			
			if "currency_element3" in meta: meta.currency_element3 += w_elem3
			elif "currency_6" in meta: meta.currency_6 += w_elem3
			
			if save_system.has_method("save_meta_progress"):
				save_system.save_meta_progress(meta)

			# B: Synchroniseer de nieuwe wallet-stand direct met de harde .tres kluis van deze slot!
			# Dit zorgt ervoor dat Player.gd bij een New Run de buit direct op zijn scherm toont.
			if is_instance_valid(Game.active_player) and Game.active_player.stats:
				var p_stats = Game.active_player.stats
				
				# Overschrijf de resource-waarden met de zojuist verhoogde meta-waarden
				p_stats.currency_olrite = meta.currency_olrite if "currency_olrite" in meta else (meta.currency_1 if "currency_1" in meta else p_stats.currency_olrite + w_olrite)
				p_stats.currency_metal = meta.currency_metal if "currency_metal" in meta else (meta.currency_2 if "currency_2" in meta else p_stats.currency_metal + w_metal)
				p_stats.currency_keepium = meta.currency_keepium if "currency_keepium" in meta else (meta.currency_3 if "currency_3" in meta else p_stats.currency_keepium + w_keep)
				p_stats.currency_element1 = meta.currency_element1 if "currency_element1" in meta else (meta.currency_4 if "currency_4" in meta else p_stats.currency_element1 + w_elem1)
				p_stats.currency_element2 = meta.currency_element2 if "currency_element2" in meta else (meta.currency_5 if "currency_5" in meta else p_stats.currency_element2 + w_elem2)
				p_stats.currency_element3 = meta.currency_element3 if "currency_element3" in meta else (meta.currency_6 if "currency_6" in meta else p_stats.currency_element3 + w_elem3)
				
				# Brand de geüpdatete portemonnee direct definitief op de harde schijf van de actieve slot
				var slot_folder = "user://" + Game.active_save_slot + "/"
				ResourceSaver.save(p_stats, slot_folder + "Player_Data.tres")
				print("PAUZEMENU BANK: Slot-resource succesvol gelijkgetrokken met Meta Progress!")


	# 2. Wis de fysieke JSON-save van de harde schijf
	if save_system and save_system.has_method("delete_current_run_save"):
		save_system.delete_current_run_save()
		print("PAUZEMENU: Tijdelijke JSON run-save met succes van schijf gewist.")
		
	# Geef het OS één frame ademruimte om de schijf-afhandeling te voltooien
	await get_tree().process_frame

	# 3. Router onvoorwaardelijk resetten voor Ring 0 Kamer 0
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
		
	# 4. GECORRIGEERD: Ontdooi de game-engine en flits direct terug naar het hoofdmenu!
	get_tree().paused = false
	print("PAUZEMENU: Terugkeren naar het hoofdmenu...")
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
