extends Resource
class_name WeaponOutputData


# --- KOGEL VARIATIES ---
@export var speed: float = 700.0         # Snelheid in pixels per seconde
@export var size_multiplier: float = 1.0  # Schaal van de kogel (1.0 = normaal, 2.0 = dubbel zo groot)
@export var base_fire_rate: float = 0.3 # Tijd in seconden tussen schoten (lager = sneller schieten!)
@export var texture: Texture2D            # De sprite/afbeelding (bepaalt het uiterlijk per variatie)
@export var damage: int = 10

# --- UNIVERSELE SCHADE-BEREKENAAR ---
func get_calculated_damage() -> int:
	# 1. We pakken de harde basisschade (standaard 10)
	var final_damage: float = float(damage) if "damage" in self else 10.0
	
	# 2. We passen direct de F1-debug multiplier toe (x1 of x5)
	final_damage *= Game.debug_damage_multiplier
	
	# 3. We ronden het getal keihard af naar een heel getal
	return roundi(final_damage)


# --- UNIVERSELE FIRE-RATE BEREKENAAR ---
func get_calculated_fire_rate() -> float:
	var final_rate: float = base_fire_rate
	
	# 1. LOGICA VOOR DE ÉCHTE SKILL TREE UPGRADES (Zonder cheats!)
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	# We spreken af dat bijvoorbeeld 'Skill3_Slot' dadelijk jullie Fire Rate upgrade wordt
	if current_meta and current_meta.skills_data.has("Skill3_Slot"):
		var rate_points: int = current_meta.skills_data["Skill3_Slot"]["level"]
		
		# CONCEPT: Elk punt (0 t/m 100) verlaagt de tussentijd met 0.5% (dus je schiet sneller!)
		var upgrade_bonus: float = 1.0 - (rate_points * 0.005)
		final_rate *= clamp(upgrade_bonus, 0.1, 1.0) # Veiligheidsgrens: nooit sneller dan 0.1s
		
	return final_rate



# --- UITGEBREIDE VARIATIES (VOOR LATER) ---
# Hier kunnen jullie later moeiteloos dingen toevoegen zoals:
# @export var pierce_count: int = 1     # Hoe vaak de kogel door vijanden heen mag gaan
# @export var behavior_type: String = "straight" # Bijv. "straight", "sine_wave", "homing", "boomerang"
