extends Control
class_name SkillSlot

# --- EDITOR INSPECTOR INSTELLINGEN ---
@export var skill_id: String = "skill_speed" # Moet EXACT matchen met kolom A uit de spreadsheet!
@export var parent_skill_slot: Control = null

# --- RUNTIME STATISTIEKEN (LIVE GELADEN UIT DE GOOGLE SPREADSHEET!) ---
var currency_type: int = 0  
var cost_per_click: int = 5
var loss_per_minute: int = 1
var current_level: int = 0

@onready var bar: ProgressBar = find_child("*Bar*", true, false)
@onready var button: Button = find_child("*Button*", true, false)


func _ready() -> void:
	# REPARATIE: button.name overschrijven is verwijderd om find_child("*Button*") in het hoofdscript niet te slopen!
	_refresh_slot_data()


## Volgorde van de valuta, zoals de rest van het spel ze telt (0 = currency_1 = olrite).
const CURRENCIES := ["olrite", "metal", "keepium", "element_1", "element_2", "element_3"]
## Skills zonder rij in de sheet worden maar één keer gemeld (anders vult de Output zich).
static var _reported_missing: Dictionary = {}


func _refresh_slot_data() -> void:
	# 1. Kosten en verval: eerst uit de nieuwe SSOT, anders uit de oude Master-CSV.
	if Ssot.has_row(skill_id):
		_read_from_ssot()
	elif skill_id in MasterDatabase.skill_data:
		var csv_data = MasterDatabase.skill_data[skill_id]["base_stats"]
		currency_type = int(csv_data.get("currency_type", 0))
		cost_per_click = int(csv_data.get("cost_per_click", 5))
		loss_per_minute = int(csv_data.get("loss_per_minute", 1))
	elif not _reported_missing.has(skill_id):
		_reported_missing[skill_id] = true
		print("SKILL SLOT: '", skill_id, "' heeft nog geen rij in de sheet; standaardkosten gebruikt.")
		
	# 2. Haal het actuele level live en PLAT op uit de savegame
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var current_meta = save_system.get_loaded_meta_progress()
	
	if current_meta and current_meta.skills_data:
		var raw_val = current_meta.skills_data.get(skill_id, 0)
		# Kogelvrije opvang voor zowel de oude geneste als de nieuwe platte structuur
		current_level = int(raw_val["level"]) if raw_val is Dictionary else int(raw_val)
	else:
		current_level = 0
		
	# Pas direct de visuele start-waarden toe
	if is_instance_valid(bar) and is_instance_valid(button):
		bar.value = current_level
		button.text = skill_id + " (" + str(current_level) + "/100)"


# Leest kosten en verval uit de skill-rij in de SSOT.
# Kolom fill_costs_per_point is "valuta:aantal", bijvoorbeeld "olrite:5".
func _read_from_ssot() -> void:
	var cost_text: String = Ssot.get_text(skill_id, "fill_costs_per_point", "")
	if ":" in cost_text:
		var parts: PackedStringArray = cost_text.split(":")
		var index: int = CURRENCIES.find(parts[0].strip_edges().to_lower())
		if index >= 0:
			currency_type = index
		cost_per_click = int(parts[1].strip_edges().to_float())
	elif cost_text.is_valid_float():
		cost_per_click = int(cost_text.to_float())
	loss_per_minute = int(Ssot.get_number(skill_id, "base_decay_per_minute",
			Ssot.get_number("player_base", "base_decay_per_minute", loss_per_minute)))
