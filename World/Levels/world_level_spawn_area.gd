extends Node2D

# --- INGEBOUWDE GODOT FUNCTIES ---

# _ready() start exact één keer zodra deze scène wordt opgestart.
func _ready() -> void:
	# 1. Focus loslaten om kapers te voorkomen
	get_viewport().gui_release_focus()
	
	# 2. Player spawnen
	if has_method("spawn_the_player"):
		spawn_the_player()
	
	# 3. Direct laden via Continue (ZONDER await pleisters)
	if Game.should_load_run:
		var player = find_child("Player", true, false)
		if player:
			var save_system = load("res://Systems/SaveSystem.gd").new()
			save_system.load_current_run(player)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var pause_menu = find_child("PauseMenu", true, false)
		if pause_menu:
			pause_menu.toggle_pause()



# --- EIGEN FUNCTIES ---

# Jullie bestaande functie om de speler in de wereld te zetten
func spawn_the_player() -> void:
	# (Hier staat jullie eigen code die de Player instantieert en op de SpawnPoint zet)
	print("Speler succesvol gespawned in de testwereld.")
