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
