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
	return Ssot.get_row(skill_id) if Ssot.has_row(skill_id) else {}


# Vraagt live de eenmalige unlock-eisen op: de valuta-kolommen (olrite, metal, ...) van de SSOT-rij.
func get_csv_unlock_requirements() -> Dictionary:
	var result: Dictionary = {}
	for currency in ["olrite", "metal", "keepium", "element_1", "element_2", "element_3"]:
		if Ssot.has_value(skill_id, currency):
			result[currency] = Ssot.get_number(skill_id, currency)
	return result
