extends Resource
class_name SkillData

@export_category("Database Koppeling (Backend)")
# De allerbelangrijkste link: moet EXACT matchen met de ID in jullie Google Spreadsheet!
# (Bijvoorbeeld: "skill_speed", "skill_magnet", etc.)
@export var skill_id: String = "skill_speed"

@export_category("In-Game Informatie (Frontend)")
# Deze velden mag je behouden om in de editor handmatig mooie display-teksten te typen
@export var skill_name: String = "Skaters Momentum"
@export_multiline var description: String = "Verhoogt je maximale loopsnelheid tijdens de run."


# --- DYNAMISCHE HULPFUNCTIE ---
# Vraagt live alle spreadsheet-gegevens op voor deze specifieke skill!
func get_csv_stats() -> Dictionary:
	if skill_id in MasterDatabase.skill_data:
		return MasterDatabase.skill_data[skill_id]["base_stats"]
	return {}


# Vraagt live de eenmalige unlock-eisen op uit de spreadsheet modifiers
func get_csv_unlock_requirements() -> Dictionary:
	if skill_id in MasterDatabase.skill_data:
		return MasterDatabase.skill_data[skill_id]["modifiers"]
	return {}
