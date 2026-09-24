extends Node
# Autoload: MasterDatabase (De absolute Single Source of Truth!)

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
	
	# GECORRIGEERD: We lezen de ruwe regel als tekst om de exacte header-namen te indexeren
	var raw_header_line = file.get_line()
	var headers = raw_header_line.split(",")
	
	# Zoek dynamisch op welke index de kolommen staan vanaf de RECHTERKANT
	var idx_full_auto: int = _find_header_index_from_end(headers, "is_full_auto")
	var idx_bullets: int = _find_header_index_from_end(headers, "bullet_per_shot")
	var idx_muzzles: int = _find_header_index_from_end(headers, "muzzle_count")
	var idx_spread: int = _find_header_index_from_end(headers, "bullet_spread")
	
	while not file.eof_reached():
		var raw_line = file.get_line()
		if raw_line.strip_edges() == "": continue
		
		var columns = raw_line.split(",")
		if columns.size() < 9 or columns[0] == "": continue
		
		var entry_id = columns[0].strip_edges().replace('"', "")
		var data_type = columns[1].strip_edges().replace('"', "")
		
		# Haal de basis strings op (Sla de stats cel over, die parsen we zo apart via de ruwe tekst)
		var ingame_name = columns[2].strip_edges().replace('"', "")
		var description = columns[3].strip_edges().replace('"', "")
		
		# Vind de stats tekstcel kogelvrij door te zoeken tussen de aanhalingstekens
		var base_stats_str = ""
		if '"' in raw_line:
			var split_quotes = raw_line.split('"')
			if split_quotes.size() > 1:
				base_stats_str = split_quotes[1]
				
		var parsed_base_stats = parse_flexible_string(base_stats_str)
		
		# Bouw het complete datapakketje
		var data_packet = {
			"ingame_name": ingame_name,
			"description": description,
			"base_value": 0.0,
			"base_stats": parsed_base_stats,
			"modifiers": {},
			"unlock_costs": {},
			"fill_costs": {},
			
			# Standaard fallbacks
			"is_full_auto": 1.0,
			"bullet_per_shot": 1,
			"muzzle_count": 1,
			"bullet_spread": 0.0
		}
		
		# BINGO: We lezen de kolommen uit vanaf de achterkant van de array!
		# Dit voorkomt dat extra komma's in de tekstcellen de boel verschuiven.
		if idx_full_auto != -1 and columns.size() > (columns.size() - 1 - idx_full_auto):
			data_packet["is_full_auto"] = float(columns[columns.size() - 1 - idx_full_auto].strip_edges())
		if idx_bullets != -1 and columns.size() > (columns.size() - 1 - idx_bullets):
			data_packet["bullet_per_shot"] = int(columns[columns.size() - 1 - idx_bullets].strip_edges())
		if idx_muzzles != -1 and columns.size() > (columns.size() - 1 - idx_muzzles):
			data_packet["muzzle_count"] = int(columns[columns.size() - 1 - idx_muzzles].strip_edges())
		if idx_spread != -1 and columns.size() > (columns.size() - 1 - idx_spread):
			data_packet["bullet_spread"] = float(columns[columns.size() - 1 - idx_spread].strip_edges())
			
		match data_type:
			"Speler_Base": player_data[entry_id] = data_packet
			"Wapen_Base": weapon_data[entry_id] = data_packet
			"Vijand_Base": enemy_data[entry_id] = data_packet
			"Upgrade_Skill":
				data_packet["current_fill_level"] = 0
				data_packet["is_discovered"] = false
				data_packet["is_unlocked"] = false
				data_packet["keepium_shield_applied"] = false
				skill_data[entry_id] = data_packet
				
	file.close()
	print("MASTER DATABASE: Systeem succesvol online via Dynamische Headers!")
	print("-> SSoT Sorteerrapport: ", player_data.size(), " SpelerBases, ", weapon_data.size(), " Wapens, ", enemy_data.size(), " Vijanden, ", skill_data.size(), " Skills ingeladen.")

# Hulpfunctie om de kolompositie vanaf het einde te berekenen
func _find_header_index_from_end(headers: PackedStringArray, target: String) -> int:
	for i in range(headers.size() - 1, -1, -1):
		if headers[i].strip_edges() == target:
			return headers.size() - 1 - i
	return -1

func parse_flexible_string(raw_string: String) -> Dictionary:
	var result: Dictionary = {}
	if raw_string.strip_edges() == "" or raw_string == "0": return result
	var pairs = raw_string.split(",")
	for pair in pairs:
		var parts = pair.split(":")
		if parts.size() == 2:
			var key = parts[0].strip_edges()
			var value_str = parts[1].strip_edges()
			result[key] = float(value_str) if value_str.is_valid_float() else value_str
	return result
