class_name RoomPopulator
## RoomPopulator – vult een kamer met fabrieken, op basis van de seed van de run en de factie-oorlog.
##
## Geen autoload nodig. game_room.gd roept RoomPopulator.populate(...) aan bij het laden.
##
## - WIE er zit, komt uit FactionWar (get_room_owner). Lege kamer in de oorlog = lege kamer.
##   De polen (eerste en laatste ring) doen niet mee aan de oorlog en blijven dus leeg.
## - WAAR de fabrieken staan en WAT ze maken, komt uit een random-generator met de seed van de
##   run + ring + kamer (RunState.room_seed). Zelfde seed = zelfde kamer.
## - Een kamer houdt zijn bezetting tot de speler hem leegmaakt (RunState onthoudt eigenaar en
##   aantal). Neemt een factie de kamer daarna opnieuw in, dan komt er een nieuwe bezetting
##   (een nieuwe "generatie", met nieuwe plekken).
##
## Instellingen in de SSOT-rij "world" (lege cel = de standaard hieronder):
##   room_factory_min, room_factory_max   hoeveel fabrieken in een bezette kamer
##   room_heavy_chance                    kans dat een fabriek heavy's maakt in plaats van grunts
##   room_grunts_per_factory              hoeveel grunts een grunt-fabriek maakt
##   room_heavies_per_factory             hoeveel heavy's een heavy-fabriek maakt

const FACTORY_SCENE := "res://Entities/Spawners/factory.tscn"
const SETTINGS_ROW := "world"
const DEFAULTS := {
	"room_factory_min": 1.0,
	"room_factory_max": 3.0,
	"room_heavy_chance": 0.35,
	"room_grunts_per_factory": 2.0,
	"room_heavies_per_factory": 1.0,
}

## Waar fabrieken mogen staan (een kamer is 1920 x 1080), met afstand tot elkaar en tot het midden.
const AREA := Rect2(260, 180, 1400, 720)
const MIN_DISTANCE := 260.0
const CENTER := Vector2(960, 540)
const CENTER_FREE_RADIUS := 220.0


## Zet de fabrieken van deze kamer neer, als kinderen van 'parent'.
## Roep dit aan VOOR de kamer bewaarde objecten terugzet: fabrieken die al stonden, halen hun
## eigen gegevens (HP, teller) zelf op, en de kamer slaat ze dan over.
static func populate(parent: Node, ring: int, room_index: int) -> void:
	var war: Node = parent.get_node_or_null("/root/FactionWar")
	if war == null or not war.active:
		return

	var gen: int = int(RunState.get_room_change(ring, room_index, "pop_gen", 0))
	var saved_owner: Variant = RunState.get_room_change(ring, room_index, "pop_owner", null)
	var owner: String = ""
	var saved_count: int = -1

	if saved_owner != null and not RunState.is_cleared(ring, room_index):
		# Deze kamer is al eens bezet en nog niet leeggemaakt: dezelfde bezetting.
		owner = str(saved_owner)
		saved_count = int(RunState.get_room_change(ring, room_index, "pop_count", -1))
	else:
		owner = war.get_room_owner(ring, room_index)
		if owner == "":
			return
		if RunState.is_cleared(ring, room_index):
			# Leeggemaakt en daarna opnieuw ingenomen: nieuwe bezetting.
			gen += 1
			RunState.unmark_cleared(ring, room_index)
	if owner == "":
		return

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = RunState.room_seed(ring, room_index, gen)

	var low: int = maxi(0, roundi(_setting("room_factory_min")))
	var high: int = maxi(low, roundi(_setting("room_factory_max")))
	var count: int = rng.randi_range(low, high)
	if saved_count >= 0:
		count = saved_count

	RunState.set_room_change(ring, room_index, "pop_owner", owner)
	RunState.set_room_change(ring, room_index, "pop_gen", gen)
	RunState.set_room_change(ring, room_index, "pop_count", count)

	var scene: PackedScene = load(FACTORY_SCENE)
	if scene == null:
		push_error("RoomPopulator: %s niet gevonden." % FACTORY_SCENE)
		return

	var heavy_chance: float = _setting("room_heavy_chance")
	var grunts: int = maxi(1, roundi(_setting("room_grunts_per_factory")))
	var heavies: int = maxi(1, roundi(_setting("room_heavies_per_factory")))
	var placed: Array[Vector2] = []
	for k in count:
		var pos: Vector2 = _free_spot(rng, placed)
		placed.append(pos)
		var heavy: bool = rng.randf() < heavy_chance
		var factory: Node = scene.instantiate()
		factory.faction = owner
		factory.spawn_unit_type = "heavy" if heavy else "light"
		factory.total_enemies_to_spawn = heavies if heavy else grunts
		factory.position = pos
		parent.add_child(factory)

	print("KAMER: ring ", ring, " kamer ", room_index, " = factie ", owner, ", ", count, " fabriek(en) (generatie ", gen, ").")


## Een vrije plek: binnen AREA, niet te dicht bij het midden of bij andere fabrieken.
## Hele pixels, want de naam van een fabriek hangt af van zijn plek.
static func _free_spot(rng: RandomNumberGenerator, placed: Array[Vector2]) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	for attempt in 40:
		var p: Vector2 = Vector2(
			roundf(rng.randf_range(AREA.position.x, AREA.end.x)),
			roundf(rng.randf_range(AREA.position.y, AREA.end.y)))
		best = p
		if p.distance_to(CENTER) < CENTER_FREE_RADIUS:
			continue
		var ok: bool = true
		for other in placed:
			if p.distance_to(other) < MIN_DISTANCE:
				ok = false
				break
		if ok:
			return p
	return best


static func _setting(setting_name: String) -> float:
	return Ssot.get_number(SETTINGS_ROW, setting_name, float(DEFAULTS[setting_name]))
