extends Resource
class_name WeaponOutputData

@export_category("Kogel Eigenschappen")
@export var speed: float = 700.0          # Snelheid in pixels per seconde
@export_range(0.1, 5.0) var size_multiplier: float = 1.0 # Schaal van de kogel
@export var texture: Texture2D            # De sprite/afbeelding per variatie

@export_category("Wapen Gevechtsdata")
@export var damage: int = 10
@export var base_fire_rate: float = 0.3   # Tijd in seconden tussen schoten (lager = sneller)
@export var is_full_auto: bool = false     # HOU DE MUISKNOP INGEDRUKT: Schakelaar voor automatisch vuren!
@export var weapon_range: float = 600.0    # Hoe ver de kogel kan reizen in pixels vÓÓr hij sterft


# --- UNIVERSELE SCHADE-BEREKENAAR ---
func get_calculated_damage() -> int:
	var final_damage: float = float(damage) if "damage" in self else 10.0
	final_damage *= Game.debug_damage_multiplier
	return roundi(final_damage)


# --- UNIVERSELE FIRE-RATE BEREKENAAR ---
func get_calculated_fire_rate() -> float:
	var final_rate: float = base_fire_rate
	
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	if current_meta and current_meta.skills_data.has("Skill3_Slot"):
		var rate_points: int = current_meta.skills_data["Skill3_Slot"]["level"]
		var upgrade_bonus: float = 1.0 - (rate_points * 0.005)
		final_rate *= clamp(upgrade_bonus, 0.1, 1.0)
		
	return final_rate
