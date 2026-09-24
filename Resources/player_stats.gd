extends Resource
class_name PlayerStats

@export_category("Gezondheid & Energie")
@export var max_health: int = 100
@export var current_health: int = 100
@export var max_shield: int = 50
@export var current_shield: int = 50
@export var max_energy: int = 100
@export var current_energy: int = 100

@export_category("Live Portemonnee (Run)")
@export var currency_olrite: int = 0      # Currency 1 (XP / Groen)
@export var currency_gold: int = 0        # Currency 2 (Metal / Grijs)
@export var currency_keepium: int = 0     # Currency 3 (Paars)
@export var currency_element1: int = 0    # Currency 4 (Blauw)
@export var currency_element2: int = 0    # Currency 5 (Geel)
@export var currency_element3: int = 0    # Currency 6 (Rood)

@export_category("Live Beweging (Run)")
@export var current_speed: float = 300.0
@export var current_acceleration: float = 1200.0
@export var current_friction: float = 1200.0
@export var current_rotation_speed: float = 10.0
@export var dash_enabled: bool = false

@export_category("Magneet & Buit")
@export var current_pickup_radius: float = 30.0    # Basis-straal voor direct oppakken
@export var loot_magnet_applied: bool = false   # Standaard geen magneet aan
@export var current_magnet_radius: float = 150.0   # Straal waarin loot naar je toe zuigt
@export var current_magnet_force: float = 400.0    # Snelheid van het toezuigen


# --- UNIVERSELE SNELHEIDS-BEREKENAAR ---
func get_calculated_speed() -> float:
	var final_speed: float = current_speed
	
	# # 1. LIVE UPGRADE BEREKENING VANUIT DE META PROGRESSIE
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	# GECORRIGEERD: Haalt het level crashvrij op, ook bij een New Game!
	if current_meta and current_meta.skills_data:
		var raw_speed = current_meta.skills_data.get("skill_speed", 0)
		var speed_level: int = int(raw_speed["level"]) if raw_speed is Dictionary else int(raw_speed)
		
		# Elk level geeft de bonus die we straks in de modifiers van de Master-CSV hangen
		var upgrade_bonus: float = 1.0 + (speed_level * 0.005) # +0.5% per level
		final_speed *= upgrade_bonus

	
	# 2. DEBUG CHEATS: De F1-cheat multiplier weegt onvoorwaardelijk mee!
	final_speed *= Game.debug_current_speed_multiplier
	
	
	return final_speed
