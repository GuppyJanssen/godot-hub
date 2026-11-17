extends Node
## RunState – alles van de lopende run op één plek.
##
## Autoload: voeg dit script toe als "RunState".
##
## RunState schrijft naar een eigen bestand (run_state.json) in de map van het save-slot.
## Nu in gebruik: de dodenlijst, gehaalde kamers en de speeltijd. De run-loot telt mee,
## maar de bestaande telling in Game is nog leidend. Positie en HP doet het SaveSystem nog.
##
## Wat erin zit:
## - run-loot per valuta
## - per kamer: gehaald of niet, welke vijanden dood zijn, wat er verder veranderd is
## - de speeltijd van de run (voor het skill-verval)
## - run-punten voor skills (run-items die als skill werken)
## - waar de speler is (ring, kamer, positie)
##
## Voorbeeld:
##   RunState.add_loot("olrite", 5)
##   RunState.mark_dead(ring, room, name)
##   RunState.save()

## Eigen bestand, naast current_run.json van het bestaande SaveSystem.
const FILE_NAME := "run_state.json"
## Een run-item kan een skill tot dit aantal punten vullen.
const RUN_POINTS_MAX := 100.0

signal loot_changed(currency: String, total: int)
signal run_points_changed(skill_id: String, total: float)
## Aan het eind van de run. 'loot' gaat naar de kluis, 'seconds' is voor het skill-verval.
signal run_ended(loot: Dictionary, seconds: float)

var active: bool = false
var run_seconds: float = 0.0
var difficulty: int = 1            # 0 = Easy, 1 = Normal, 2 = Hard (zie SkillDecay)
var ring: int = 0
var room: int = 0
var player_position: Vector2 = Vector2.ZERO

var loot: Dictionary = {}          # valuta -> aantal
var rooms: Dictionary = {}         # "ring_kamer" -> { "cleared", "dead", "changes" }
var run_points: Dictionary = {}    # skill_id -> punten die alleen deze run tellen
var extra: Dictionary = {}         # vrije ruimte voor alles wat verder mee moet in de save


func _process(delta: float) -> void:
	# Staat het spel op pauze, dan loopt _process niet. De tijd telt dus alleen tijdens het spelen.
	if active:
		run_seconds += delta


# ---------------------------------------------------------------- run starten en eindigen

## Begin een schone run.
func start_new_run(new_difficulty: int = 1) -> void:
	# Een oude opgeslagen run hoort niet bij deze nieuwe run.
	delete_save()
	active = true
	run_seconds = 0.0
	difficulty = new_difficulty
	ring = 0
	room = 0
	player_position = Vector2.ZERO
	loot.clear()
	rooms.clear()
	run_points.clear()
	extra.clear()
	
	# De factie-oorlog begint elke run opnieuw.
	var war: Node = _faction_war()
	if war != null:
		war.start_new_war()


## Einde van de run (Surrender, dood, gewonnen, of New Run terwijl er nog een run stond).
## Geeft de run-loot terug en wist de run. Tel de loot zelf op bij de kluis,
## of luister naar het signaal run_ended.
func end_run() -> Dictionary:
	var final_loot: Dictionary = loot.duplicate()
	var seconds: float = run_seconds
	active = false
	delete_save()
	loot.clear()
	rooms.clear()
	run_points.clear()
	extra.clear()
	run_seconds = 0.0
	var war: Node = _faction_war()
	if war != null:
		war.stop()
	run_ended.emit(final_loot, seconds)
	return final_loot


# ---------------------------------------------------------------- loot

func add_loot(currency: String, amount: int) -> void:
	var total: int = get_loot(currency) + amount
	loot[currency] = total
	loot_changed.emit(currency, total)


func get_loot(currency: String) -> int:
	return int(loot.get(currency, 0))


# ---------------------------------------------------------------- kamers

func room_key(room_ring: int, room_index: int) -> String:
	return "%d_%d" % [room_ring, room_index]


## Onthoud dat deze vijand dood is. Hij komt dan niet meer terug in deze kamer.
func mark_dead(room_ring: int, room_index: int, enemy_name: String) -> void:
	var dead: Array = _room(room_ring, room_index)["dead"]
	if not dead.has(enemy_name):
		dead.append(enemy_name)


func is_dead(room_ring: int, room_index: int, enemy_name: String) -> bool:
	var key: String = room_key(room_ring, room_index)
	if not rooms.has(key):
		return false
	var dead: Array = rooms[key]["dead"]
	return dead.has(enemy_name)


## De kamer is leeg gespeeld.
func mark_cleared(room_ring: int, room_index: int) -> void:
	_room(room_ring, room_index)["cleared"] = true


func is_cleared(room_ring: int, room_index: int) -> bool:
	var key: String = room_key(room_ring, room_index)
	if not rooms.has(key):
		return false
	return rooms[key]["cleared"]


## Onthoud een andere wijziging in de kamer, bijvoorbeeld een kapotte asteroïde:
##   RunState.set_room_change(ring, room, "asteroid_3", "destroyed")
func set_room_change(room_ring: int, room_index: int, object_name: String, value: Variant) -> void:
	_room(room_ring, room_index)["changes"][object_name] = value


func get_room_change(room_ring: int, room_index: int, object_name: String, fallback: Variant = null) -> Variant:
	var key: String = room_key(room_ring, room_index)
	if not rooms.has(key):
		return fallback
	var changes: Dictionary = rooms[key]["changes"]
	return changes.get(object_name, fallback)


