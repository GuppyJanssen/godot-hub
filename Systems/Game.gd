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
var debug_fire_rate_multiplier: float = 1.0  # F1: 2 = twee keer zo snel schieten
var debug_weapon_mode: int = 0  # 0 = SSOT (het wapen bepaalt het), 1 = altijd auto, 2 = altijd semi
var debug_muzzle_count: int = 0  # 0 = het aantal uit de SSOT (base_muzzle_count)


# 3. JULLIE BESTAANDE READY FUNCTIE (BLIJFT 100% INTACT)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GAME HUB: Globals succesvol geïnitialiseerd. Cockpit staat live.")
	
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var remembered_slot = save_system.load_last_used_slot()
	
	# load_last_used_slot geeft alleen een geldige slotnaam terug (Slot_1 t/m Slot_3).
	if remembered_slot != "":
		active_save_slot = remembered_slot
		get_tree().call_deferred("change_scene_to_file", "res://Systems/main_menu.tscn")
	else:
		get_tree().call_deferred("change_scene_to_file", "res://Systems/pre_menu.tscn")


# Slaat de plek van de speler op (bij "terug naar hoofdmenu"). Het echte werk doet de speler
# zelf, via SaveSystem (veilig pad, atomisch schrijven). Hier stond eerst een kopie van die code.
func save_live_run_state_to_disk() -> void:
	if is_instance_valid(active_player) and active_player.has_method("save_live_run_state_to_disk"):
		active_player.save_live_run_state_to_disk()
