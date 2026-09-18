extends CanvasLayer

func _ready() -> void:
	# DIT menu blijft ALTIJD wakker, ook als de rest van de wereld bevriest
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


# De ultieme invoer-luisteraar van de engine zelf. Dit werkt ALTIJD, 
# ook al staat de CanvasLayer op visible = false!
func _notification(what: int) -> void:
	# NOTIFICATION_WM_GO_BACK_REQUEST reageert op Escape (en de Back-knop op controllers/telefoons)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle_pause()


# Handmatige keyboard-fallback voor PC (voor het geval de OS-layer ui_cancel prefereert)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if not event.is_echo() and event.is_pressed():
			# Vertel Godot direct dat deze toets hier is opgebruikt, 
			# zodat hij niet per ongeluk een 2e keer kan vuren!
			get_tree().root.set_input_as_handled()
			toggle_pause()


# De centrale toggle functie die de boel bevriest of ontdooit
func toggle_pause() -> void:
	get_tree().paused = !get_tree().paused
	visible = get_tree().paused
	print("Pauzestand gewijzigd binnen Pauzemenu! Stand is nu: ", get_tree().paused)


# --- LOGICA VOOR DE UI KNOPPEN ---

func _on_continue_button_pressed() -> void:
	toggle_pause()

func _on_main_menu_button_pressed() -> void:
	# EERST zoeken we de speler en slaan we de run + wereldstatus op!
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		var save_system = load("res://Systems/SaveSystem.gd").new()
		save_system.save_current_run(player)
	else:
		push_error("Fout: Kon de player node niet vinden om op te slaan!")
		
	# PAS DAARNA halen we de game van pauze af en wisselen we van scène!
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")

# 3. SURRENDER BUTTON: Run definitief stoppen en buit incasseren
func _on_surrender_button_pressed() -> void:
	var player = get_tree().current_scene.find_child("Player", true, false)
	if player:
		var save_system = load("res://Systems/SaveSystem.gd").new()
		# Verwerk de buit permanent en wis de tijdelijke run-save
		save_system.add_and_save_run_loot(player.run_xp_earned, player.run_currency_earned)
		save_system.delete_current_run_save()
		
	# Pas op het allerlaatst wisselen naar het hoofdmenu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
