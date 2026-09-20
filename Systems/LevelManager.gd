extends Node

# 1. DE CONFIGURATIE VAN DE BOL (Telling klopt exact!)
const LAYER_WIDTHS: Array[int] = [1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1]

# 2. DE ACTUELE REIS-POSITIE
var current_layer: int = 0       # 0 = Startplaneet, 5 = Evenaar, 10 = Eindkamer
var current_room_index: int = 0  # Welke kamer binnen de huidige ring

# 3. FUTURE-PROOF SCHAKELAARS VOOR DE GROEP
var spawn_in_center_on_vertical: bool = true

# Wordt aangeroepen door Player.gd zodra hij een schermrand verlaat
func handle_room_transition(direction: String, player_global_x: float) -> void:
	var old_layer = current_layer
	var old_room = current_room_index
	
	var current_width: int = LAYER_WIDTHS[current_layer]
	
	match direction:
		"right":
			# Horizontale cirkel: als je rechts de kamer uitloopt, ga je naar de volgende kamer
			current_room_index = (current_room_index + 1) % current_width
			
		"left":
			# Horizontale cirkel: links de kamer uitlopen (veilig omgaan met negatieve getallen)
			current_room_index = (current_room_index - 1 + current_width) % current_width
			
		"up":
			if current_layer < LAYER_WIDTHS.size() - 1:
				current_layer += 1
				var next_width: int = LAYER_WIDTHS[current_layer]
				
				# TRECHTER OMHOOG (Up-scaling of overgang naar de polen)
				if next_width > current_width:
					# Bepaal of de speler links of rechts van het midden vloog
					var is_right_side: bool = player_global_x >= 960.0
					current_room_index = (current_room_index * 2) + (1 if is_right_side else 0)
				elif next_width < current_width:
					# Krimp-laag boven de evenaar: 2 kamers smelten samen naar 1
					current_room_index = current_room_index / 2
				else:
					# Als ringen even breed zouden zijn (niet van toepassing bij ons)
					pass
					
		"down":
			if current_layer > 0:
				current_layer -= 1
				var next_width: int = LAYER_WIDTHS[current_layer]
				
				# TRECHTER OMLAAG (Down-scaling of overgang naar de polen)
				if next_width < current_width:
					# Je zakactie voegt automatisch 2 kamers samen naar de juiste onderliggende index
					current_room_index = current_room_index / 2
				elif next_width > current_width:
					# Krimp-laag onder de evenaar omgekeerd: 1 kamer splitst naar 2 op basis van X
					var is_right_side: bool = player_global_x >= 960.0
					current_room_index = (current_room_index * 2) + (1 if is_right_side else 0)
					
	print("TRANSITIE: Van [L:", old_layer, " R:", old_room, "] naar [L:", current_layer, " R:", current_room_index, "] via ", direction.to_upper())
	
	# Start het inladen van de nieuwe kamer scène
	_load_current_room(direction)


func _load_current_room(coming_from_direction: String) -> void:
	# Sla de reisrichting tijdelijk op in het geheugen voor de speler-spawn
	set_meta("last_direction", coming_from_direction)
	
	# Bepaal het index-nummer van de allerlaatste laag (de Noordpool)
	var max_layer_index = LAYER_WIDTHS.size() - 1
	
	# DE SLIMME ROUTER: Welke scène moet Godot nu fysiek gaan inladen?
	if current_layer == 0:
		# SITUATIE A: We reizen naar de Zuidpool
		print("ROUTER: Unieke Zuidpool-scène inladen...")
		get_tree().change_scene_to_file("res://World/Levels/world_level_spawn_area.tscn")
		
	elif current_layer == max_layer_index:
		# SITUATIE B: We reizen naar de Noordpool (Eindkamer)
		print("ROUTER: Unieke Noordpool-scène inladen...")
		get_tree().change_scene_to_file("res://World/Levels/world_level_end_area.tscn")
		
	else:
		# SITUATIE C: We reizen door de 9 ringen -> Laad de universele Roguelike kamer!
		print("ROUTER: Universele procedurele GameRoom inladen... (Ring: ", current_layer, " Kamer: ", current_room_index, ")")
		get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")


# Geeft de exacte start-coördinaten voor de speler terug in de nieuwe kamer
func get_spawn_position(entered_from_direction: String) -> Vector2:
	var spawn_pos: Vector2 = Vector2(960, 540) # Standaard midden van het scherm
	
	match entered_from_direction:
		"right": # Je kwam van rechts, dus je begint LINKS op het scherm
			spawn_pos.x = 50
			spawn_pos.y = 540
		"left": # Je kwam van links, dus je begint RECHTS op het scherm
			spawn_pos.x = 1870
			spawn_pos.y = 540
		"up": # Je ging omhoog, dus je start ONDERIN het scherm
			spawn_pos.x = 960.0 if spawn_in_center_on_vertical else get_viewport().get_mouse_position().x
			spawn_pos.y = 1000
		"down": # Je ging omlaag, dus je start BOVENIN het scherm
			spawn_pos.x = 960.0 if spawn_in_center_on_vertical else get_viewport().get_mouse_position().x
			spawn_pos.y = 50
			
	return spawn_pos
