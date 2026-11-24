extends RefCounted
class_name SaveSystem
## SaveSystem – alles wat met de save-bestanden op schijf te maken heeft.
##
## Veiligheid (ontwikkelaarsnotities):
## - Alleen JSON. Nooit .tres/.res uit user:// laden: zo'n bestand kan een script bevatten dat
##   meteen wordt uitgevoerd. Een gedeelde of aangepaste save kan dan code op je pc draaien.
## - De naam van het save-slot wordt gecontroleerd (is_valid_slot). Zo kan een aangepast
##   app_config.json niet buiten de save-map schrijven of lezen (bijvoorbeeld "../../").
## - read_json geeft altijd een Dictionary terug (leeg bij een ontbrekend of kapot bestand),
##   zodat een beschadigde save het spel niet laat crashen.
## - write_json schrijft eerst naar een .tmp-bestand en zet dat daarna op zijn plek.
##   Valt het spel uit tijdens het opslaan, dan blijft de vorige save heel.
##
## Gebruik zonder instantie: SaveSystem.read_json(pad), SaveSystem.slot_dir().
## Oude code die load("res://Systems/SaveSystem.gd").new() doet, werkt nog. Dit is een
## RefCounted: hij ruimt zichzelf op, dus NOOIT .free() aanroepen.

## Alleen deze slotnamen zijn toegestaan (pre_menu: Slot_1, Slot_2, Slot_3).
const SLOT_NAMES: Array = ["Slot_1", "Slot_2", "Slot_3"]
const APP_CONFIG_PATH := "user://app_config.json"
const META_FILE := "meta_data.json"
const RUN_FILE := "current_run.json"
## Grootste save die we inlezen. Groter = vrijwel zeker kapot of aangepast.
const MAX_FILE_BYTES := 20 * 1024 * 1024

## Wordt nog gebruikt door neutral_spawner.gd (vervalt met deze instantie).
var dead_enemies_cache: Dictionary = {}


# ---------------------------------------------------------------- hulpfuncties

static func is_valid_slot(slot_name: String) -> bool:
	return SLOT_NAMES.has(slot_name)


## De map van het actieve slot, bijvoorbeeld "user://Slot_2/". Leeg als het slot ongeldig is.
static func slot_dir() -> String:
	if not is_valid_slot(Game.active_save_slot):
		return ""
	return "user://" + Game.active_save_slot + "/"


## Pad van een bestand in het actieve slot. Leeg als het slot ongeldig is.
static func slot_file(file_name: String) -> String:
	var dir: String = slot_dir()
	return "" if dir == "" else dir + file_name


