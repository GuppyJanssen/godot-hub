extends Node2D

# GECORRIGEERD: Dit zorgt ervoor dat SaveSystem direct herkend wordt binnen dit hele script!
@onready var SaveSystem = load("res://Systems/SaveSystem.gd").new()

# De andere variabelen die er al stonden:
var active_run_time: float = 0.0



# --- INGEBOUWDE GODOT FUNCTIES ---
func _ready() -> void:
	print("ZUIDPOOL: Speler start de run op de basisplaneet.")
	
	# INITIALISATIE ACHTERGROND: Dwing direct de start-kleur af via de LevelManager!
	var bg_node = $Background as ColorRect
	if bg_node:
		LevelManager.update_room_background(bg_node)
		
	# (Laat jullie eventuele andere specifieke ready code voor de startscène hieronder gewoon staan!)


func _process(_delta: float) -> void:
	# Live-controle tijdens elke frame van het spelen
	_check_barriers()


func _check_barriers() -> void:
	# We zoeken net als bij de andere scènes veilig in beide groepen naar vijanden
	var enemies_caps = get_tree().get_nodes_in_group("Enemies")
	var enemies_small = get_tree().get_nodes_in_group("enemies")
	var room_is_locked: bool = (enemies_caps.size() > 0) or (enemies_small.size() > 0)
	
	# Toon of verberg de bovenbalk live op basis van de vijanden-lock
	var top_barrier = $BarrierVisuals/TopBarrier as ColorRect
	if top_barrier:
		top_barrier.visible = room_is_locked


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
