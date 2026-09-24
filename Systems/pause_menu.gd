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


func _on_surrender_button_pressed() -> void:
	print("PAUZEMENU: Surrender geactiveerd! Run wordt permanent afgebroken...")
	
	# 1. We zoeken de actieve live player in de arena om zijn buit-buffers op te vragen
	var root_node = get_tree().root
	var active_player = root_node.find_child("Player", true, false)
	
	if active_player and is_instance_valid(active_player):
		# BEZEM DOOR HET OUDE ZEER: We sturen de 6 live grondstoffen direct door naar de permanente bank!
		if save_system.has_method("add_and_save_run_loot"):
			save_system.add_and_save_run_loot(
				active_player.run_currency_olrite,
				active_player.run_currency_gold,
				active_player.run_currency_keepium,
				active_player.run_currency_element1,
				active_player.run_currency_element2,
				active_player.run_currency_element3
			)
		else:
			push_error("PAUZEMENU FOUT: add_and_save_run_loot bestaat niet in het SaveSystem!")
	else:
		print("PAUZEMENU WAARSCHUWING: Geen actieve Player gevonden, buit overdracht overgeslagen.")
		
	# 2. Wis de tijdelijke run-save van de schijf zodat de Continue-knop straks een schone lei laadt
	if save_system.has_method("delete_current_run_save"):
		save_system.delete_current_run_save()
		
	# 3. Schoon de LevelManager-cache onvoorwaardelijk op naar Ring 0 Kamer 0
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
		
	# 4. Ontdooi de game-engine en flits terug naar het Hoofdmenu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


func _on_main_menu_button_pressed() -> void:
	# Bij een normale klik naar het hoofdmenu slaan we de actuele run WEL tussentijds op!
	var root_node = get_tree().root
	var active_player = root_node.find_child("Player", true, false)
	
	if active_player and is_instance_valid(active_player):
		if save_system.has_method("save_current_run"):
			save_system.save_current_run(active_player)
			print("PAUZEMENU: Tussentijdse run-save succesvol weggeschreven.")
			
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
