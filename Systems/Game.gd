extends Node

# Onthoudt welk save-slot momenteel actief is (bijv. "Slot_1", "Slot_2", etc.)
# Standaard staat hij leeg totdat de speler een keuze maakt in het menu.
static var active_save_slot: String = ""
static var should_load_run: bool = false # Staat standaard uit bij een nieuwe game


# --- VARIABELEN ---
var entity_data: JSON
# DEBUG CHEATS: Extra multipliers voor tijdens het testen (Standaard 1.0 = normaal)
var debug_speed_multiplier: float = 1.0
# DEBUG CHEATS: InstaKill (Standaard false = uit)
var debug_damage_multiplier: float = 1.0
# DEBUG CHEATS: Onsterfelijkheid (Standaard false = uit)
var debug_is_invincible: bool = false


# --- INGEBOUWDE GODOT FUNCTIES ---

# _ready() wordt exact één keer uitgevoerd zodra de game opstart.
func _ready() -> void:
	print("Loading entity data")
	entity_data = load_entity_data()
	
	# GEWIZJIGD: We starten nu ALTIJD eerst in het tijdelijke Voorscherm!
	get_tree().call_deferred("change_scene_to_file", "res://Systems/pre_menu.tscn")



# --- JSON DATA LOGICA ---

# Deze functie zoekt en leest jullie JSON-bestand met data uit.
func load_entity_data() -> JSON:
	# 1. Open het bestand in lees-modus (READ)
	var file = FileAccess.open("./Data/entity_data.json", FileAccess.READ)
	
	# Veiligheidscheck: als het bestand niet bestaat, sturen we een foutmelding
	if file == null:
		print("Error: Could not open file")
		return null

	# 2. Lees de inhoud van het bestand als platte tekst
	var json_string = file.get_as_text()
	file.close() # Sluit het bestand direct netjes af

	# 3. REPARATIE HIER: Maak een leeg JSON-object aan zonder argumenten tussen de haakjes
	var json = JSON.new()
	var parse_result = json.parse(json_string)

	# Veiligheidscheck: als er een typefout of syntaxfout in het JSON-bestand zit, print de error
	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return null
	
	# 4. Geef de succesvol ontlede data terug aan de variabele
	return json
