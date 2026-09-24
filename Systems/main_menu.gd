extends Control

func _ready() -> void:
	get_viewport().gui_release_focus()
	
	# WATERDICHTE HUD-OPRUIMING: Wist de visuele teller-balk onvoorwaardelijk van het scherm!
	var root_node = get_tree().root
	if root_node:
		var oude_hud = root_node.find_child("*hud*", true, false)
		if oude_hud:
			oude_hud.queue_free()
			print("MAIN MENU: Oude run-HUD succesvol van het scherm gewist.")



func _on_continue_button_pressed() -> void:
	print("MAIN MENU: Continue geactiveerd. Run laden van schijf...")
	get_tree().paused = false
	Game.should_load_run = true
	
	# GECORRIGEERD: Zorg dat we 'game_room.tscn' onvoorwaardelijk inladen, 
	# de LevelManager logica stuurt de player dadelijk zelf naar de juiste ring!
	get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")



func _on_skill_tree_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Systems/SkillTree.tscn")



func _on_new_run_button_pressed() -> void:
	print("MAIN MENU: New Run geactiveerd. Forceer schone schijf...")
	
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
		# BINGO: We wissen de opgeslagen achtergrond-cache zodat de nieuwe run een FRISSE random keuze krijgt!
		if LevelManager.has_meta("active_run_background"):
			LevelManager.remove_meta("active_run_background")
		
	get_tree().paused = false
	get_viewport().gui_release_focus()
	Game.should_load_run = false
	
	var active_slot = Game.active_save_slot if Game.active_save_slot != "" else "Slot_3"
	var run_file_path = "user://" + active_slot + "/current_run.json"
	
	if DirAccess.dir_exists_absolute("user://" + active_slot):
		if FileAccess.file_exists(run_file_path):
			DirAccess.remove_absolute(run_file_path)
			print("MAIN MENU: Oude run-cache met succes van de harde schijf GEWIST.")
			
	get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")

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