## Bewaart een momentopname van een kamer: alles wat zich in de groep "saveable" had aangemeld.
## 'units' is een Dictionary id -> wat dat object zelf wilde bewaren.
func save_room_snapshot(room_ring: int, room_index: int, units: Dictionary) -> void:
	_room(room_ring, room_index)["changes"]["units"] = units


## Alles wat er bij de laatste momentopname in deze kamer bewaard is.
func get_saved_units(room_ring: int, room_index: int) -> Dictionary:
	var units: Variant = get_room_change(room_ring, room_index, "units", {})
	if units is Dictionary:
		return units
	return {}


## De bewaarde gegevens van één object. Leeg als er niets bewaard is.
func get_saved_unit(room_ring: int, room_index: int, unit_id: String) -> Dictionary:
	var unit: Variant = get_saved_units(room_ring, room_index).get(unit_id, {})
	if unit is Dictionary:
		return unit
	return {}


## Hoeveel kamers er deze run gehaald zijn (voor backtrack-punten).
func cleared_room_count() -> int:
	var count: int = 0
	for data in rooms.values():
		if data["cleared"]:
			count += 1
	return count


func _room(room_ring: int, room_index: int) -> Dictionary:
	var key: String = room_key(room_ring, room_index)
	if not rooms.has(key):
		rooms[key] = {"cleared": false, "dead": [], "changes": {}}
	return rooms[key]


# ---------------------------------------------------------------- run-punten (run-items)

## Een run-item geeft punten in een skill, alleen voor deze run.
## Voorbeeld: elke keer dat je wapen X opraapt: RunState.add_run_points("skill_3", 10)
func add_run_points(skill_id: String, amount: float) -> void:
	var total: float = clampf(get_run_points(skill_id) + amount, 0.0, RUN_POINTS_MAX)
	run_points[skill_id] = total
	run_points_changed.emit(skill_id, total)


func get_run_points(skill_id: String) -> float:
	return float(run_points.get(skill_id, 0.0))


# ---------------------------------------------------------------- opslaan en laden

## De map van het actieve save-slot, bijvoorbeeld "user://Slot_2/".
func save_dir() -> String:
	return "user://" + Game.active_save_slot + "/"


func save_path() -> String:
	return save_dir() + FILE_NAME


## Staat er een run klaar om verder te spelen? (Voor de Continue-knop.)
func has_saved_run() -> bool:
	return FileAccess.file_exists(save_path())


## Schrijft de hele run weg. Roep dit aan bij een kamerwissel en bij "terug naar hoofdmenu".
func save() -> bool:
	if not active:
		return false

	var data: Dictionary = {
		"run_seconds": run_seconds,
		"difficulty": difficulty,
		"ring": ring,
		"room": room,
		"player_x": player_position.x,
		"player_y": player_position.y,
		"loot": loot,
		"rooms": rooms,
		"run_points": run_points,
		"extra": extra,
	}

	# Het seed-systeem (Game_toevoeging.gd) lift hier mee, als het is ingebouwd.
	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("get_seed_state"):
		data.merge(game.get_seed_state(), true)
	
	# De stand van de factie-oorlog.
	var war: Node = _faction_war()
	if war != null:
		data["faction_war"] = war.get_state()

	DirAccess.make_dir_recursive_absolute(save_dir())
	var file: FileAccess = FileAccess.open(save_path(), FileAccess.WRITE)
	if file == null:
		push_error("RunState: kan niet schrijven naar %s" % save_path())
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


## Leest de opgeslagen run terug (Continue). Geeft true terug als het gelukt is.
func load_run() -> bool:
	if not has_saved_run():
		return false

	var file: FileAccess = FileAccess.open(save_path(), FileAccess.READ)
	if file == null:
		push_error("RunState: kan %s niet openen." % save_path())
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary:
		push_error("RunState: %s is beschadigd." % save_path())
		return false
	var data: Dictionary = parsed

	active = true
	run_seconds = float(data.get("run_seconds", 0.0))
	difficulty = int(data.get("difficulty", 1))
	ring = int(data.get("ring", 0))
	room = int(data.get("room", 0))
	player_position = Vector2(float(data.get("player_x", 0.0)), float(data.get("player_y", 0.0)))

	# JSON maakt van elk getal een kommagetal. Loot zetten we terug naar hele getallen.
	loot.clear()
	var saved_loot: Dictionary = data.get("loot", {})
	for currency in saved_loot:
		loot[currency] = int(saved_loot[currency])

	rooms.clear()
	var saved_rooms: Dictionary = data.get("rooms", {})
	for key in saved_rooms:
		var saved: Dictionary = saved_rooms[key]
		rooms[key] = {
			"cleared": bool(saved.get("cleared", false)),
			"dead": saved.get("dead", []),
			"changes": saved.get("changes", {}),
		}

	run_points = data.get("run_points", {})
	extra = data.get("extra", {})

	var game: Node = get_node_or_null("/root/Game")
	if game != null and game.has_method("load_seed_state"):
		game.load_seed_state(data)
	
	# De factie-oorlog terugzetten. Een oude save zonder oorlog begint een nieuwe.
	var war: Node = _faction_war()
	if war != null:
		var war_data: Variant = data.get("faction_war", {})
		war.load_state(war_data if war_data is Dictionary else {})

	for currency in loot:
		loot_changed.emit(currency, loot[currency])
	return true


## Gooit de opgeslagen run weg (de Continue-knop verdwijnt dan).
func delete_save() -> void:
	if has_saved_run():
		DirAccess.remove_absolute(save_path())


## De autoload FactionWar, als die bestaat. Zo werkt RunState ook zonder factie-oorlog.
func _faction_war() -> Node:
	return get_node_or_null("/root/FactionWar")
