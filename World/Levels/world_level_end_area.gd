extends Node2D

func _ready() -> void:
	print("NOORDPOOL: Welkom in de Eindbaas-Arena!")
	
	# Dwing de speciale sfeervolle eindkleur af via de LevelManager
	var bg_node = $Background as ColorRect
	if bg_node:
		LevelManager.update_room_background(bg_node)


func _process(_delta: float) -> void:
	# Live-controle tijdens elke frame van het spelen
	_check_barriers()


func _check_barriers() -> void:
	# We zoeken net als bij de andere scènes veilig in beide groepen naar vijanden/de baas
	var enemies_caps = get_tree().get_nodes_in_group("Enemies")
	var enemies_small = get_tree().get_nodes_in_group("enemies")
	var room_is_locked: bool = (enemies_caps.size() > 0) or (enemies_small.size() > 0)
	
	# Toon of verberg de onderbalk live op basis van de vijanden-lock
	var bottom_barrier = $BarrierVisuals/BottomBarrier as ColorRect
	if bottom_barrier:
		bottom_barrier.visible = room_is_locked
