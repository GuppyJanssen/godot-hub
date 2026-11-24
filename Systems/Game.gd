extends Node

# 2. HIERONDER VOLGEN JULLIE NORMALE VARIABELEN
var active_player: CharacterBody2D = null
var active_save_slot: String = ""
var debug_use_mirror_spawn: bool = false
var should_load_run: bool = false

# BINGO: Hier staat de nieuwe variabele veilig geparkeerd, buiten de ready-functie!
var active_weapon_key: String = "weapon_pistol"

# --- F1 LIVE PHYSICS MULTIPLIERS ---
var debug_is_invincible: bool = false
var debug_damage_multiplier: float = 1.0
var debug_current_speed_multiplier: float = 1.0
var debug_max_speed_multiplier: float = 1.0
var debug_acceleration_multiplier: float = 1.0
var debug_friction_multiplier: float = 1.0
var debug_bullet_speed_multiplier: float = 1.0
var debug_bullet_size_multiplier: float = 1.0
var debug_range_multiplier: float = 1.0
var debug_muzzle_count: int = 0  # 0 = het aantal uit de SSOT (base_muzzle_count)


# 3. JULLIE BESTAANDE READY FUNCTIE (BLIJFT 100% INTACT)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GAME HUB: Globals succesvol geïnitialiseerd. Cockpit staat live.")
	
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var remembered_slot = save_system.load_last_used_slot()
	
	if remembered_slot != "":
		active_save_slot = remembered_slot
		get_tree().call_deferred("change_scene_to_file", "res://Systems/main_menu.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Systems/pre_menu.tscn")


# --- SSoT GLOBAL SAVE ENGINE: Beveiligt live X/Y coördinaten en de 6 winst-tellers ---
func save_live_run_state_to_disk() -> void:
	if not is_instance_valid(active_player): return
	
	var slot_folder = "user://" + active_save_slot + "/"
	var full_path = slot_folder + "current_run.json"
	var run_data = {}
	
	# Laad bestaande data in zodat we kamer-indexen niet per ongeluk wissen
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			run_data = json.get_data()
		file.close()
		
	# Injecteer de exacte pixelcoördinaten van DIT specifieke frame
	run_data["current_layer"] = LevelManager.current_layer
	run_data["current_room_index"] = LevelManager.current_room_index
	run_data["player_x"] = active_player.global_position.x
	run_data["player_y"] = active_player.global_position.y
	
	# De run-buit staat in RunState (run_state.json), niet hier.
	
	var write_file = FileAccess.open(full_path, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(run_data, "\t"))
	write_file.close()
	print("GLOBAL HUB: Run-state (Positie: ", active_player.global_position, ") waterdicht opgeslagen op schijf!")
