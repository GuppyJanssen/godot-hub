extends Control
class_name SkillSlot

# --- EDITOR INSPECTOR INSTELLINGEN ---
@export var skill_id: String = "skill_speed" # Moet EXACT matchen met kolom A uit de spreadsheet!
@export var parent_skill_slot: Control = null

# --- RUNTIME STATISTIEKEN (LIVE GELADEN UIT DE GOOGLE SPREADSHEET!) ---
var currency_type: int = 1
var cost_per_click: int = 5
var loss_per_minute: int = 1
var current_level: int = 0

@onready var bar: ProgressBar = find_child("*Bar*", true, false)
@onready var button: Button = find_child("*Button*", true, false)


func _ready() -> void:
	# Geef de knop de naam van het slot voor de dynamische menulink
	if button:
		button.name = name
	_refresh_slot_data()


func _refresh_slot_data() -> void:
	# 1. Haal de basisgegevens en drempels op uit de Master-CSV (enkelvoud skill_data!)
	if skill_id in MasterDatabase.skill_data:
		var csv_data = MasterDatabase.skill_data[skill_id]["base_stats"]
		currency_type = int(csv_data.get("currency_type", 1))
		cost_per_click = int(csv_data.get("cost_per_click", 5))
		loss_per_minute = int(csv_data.get("loss_per_minute", 1))
	else:
		push_warning("SKILL SLOT: ID '" + skill_id + "' niet gevonden in de Master-CSV!")
		
	# 2. Haal het actuele level live en PLAT op uit de savegame
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	if current_meta and current_meta.skills_data:
		var raw_val = current_meta.skills_data.get(skill_id, 0)
		# Kogelvrije opvang voor zowel de oude geneste als de nieuwe platte structuur
		current_level = int(raw_val["level"]) if raw_val is Dictionary else int(raw_val)
	else:
		current_level = 0


		
	# (Optioneel: Roep hier dadelijk jullie eigen visuele update aan, 
	# zoals het vullen van een ProgressBar of het bijwerken van een level-tekst!)
	# _update_visuals()
