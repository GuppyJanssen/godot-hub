extends Node2D

@onready var barrier_visuals: Node2D = $BarrierVisuals

func _ready() -> void:
	print("GAMEROOM: Kamer succesvol opgestart op Ring: ", LevelManager.current_layer, " Kamer: ", LevelManager.current_room_index)
	
	# Pas de achtergrondkleur live aan op basis van de actieve regio (A, AB, B, etc.)
	var bg_node = $Background as ColorRect
	if bg_node:
		LevelManager.update_room_background(bg_node)
		
	# Zorg dat de barrière direct bij binnenkomst in de juiste stand start
	_check_barriers()


func _process(_delta: float) -> void:
	# Live-controle tijdens elke frame van het spelen
	_check_barriers()


func _check_barriers() -> void:
	if not barrier_visuals: 
		return
	
	# We zoeken net als de speler veilig in beide schrijfwijzen van de vijandengroep
	var enemies_caps = get_tree().get_nodes_in_group("Enemies")
	var enemies_small = get_tree().get_nodes_in_group("enemies")
	var room_is_locked: bool = (enemies_caps.size() > 0) or (enemies_small.size() > 0)
	
	# DE LIVE SWITCH: Als de kamer op slot zit, tonen we de rode randen. 
	# Zodra de laatste vijand sterft, verdwijnen ze onmiddellijk!
	barrier_visuals.visible = room_is_locked
