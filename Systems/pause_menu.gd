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
		# Pauze = momentopname (Daan, 26 nov): de hele kamer (vijanden, kogels, loot, ...) en het schip
		# met zijn vaart worden opgeslagen, als een autosave. Afsluiten en Continue gaat dus precies
		# verder; pauzeren levert niets op. De kluis en skills (meta_data) worden niet aangeraakt.
		_save_snapshot()


## Schrijft de huidige stand van de run weg voor Continue (zie toggle_pause en terug naar hoofdmenu).
func _save_snapshot() -> void:
	if not (is_instance_valid(Game) and is_instance_valid(Game.active_player)) or not RunState.active:
		return
	Game.save_live_run_state_to_disk()
	RunState.ring = LevelManager.current_layer
	RunState.room = LevelManager.current_room_index
	RunState.player_position = Game.active_player.global_position
	var room_scene = get_tree().current_scene
	if room_scene and room_scene.has_method("snapshot_room"):
		room_scene.snapshot_room()
	RunState.save()


func _on_continue_button_pressed() -> void:
	toggle_pause()


# --- GECORRIGEERD: Main Menu Knop Slaat Nu Foutloos Op Via De Global Hub ---
func _on_main_menu_button_pressed() -> void:
	print("PAUZEMENU: Terugkeren naar Hoofdmenu via handmatige verlaat-knop. Run-state opslaan...")
	
	if is_instance_valid(Game) and is_instance_valid(Game.active_player):
		# Bestaande save: positie en alle 6 de loot-tellers. Deze functie vult het bestand aan
		# in plaats van het te overschrijven, dus de rest van de run blijft bewaard.
		Game.save_live_run_state_to_disk()
		
		# RunState: dode vijanden, gehaalde kamers en speeltijd.
		RunState.ring = LevelManager.current_layer
		RunState.room = LevelManager.current_room_index
		RunState.player_position = Game.active_player.global_position
		# Leg vast wat er in deze kamer ligt en leeft (alles in de groep "saveable").
		var room_scene = get_tree().current_scene
		if room_scene and room_scene.has_method("snapshot_room"):
			room_scene.snapshot_room()
		RunState.save()
		print("PAUZEMENU: Run succesvol gebrand op schijf voor Continue.")
			
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")



# --- GECORRIGEERD: Surrender Knop Volledig Foutloos Zonder Shadowing Conflict ---
func _on_surrender_button_pressed() -> void:
	print("PAUZEMENU: Surrender geactiveerd! Run wordt permanent afgebroken...")
	
	# 1. De buit van deze run gaat naar de kluis (zie LootResources).
	LootResources.bank_run_loot()
	# Wis de statusbalken-cache bij opgeven.
	Game.remove_meta("transit_health")
	Game.remove_meta("transit_shield")
	Game.remove_meta("transit_energy")


	# 2. Wis de fysieke JSON-save van de harde schijf
	if save_system and save_system.has_method("delete_current_run_save"):
		save_system.delete_current_run_save()
		print("PAUZEMENU: Tijdelijke JSON run-save met succes van schijf gewist.")
	
	# RunState afsluiten: wist de dodenlijst, de gehaalde kamers en de speeltijd van deze run.
	RunState.end_run()
		
	# Geef het OS één frame ademruimte om de schijf-afhandeling te voltooien
	await get_tree().process_frame

	# 3. Router onvoorwaardelijk resetten voor Ring 0 Kamer 0
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
		
	# 4. GECORRIGEERD: Ontdooi de game-engine en flits direct terug naar het hoofdmenu!
	get_tree().paused = false
	print("PAUZEMENU: Terugkeren naar het hoofdmenu...")
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
