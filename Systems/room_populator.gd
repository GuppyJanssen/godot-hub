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
##   room_commando_chance                 kans per factie dat er al een commando in de kamer staat
##   room_commando_double_chance          als er één staat: kans op nog een tweede (0.1 x 0.1 = 1% op twee)
##
## WELKE UNIT (Daan, 26 nov): de 1e fabriek van een factie maakt lights (bij Organic spores), de 2e
## heavy's, de rest volgens room_heavy_chance. Per gemaakte unit kan de fabriek toch het andere type
## maken (factory_type_swap_chance) of een commando (factory_commando_chance), zie basic_spawner.gd.
## Torens zijn gebouwen en komen niet uit fabrieken.
##
## TWEE FACTIES (front): valt een factie deze kamer aan in de oorlog (room["attacker"]), dan is de
## kamer een front en staan haar fabrieken er ook. Geen aanvaller = alleen de bezitter. De bezitter
## staat op de ene helft, de aanvaller op de andere (links/rechts of boven/onder, uit de seed). Ze
## vechten onderling (TargetPicker), maar de speler gaat voor. Op de oorlogskaart (F2) hebben
## fronten een eigen kleur. AANNAME: welke helft is nog willekeurig; later de kant van het eigen gebied.

const FACTORY_SCENE := "res://Entities/Spawners/factory.tscn"
const UNIT_SCENE := "res://Entities/Objects/test_body.tscn"
const SETTINGS_ROW := "world"
const DEFAULTS := {
	"room_factory_min": 1.0,
	"room_factory_max": 3.0,
	"room_heavy_chance": 0.35,
	"room_grunts_per_factory": 2.0,
	"room_heavies_per_factory": 1.0,
	"room_factory_spacing": 260.0,
	"room_center_free_radius": 220.0,
	"room_commando_chance": 0.0,
	"room_commando_double_chance": 0.0,
}

## Waar fabrieken mogen staan: de kamer (RoomBounds.size) met deze rand, met afstand tot elkaar en tot het midden.
const AREA_MARGIN := Vector2(260, 180)


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
	var saved_second: Variant = null

	if saved_owner != null and not RunState.is_cleared(ring, room_index):
		# Deze kamer is al eens bezet en nog niet leeggemaakt: dezelfde bezetting.
		owner = str(saved_owner)
		saved_count = int(RunState.get_room_change(ring, room_index, "pop_count", -1))
		saved_second = RunState.get_room_change(ring, room_index, "pop_second", null)
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
	# Hogere ringen binnen een driehoek zijn rijker gevuld (room_fill_per_ring, bijv. 1/1.25/1.5).
	var fill: float = _ring_fill(ring)
	var count: int = maxi(0, roundi(rng.randi_range(low, high) * fill))
	if saved_count >= 0:
		count = saved_count

	# Tweede factie: bewaard blijft bewaard (zelfde bezetting), anders nu kiezen.
	var second: String = ""
	if saved_second != null:
		second = str(saved_second)
		if not _is_known_faction(second) or second == owner:
			second = ""
	else:
		second = _pick_second(war, ring, room_index, owner)
	var second_count: int = maxi(0, roundi(rng.randi_range(low, high) * fill)) if second != "" else 0
	# Welke helft voor wie: true = links/rechts, false = boven/onder; owner_first = bezitter links/boven.
	var split_x: bool = rng.randf() < 0.5
	var owner_first: bool = rng.randf() < 0.5

	RunState.set_room_change(ring, room_index, "pop_owner", owner)
	RunState.set_room_change(ring, room_index, "pop_gen", gen)
	RunState.set_room_change(ring, room_index, "pop_count", count)
	RunState.set_room_change(ring, room_index, "pop_second", second)

	var scene: PackedScene = load(FACTORY_SCENE)
	if scene == null:
		push_error("RoomPopulator: %s niet gevonden." % FACTORY_SCENE)
		return

	var heavy_chance: float = _setting("room_heavy_chance")
	var grunts: int = maxi(1, roundi(_setting("room_grunts_per_factory")))
	var heavies: int = maxi(1, roundi(_setting("room_heavies_per_factory")))
	var placed: Array[Vector2] = []
	var owner_area: Rect2 = _area() if second == "" else _half(split_x, owner_first)
	_place(parent, scene, rng, owner, count, owner_area, placed, heavy_chance, grunts, heavies)
	_place_commandos(parent, rng, owner, owner_area, placed, "%d_%d_%d" % [ring, room_index, gen])
	if second != "":
		var second_area: Rect2 = _half(split_x, not owner_first)
		_place(parent, scene, rng, second, second_count, second_area, placed, heavy_chance, grunts, heavies)
		_place_commandos(parent, rng, second, second_area, placed, "%d_%d_%d" % [ring, room_index, gen])

	print("KAMER: ring ", ring, " kamer ", room_index, " = factie ", owner, ", ", count, " fabriek(en)",
			(", plus factie %s met %d fabriek(en)" % [second, second_count]) if second != "" else "",
			" (generatie ", gen, ").")


