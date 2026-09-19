extends Resource
class_name PlayerStats

@export var health: int = 100
@export var speed: float = 300.0
@export var acceleration: float = 1200.0
@export var friction: float = 100.0
@export var rotation_speed: float = 10.0

# Live variabelen tijdens de run
var current_health: int = 100 
var current_speed: float = 300.0
var current_acceleration: float = 1200.0
var current_friction: float = 100.0
var current_rotation_speed: float = 10.0

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
