extends Node
# Autoload: MasterDatabase (De absolute Single Source of Truth!)

# De vakjes in het geheugen waar de rest van de game live data uit gaat trekken
var player_data: Dictionary = {}
var weapon_data: Dictionary = {}
var enemy_data: Dictionary = {}
var skill_data: Dictionary = {}

func _ready() -> void:
	load_master_database_from_csv("res://Systems/Single Source of Truth - Master Database.csv")


func load_master_database_from_csv(file_path: String) -> void:
	if not FileAccess.file_exists(file_path):
		push_error("MASTER CSV CRITICAL FOUT: Bestand niet gevonden op: " + file_path)
		return
		
	var file = FileAccess.open(file_path, FileAccess.READ)
	var _headers = file.get_csv_line() # Sla de titels over
	
	while not file.eof_reached():
		var columns = file.get_csv_line()
		
		# Beveiliging tegen lege regels aan het einde van het bestand
		if columns.size() < 9 or columns[0] == "":
			continue
			
		var entry_id = columns[0].strip_edges()
		var data_type = columns[1].strip_edges()
		
		# We parsen de gecodeerde strings naar bruikbare dictionaries via onze universele splitser
		var parsed_base_stats = parse_flexible_string(columns[5])
		var parsed_modifiers = parse_flexible_string(columns[6])
		var parsed_unlock_costs = parse_flexible_string(columns[7])
		var parsed_fill_costs = parse_flexible_string(columns[8])
		
		# Bouw het complete datapakketje voor deze rij
		var data_packet = {
			"ingame_name": columns[2].strip_edges(),
			"description": columns[3].strip_edges(),
			"base_value": float(columns[4]) if columns[4] != "" else 0.0,
			"base_stats": parsed_base_stats,
			"modifiers": parsed_modifiers,
			"unlock_costs": parsed_unlock_costs,
			"fill_costs": parsed_fill_costs
		}
		
		# --- DE MAGISCHE MASTER SORTEERHOED ---
		match data_type:
			"Speler_Base":
				player_data[entry_id] = data_packet
			"Wapen_Base":
				weapon_data[entry_id] = data_packet
			"Vijand_Base":
				enemy_data[entry_id] = data_packet
			"Upgrade_Skill":
				# Voor de skills injecteren we direct de live save-game status variabelen!
				data_packet["current_fill_level"] = 0
				data_packet["is_discovered"] = false
				data_packet["is_unlocked"] = false
				data_packet["keepium_shield_applied"] = false
				
				# We parsen de targets als een schone Array van strings (bijv: ["current_speed", "current_acceleration"])
				var target_list: Array[String] = []
				for target in columns[5].split(","):
					if target.strip_edges() != "":
						target_list.append(target.strip_edges())
				data_packet["targets"] = target_list
				
				skill_data[entry_id] = data_packet
				
	file.close()
	print("MASTER DATABASE: Systeem succesvol online!")
	print("-> SSoT Sorteerrapport: ", player_data.size(), " SpelerBases, ", weapon_data.size(), " Wapens, ", enemy_data.size(), " Vijanden, ", skill_data.size(), " Skills ingeladen.")


# --- UNIVERSELE TEKST PARSER (Verandert 'stat:waarde,stat:waarde' naar een tabel) ---
func parse_flexible_string(raw_string: String) -> Dictionary:
	var result: Dictionary = {}
	if raw_string.strip_edges() == "" or raw_string == "0":
		return result
		
	var pairs = raw_string.split(",")
	for pair in pairs:
		var parts = pair.split(":")
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value_str = parts[1].strip_edges()
			
			if value_str.is_valid_float():
				result[key] = float(value_str)
			else:
				result[key] = value_str
				
	return result