## Zet 'amount' fabrieken van 'faction' neer binnen 'area'.
static func _place(parent: Node, scene: PackedScene, rng: RandomNumberGenerator, faction: String, amount: int,
		area: Rect2, placed: Array[Vector2], heavy_chance: float, grunts: int, heavies: int) -> void:
	for k in amount:
		var pos: Vector2 = _free_spot(rng, placed, area)
		placed.append(pos)
		# 1e fabriek lights, 2e heavy's, daarna volgens de kans.
		var heavy: bool = false
		if k == 1:
			heavy = true
		elif k >= 2:
			heavy = rng.randf() < heavy_chance
		var factory: Node = scene.instantiate()
		factory.faction = faction
		factory.spawn_unit_type = "heavy" if heavy else "light"
		factory.total_enemies_to_spawn = _units_per_factory(faction, "heavy" if heavy else "light", heavies if heavy else grunts)
		factory.position = pos
		parent.add_child(factory)


## Commando's die al in de kamer staan: kans room_commando_chance op één, en als er één staat
## kans room_commando_double_chance op een tweede. Vaste namen per kamer en generatie, zodat RunState ze onthoudt.
static func _place_commandos(parent: Node, rng: RandomNumberGenerator, faction: String, area: Rect2,
		placed: Array[Vector2], tag: String) -> void:
	var amount: int = 0
	if rng.randf() < clampf(_setting("room_commando_chance"), 0.0, 1.0):
		amount = 1
		if rng.randf() < clampf(_setting("room_commando_double_chance"), 0.0, 1.0):
			amount = 2
	if amount == 0 or not EnemyStats.exists(faction, "medium"):
		return
	var scene: PackedScene = load(UNIT_SCENE)
	if scene == null:
		push_error("RoomPopulator: %s niet gevonden." % UNIT_SCENE)
		return
	# Bij de eigen fabrieken, alsof ze daar gebouwd zijn (Daan, 26 nov); geen fabriek = ergens op de helft.
	var homes: Array[Vector2] = []
	for child in parent.get_children():
		if "faction" in child and "spawn_unit_type" in child and str(child.faction) == faction:
			homes.append((child as Node2D).position)
	for k in amount:
		var pos: Vector2 = _free_spot(rng, placed, area)
		if not homes.is_empty():
			var home: Vector2 = homes[rng.randi_range(0, homes.size() - 1)]
			var spread: float = _setting("room_factory_spacing") * 0.6
			pos = home + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(spread * 0.4, spread)
			pos = Vector2(roundf(clampf(pos.x, _area().position.x, _area().end.x)), roundf(clampf(pos.y, _area().position.y, _area().end.y)))
		placed.append(pos)
		var unit: Node = scene.instantiate()
		unit.name = "Commando_%s_%s_%d" % [faction, tag, k]
		unit.faction = faction
		unit.unit_type = "medium"
		unit.position = pos
		parent.add_child(unit)


