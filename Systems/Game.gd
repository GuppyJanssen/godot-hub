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
