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
	
	# 1. LOGICA VOOR DE ÉCHTE SKILL TREE UPGRADES (Zonder cheats!)
	# We laden de opgeslagen stand van de schijf in
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	# Als de speler punten heeft gekocht in 'Skill1_Slot' (Loopsnelheid)
	if current_meta and current_meta.skills_data.has("Skill1_Slot"):
		var speed_points: int = current_meta.skills_data["Skill1_Slot"]["level"]
		
		# CONCEPT: Elk gekocht punt (0 t/m 100) geeft bijvoorbeeld +0.5% extra loopsnelheid!
		# 60 punten = +30% snelheid. (Pas de 0.005 gerust aan naar jullie eigen balans dadelijk!)
		var upgrade_bonus: float = 1.0 + (speed_points * 0.005)
		final_speed *= upgrade_bonus
	
	# 2. DEBUG CHEATS: We wegen de F1-cheat multiplier hier overal direct in mee!
	final_speed *= Game.debug_speed_multiplier
	
	return final_speed