## Hoeveel units een fabriek van deze factie en dit type maakt: kolom factory_unit_total op de eigen
## vijand-rij (bijv. enemy_organic_light = 10 spores), anders de standaard uit world
## (room_grunts_per_factory / room_heavies_per_factory). -1 = eindeloos. Begrensd tot 200.
static func _units_per_factory(faction: String, unit_type: String, fallback: int) -> int:
	var row: String = EnemyStats.enemy_row(faction, unit_type)
	if not Ssot.has_value(row, "factory_unit_total"):
		return fallback
	var total: int = roundi(Ssot.get_number(row, "factory_unit_total", float(fallback)))
	if total == -1:
		return -1
	return clampi(total, 1, 200)


## De tweede factie voor deze kamer: de factie waarmee hier een front is (de aanvaller in de oorlog).
## "" = geen front, alleen de bezitter.
static func _pick_second(war: Node, ring: int, room_index: int, owner: String) -> String:
	var info: Dictionary = war.get_room_info(ring, room_index)
	var attacker: String = str(info.get("attacker", ""))
	if attacker != "" and attacker != owner and _is_known_faction(attacker):
		return attacker
	return ""


## Bestaat deze factie in de SSOT (rij faction_<naam>)? Beschermt tegen rare waarden uit een save.
static func _is_known_faction(faction: String) -> bool:
	return faction != "" and faction.length() <= 2 and faction.is_valid_identifier() \
			and Ssot.has_row(EnemyStats.faction_row(faction))


## Vulfactor voor deze ring: de hoeveelste ring binnen zijn driehoek (onderste = 1e) kiest een waarde
## uit room_fill_per_ring (world, bijv. "1/1.25/1.5"). Leeg of ongeldig = 1. Begrensd tot 0..5.
static func _ring_fill(ring: int) -> float:
	if LevelManager.triangle_of_ring(ring) < 0:
		return 1.0
	var step: int = (ring - 1) % LevelManager.RINGS_PER_TRIANGLE
	var parts: PackedStringArray = Ssot.get_text(SETTINGS_ROW, "room_fill_per_ring", "").split("/", false)
	if step >= parts.size():
		return 1.0
	var value: String = parts[step].strip_edges().replace(",", ".")
	return clampf(value.to_float(), 0.0, 5.0) if value.is_valid_float() else 1.0


## De helft van het fabrieksgebied: links/rechts (split_x) of boven/onder; first = links of boven.
static func _half(split_x: bool, first: bool) -> Rect2:
	var a: Rect2 = _area()
	if split_x:
		var w: float = a.size.x * 0.5
		return Rect2(a.position + Vector2(0.0 if first else w, 0.0), Vector2(w, a.size.y))
	var h: float = a.size.y * 0.5
	return Rect2(a.position + Vector2(0.0, 0.0 if first else h), Vector2(a.size.x, h))


## Een vrije plek: binnen 'area', niet te dicht bij het midden of bij andere fabrieken.
## Hele pixels, want de naam van een fabriek hangt af van zijn plek.
static func _free_spot(rng: RandomNumberGenerator, placed: Array[Vector2], area: Rect2) -> Vector2:
	var best: Vector2 = Vector2.ZERO
	for attempt in 40:
		var p: Vector2 = Vector2(
			roundf(rng.randf_range(area.position.x, area.end.x)),
			roundf(rng.randf_range(area.position.y, area.end.y)))
		best = p
		if p.distance_to(RoomBounds.center()) < _setting("room_center_free_radius"):
			continue
		var ok: bool = true
		for other in placed:
			if p.distance_to(other) < _setting("room_factory_spacing"):
				ok = false
				break
		if ok:
			return p
	return best


static func _setting(setting_name: String) -> float:
	return Ssot.get_number(SETTINGS_ROW, setting_name, float(DEFAULTS[setting_name]))


static func _area() -> Rect2:
	return Rect2(AREA_MARGIN, RoomBounds.size() - 2.0 * AREA_MARGIN)
