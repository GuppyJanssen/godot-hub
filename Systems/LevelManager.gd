extends Node
# SINGLE SOURCE OF TRUTH: LevelManager / Router

# Jouw exacte, symmetrische bol-breedtes!
const LAYER_WIDTHS: Array[int] = [1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1]

var current_layer: int = 0       
var current_room_index: int = 0  
var is_loading_from_continue: bool = false


func reset_manager_for_new_run() -> void:
	current_layer = 0
	current_room_index = 0
	is_loading_from_continue = false
	set_meta("last_direction", "up")
	set_meta("player_exit_x", 960.0)
	set_meta("player_exit_y", 1000.0)
	print("LEVEL MANAGER: Router succesvol gereset naar Ring 0.")


func handle_room_transition(direction: String, player_global_x: float) -> void:
	var old_layer = current_layer
	var old_room = current_room_index
	var current_width: int = LAYER_WIDTHS[current_layer]
	is_loading_from_continue = false
	
	match direction:
		"right":
			current_room_index = (current_room_index + 1) % current_width
		"left":
			current_room_index = (current_room_index - 1 + current_width) % current_width
		"up":
			if current_layer < LAYER_WIDTHS.size() - 1:
				current_layer += 1
				var next_width: int = LAYER_WIDTHS[current_layer]
				if next_width > current_width:
					current_room_index = (current_room_index * 2) + (1 if player_global_x >= 960.0 else 0)
				elif next_width < current_width:
					current_room_index = floori(current_room_index / 2.0)
		"down":
			if current_layer > 0:
				current_layer -= 1
				var next_width: int = LAYER_WIDTHS[current_layer]
				if next_width < current_width:
					current_room_index = floori(current_room_index / 2.0)
				elif next_width > current_width:
					current_room_index = (current_room_index * 2) + (1 if player_global_x >= 960.0 else 0)
					
	print("BOL-ROUTER: Reis van [L:", old_layer, " R:", old_room, "] naar [L:", current_layer, " R:", current_room_index, "] via ", direction.to_upper())
	_load_current_room(direction)


func _load_current_room(coming_from_direction: String) -> void:
	set_meta("last_direction", coming_from_direction)
	
	# BINGO: Geen losse scènes meer! We laden ALTIJD de universele game_room
	get_tree().change_scene_to_file("res://World/Levels/game_room.tscn")

	await get_tree().process_frame
	await get_tree().process_frame
	
	if is_instance_valid(Game.active_player):
		if is_loading_from_continue:
			is_loading_from_continue = false
			return
			
		var edge_margin: float = 30.0
		var spawn_pos: Vector2 = Vector2(960, 540)
		var exit_x = get_meta("player_exit_x") if has_meta("player_exit_x") else 960.0
		var exit_y = get_meta("player_exit_y") if has_meta("player_exit_y") else 540.0
		var use_mirror: bool = Game.debug_use_mirror_spawn
		
		match coming_from_direction:
			"right": spawn_pos = Vector2(edge_margin, exit_y if use_mirror else 540.0)
			"left":  spawn_pos = Vector2(1920.0 - edge_margin, exit_y if use_mirror else 540.0)
			"up":    spawn_pos = Vector2(exit_x if use_mirror else 960.0, 1080.0 - edge_margin)
			"down":  spawn_pos = Vector2(exit_x if use_mirror else 960.0, edge_margin)
			
		Game.active_player.global_position = spawn_pos