## Leest een JSON-bestand. Geeft altijd een Dictionary (leeg als het niet lukt).
static func read_json(path: String) -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("SaveSystem: kan %s niet openen (fout %d)." % [path, FileAccess.get_open_error()])
		return {}
	if file.get_length() > MAX_FILE_BYTES:
		push_warning("SaveSystem: %s is te groot en wordt genegeerd." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_warning("SaveSystem: %s is beschadigd en wordt genegeerd." % path)
		return {}
	return parsed


## Schrijft een Dictionary als JSON. Eerst naar .tmp, dan op zijn plek. Geeft true als het lukte.
static func write_json(path: String, data: Dictionary) -> bool:
	if path == "" or not path.begins_with("user://"):
		push_error("SaveSystem: ongeldig opslagpad '%s'." % path)
		return false
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var tmp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: kan niet schrijven naar %s (fout %d)." % [tmp_path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var err: Error = DirAccess.rename_absolute(tmp_path, path)
	if err != OK:
		push_error("SaveSystem: kan %s niet vervangen (fout %d)." % [path, err])
		return false
	return true


## Dictionary uit een Dictionary, of {} als het iets anders is (beschermt tegen kapotte saves).
static func dict_or_empty(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


## Array uit een waarde, of [] als het iets anders is.
static func array_or_empty(value: Variant) -> Array:
	return value if value is Array else []


# ---------------------------------------------------------------- meta (de kluis en de skills)

func get_loaded_meta_progress() -> MetaProgress:
	var meta_res: MetaProgress = MetaProgress.new()
	var save_dict: Dictionary = read_json(slot_file(META_FILE))
	if save_dict.is_empty():
		return meta_res

	var saved_resources: Dictionary = dict_or_empty(save_dict.get("resources"))
	for id in saved_resources:
		meta_res.add_amount(LootResources.normalize(id), _safe_int(saved_resources[id]))
	# Oude saves hadden currency_1 ... currency_6 (vaste volgorde); die worden omgezet.
	for i in range(1, 7):
		var key: String = "currency_" + str(i)
		if save_dict.has(key):
			meta_res.add_amount(LootResources.normalize(i), _safe_int(save_dict[key]))

	# Alleen skills die in de SSOT bestaan, met een level dat binnen de grenzen valt.
	var saved_skills: Dictionary = dict_or_empty(save_dict.get("skills_data"))
	for skill_id in saved_skills:
		if not Ssot.has_row(str(skill_id)):
			continue
		var entry: Variant = saved_skills[skill_id]
		# Een kommagetal: door verval kan een skill op 37,25 staan.
		var level: float = _safe_float(entry.get("level", 0) if entry is Dictionary else entry)
		var clean: Dictionary = entry.duplicate() if entry is Dictionary else {}
		clean["level"] = clampf(level, 0.0, Ssot.get_number(str(skill_id), "fill_levels_amount", 100.0))
		meta_res.skills_data[str(skill_id)] = clean

	# JSON geeft getallen terug als float; de seed is een int.
	meta_res.tree_seed = _safe_int(save_dict.get("tree_seed", 0))
	for skill_id in array_or_empty(save_dict.get("discovered_skills")):
		if skill_id is String and Ssot.has_row(skill_id) and not meta_res.discovered_skills.has(skill_id):
			meta_res.discovered_skills.append(skill_id)
	return meta_res


func save_meta_progress(meta_resource: MetaProgress) -> void:
	if meta_resource == null or slot_dir() == "":
		return
	write_json(slot_file(META_FILE), {
		"resources": meta_resource.resources,
		"skills_data": meta_resource.skills_data,
		"tree_seed": meta_resource.tree_seed,
		"discovered_skills": meta_resource.discovered_skills,
	})


# ---------------------------------------------------------------- current_run.json (positie, schade)

func save_current_run(player_node: CharacterBody2D) -> void:
	if slot_dir() == "" or not is_instance_valid(player_node):
		return
	var full_path: String = slot_file(RUN_FILE)
	var run_data: Dictionary = read_json(full_path)
	var existing_damage: Dictionary = dict_or_empty(run_data.get("target_damage_taken"))

	var room_key: String = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)
	var room_damage_dict: Dictionary = dict_or_empty(existing_damage.get(room_key))

	for target in player_node.get_tree().get_nodes_in_group("targets"):
		if is_instance_valid(target) and "current_health" in target and "max_health" in target:
			room_damage_dict[str(target.name)] = target.max_health - target.current_health
	if dead_enemies_cache.has(room_key):
		for dead_id in dead_enemies_cache[room_key]:
			room_damage_dict[str(dead_id)] = 50
	existing_damage[room_key] = room_damage_dict

	run_data["player_position_x"] = player_node.global_position.x
	run_data["player_position_y"] = player_node.global_position.y
	run_data["current_layer"] = LevelManager.current_layer
	run_data["current_room_index"] = LevelManager.current_room_index
	run_data["target_damage_taken"] = existing_damage
	write_json(full_path, run_data)


func load_current_run(player_node: CharacterBody2D) -> void:
	if slot_dir() == "" or not is_instance_valid(player_node):
		return
	var data: Dictionary = read_json(slot_file(RUN_FILE))
	if data.is_empty():
		return
	var room_key: String = "L" + str(LevelManager.current_layer) + "_R" + str(LevelManager.current_room_index)

	if LevelManager.is_loading_from_continue:
		player_node.global_position = Vector2(_safe_float(data.get("player_position_x", 960.0)), _safe_float(data.get("player_position_y", 540.0)))

	# Herstel de HP van de vijanden. Waren ze al dood, dan verdwijnen ze.
	var d_map: Dictionary = dict_or_empty(dict_or_empty(data.get("target_damage_taken")).get(room_key))
	for target in player_node.get_tree().get_nodes_in_group("targets"):
		if d_map.has(str(target.name)) and "current_health" in target and "max_health" in target:
			target.current_health = maxi(0, int(target.max_health) - _safe_int(d_map[str(target.name)]))
			if target.current_health <= 0:
				target.queue_free()


func delete_current_run_save() -> void:
	var full_path: String = slot_file(RUN_FILE)
	if full_path != "" and FileAccess.file_exists(full_path):
		DirAccess.remove_absolute(full_path)


## Bestaat er een current_run.json in het actieve slot?
static func has_current_run() -> bool:
	var full_path: String = slot_file(RUN_FILE)
	return full_path != "" and FileAccess.file_exists(full_path)


# ---------------------------------------------------------------- laatst gebruikte slot

## Slaat het laatst gebruikte slot op ("" = geen). Ongeldige namen worden niet opgeslagen.
func save_last_used_slot(slot_name: String) -> void:
	if slot_name != "" and not is_valid_slot(slot_name):
		push_warning("SaveSystem: ongeldig slot '%s' niet opgeslagen." % slot_name)
		return
	write_json(APP_CONFIG_PATH, {"last_slot": slot_name})


## Het laatst gebruikte slot, of "" als er geen (geldig) slot is.
func load_last_used_slot() -> String:
	var slot: Variant = read_json(APP_CONFIG_PATH).get("last_slot", "")
	if slot is String and is_valid_slot(slot):
		return slot
	return ""


# ---------------------------------------------------------------- getallen uit JSON

static func _safe_int(value: Variant) -> int:
	if value is int or value is float:
		return int(value)
	if value is String and value.is_valid_float():
		return int(value.to_float())
	return 0


static func _safe_float(value: Variant) -> float:
	if value is int or value is float:
		var f: float = float(value)
		return f if is_finite(f) else 0.0
	return 0.0
