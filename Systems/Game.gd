extends Node

# 1. JULLIE ENUMS STAAN HIER BOVENAAN
enum LootType {
	OLRITE,
	METAL,
	KEEPIUM,
	ELEMENT_1,
	ELEMENT_2,
	ELEMENT_3,
	PLACEHOLDER_A,
	PLACEHOLDER_B,
	PLACEHOLDER_C,
	PLACEHOLDER_D,
	PLACEHOLDER_E,
	SPECIAL_BOSS_DROP,
	UPGRADE_TOKEN
}

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
var debug_muzzle_count: int = 14

# BINGO: Hier hoort hij te staan zodat de Gatling-check op regel 135 niet meer crasht!
var debug_is_full_auto: bool = true



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

# GECORRIGEERD: Boekt alle in-game verzamelde run-loot permanent over naar de Skill Tree kluis!
# GECORRIGEERD: Telt de run-winst live op bij de hoofdportemonnee zodra de run stopt!
func transfer_run_loot_to_meta_bank() -> void:
	if not is_instance_valid(active_player): return
	
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var meta = save_system.get_loaded_meta_progress()
	
	if meta:
		print("SSoT BANKREKENING: Bezig met het storten van de run-winst naar de kluis...")
		
		# We halen de live verdiende winst op uit de speler
		var p = active_player
		
		# De harde optelsom: Hoofdsaldo = Hoofdsaldo + Run-Winst!
		meta.currency_1 += p.run_loot_olrite
		meta.currency_2 += p.run_loot_metal
		meta.currency_3 += p.run_loot_keepium
		meta.currency_4 += p.run_loot_element1
		meta.currency_5 += p.run_loot_element2
		meta.currency_6 += p.run_loot_element3
		
		# Sla de nieuwe, permanente kluisstand direct op naar de harde schijf
		save_system.save_meta_progress(meta)
		
		# Synchroniseer de lokale tres resource voor de speler direct mee
		if p.stats:
			p.stats.currency_olrite = meta.currency_1
			p.stats.currency_metal = meta.currency_2
			p.stats.currency_keepium = meta.currency_3
			p.stats.currency_element1 = meta.currency_4
			p.stats.currency_element2 = meta.currency_5
			p.stats.currency_element3 = meta.currency_6
			ResourceSaver.save(p.stats, "res://Resources/Player_Data.tres")
			
		print("SSoT BANKREKENING: Storting succesvol verwerkt!")
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
	
	# Beveilig alle 6 de winst-slots uit de hub metadata
	run_data["run_loot_olrite"] = int(get_meta("run_loot_olrite")) if has_meta("run_loot_olrite") else 0
	run_data["run_loot_metal"]  = int(get_meta("run_loot_metal"))  if has_meta("run_loot_metal")  else 0
	run_data["run_loot_keepium"] = int(get_meta("run_loot_keepium")) if has_meta("run_loot_keepium") else 0
	run_data["run_loot_element1"] = int(get_meta("run_loot_element1")) if has_meta("run_loot_element1") else 0
	run_data["run_loot_element2"] = int(get_meta("run_loot_element2")) if has_meta("run_loot_element2") else 0
	run_data["run_loot_element3"] = int(get_meta("run_loot_element3")) if has_meta("run_loot_element3") else 0
	
	var write_file = FileAccess.open(full_path, FileAccess.WRITE)
	write_file.store_string(JSON.stringify(run_data, "\t"))
	write_file.close()
	print("GLOBAL HUB: Run-state (Positie: ", active_player.global_position, ") waterdicht opgeslagen op schijf!")


# --- SSoT GLOBAL LAAD MOTOR: Dwingt de pixelpositie af bij Continue ---
func load_and_force_continue_position() -> void:
	if not is_instance_valid(active_player): return
	
	var continue_path = "user://" + active_save_slot + "/current_run.json"
	if not FileAccess.file_exists(continue_path): return
	
	var c_file = FileAccess.open(continue_path, FileAccess.READ)
	var c_json = JSON.new()
	if c_json.parse(c_file.get_as_text()) == OK:
		var run_data = c_json.get_data()
		var found_pos = Vector2.ZERO
		var has_x = false
		var has_y = false
		
		if run_data.has("player_x"): found_pos.x = float(run_data["player_x"]); has_x = true
		if run_data.has("player_y"): found_pos.y = float(run_data["player_y"]); has_y = true
		
		# Teleporteer de speler onvoorwaardelijk over alle spawnpoints heen!
		if has_x and has_y and found_pos != Vector2.ZERO:
			active_player.global_position = found_pos
			print("GLOBAL HUB: Speler succesvol geforceerd op pixel: ", found_pos)
			
		# Herstel de 6 winst-benders in de Hub metadata
		set_meta("run_loot_olrite", int(run_data.get("run_loot_olrite", 0)))
		set_meta("run_loot_metal", int(run_data.get("run_loot_metal", 0)))
		set_meta("run_loot_keepium", int(run_data.get("run_loot_keepium", 0)))
		set_meta("run_loot_element1", int(run_data.get("run_loot_element1", 0)))
		run_data["run_loot_element2"] = int(run_data.get("run_loot_element2", 0))
		run_data["run_loot_element3"] = int(run_data.get("run_loot_element3", 0))
	c_file.close()
