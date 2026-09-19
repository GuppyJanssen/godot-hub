extends Node2D

# GECORRIGEERD: Dit zorgt ervoor dat SaveSystem direct herkend wordt binnen dit hele script!
@onready var SaveSystem = load("res://Systems/SaveSystem.gd").new()

# De andere variabelen die er al stonden:
var active_run_time: float = 0.0



# --- INGEBOUWDE GODOT FUNCTIES ---

# _ready() start exact één keer zodra deze scène wordt opgestart.
func _ready() -> void:
	# 1. Focus loslaten om kapers te voorkomen
	get_viewport().gui_release_focus()
	
	# 2. Roep jullie spawn-functie op de normale manier aan
	spawn_the_player()


func _process(delta: float) -> void:
	active_run_time += delta
	
	# GECORRIGEERD: We laden de run direct en zetten de vlag DAARNA METEEN op false!
	if Game.should_load_run:
		var player = find_child("Player", true, false)
		if player:
			# Zet de vlag DIRECT uit zodat deze if-statement NU stopt en NOOIT meer herhaalt!
			Game.should_load_run = false
			
			var save_system = load("res://Systems/SaveSystem.gd").new()
			save_system.load_current_run(player)
			print("Continue succesvol verwerkt. De laad-vlag is nu veilig vergrendeld op false.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = find_child("PauseMenu", true, false)
		if pause_menu:
			pause_menu.toggle_pause()


# --- EIGEN FUNCTIES & SIGNALEN ---

# Bestaande functie om de speler in de wereld te zetten
func spawn_the_player() -> void:
	# (Hier staat jullie eigen code die de Player instantieert en op de SpawnPoint zet)
	print("Speler succesvol gespawned in de testwereld.")


# Wanneer de speler op SURRENDER klikt of de run eindigt:
func _on_surrender_button_pressed() -> void:
	# REPARATIE: We moeten de Player node eerst even opzoeken in de wereld
	# om zijn verdiende XP en Currency te kunnen uitlezen!
	var player = find_child("Player", true, false)
	
	var xp_earned: int = 0
	var currency_earned: int = 0
	
	if player:
		xp_earned = player.run_xp_earned
		currency_earned = player.run_currency_earned
	else:
		push_warning("Waarschuwing: Player node niet gevonden tijdens Surrender!")
	
	# We sturen de buit ÉN de exacte in-game speeltijd mee naar de manager!
	SaveSystem.add_and_save_run_loot(xp_earned, currency_earned, active_run_time)
	
	# Haal de tijdelijke run-save weg en ga terug naar het menu
	SaveSystem.delete_current_run_save()
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
