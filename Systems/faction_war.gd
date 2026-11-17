extends Node
## FactionWar – de factie-oorlog die tijdens een run op de achtergrond doorloopt.
##
## Autoload: voeg dit script toe als "FactionWar".
##
## Het idee: er vliegen GEEN echte vijanden rond in kamers waar je niet bent. Per kamer houdt
## dit script alleen een paar getallen bij (wie bezit de kamer, hoe sterk, wie valt aan).
## Elke seconde speeltijd rekent het die getallen bij. Kom je een kamer binnen, dan kan de kamer
## hier opvragen welke factie er zit en hoe sterk (get_room_owner / get_room_info).
##
## Regels:
## - A, B en C (en later D-F, G-I) beginnen op door de seed gekozen plekken, 120° uit elkaar.
## - Een factie duwt elke tik een beetje naar de kamers links en rechts, en een klein beetje
##   omhoog naar de volgende ring. Nooit omlaag. De polen (eerste en laatste ring) doen niet mee.
## - Een lege kamer wordt ingenomen als een factie er lang genoeg tegenaan duwt.
## - Een bezette kamer verliest sterkte als een andere factie aanvalt. Op 0 = overgenomen.
## - Vallen twee basisfacties van DEZELFDE driehoek elkaar lang genoeg aan, dan wordt de kamer
##   hybride (A + B = "ab"). Tussen driehoeken (bijvoorbeeld A en D) ontstaan geen hybrides.
## - Facties uit een hogere driehoek zijn veel sterker in gevechten (tier_power).
## - Een factie uit een lagere driehoek kan alleen omhoog via kamers die de speler heeft
##   leeggemaakt. Daarna vecht hij gewoon mee, maar hij is daar veel zwakker.
## - Maakt de speler een kamer leeg, dan blijft die een tijd leeg (reoccupy_delay) en daarna
##   kan elke buurfactie hem weer innemen.
##
## Alle getallen komen uit de SSOT-rij SETTINGS_ROW. Een lege cel = de standaard uit DEFAULTS.
## De klok is de speeltijd: op pauze staat de oorlog stil.

## Wordt uitgezonden als een kamer van eigenaar wisselt.
signal room_changed(ring: int, room_index: int, new_owner: String)
## Na elke reeks tikken (handig om een kaart bij te werken).
signal tick_done

## De SSOT-rij met de instellingen van de oorlog.
const SETTINGS_ROW := "world"
## Hoe vaak de oorlog bijgerekend wordt, in seconden speeltijd.
const TICK_SECONDS := 1.0
## Nooit meer dan dit aantal tikken in één frame (bij de debug-versnelling).
const MAX_TICKS_PER_FRAME := 120

## De drie driehoeken. Hybrides ontstaan alleen binnen een driehoek: ab, bc, ca.
const TRIANGLES: Array = [["a", "b", "c"], ["d", "e", "f"], ["g", "h", "i"]]

## Welke driehoek in welke ring woont. Index = ring (0 = zuidpool). -1 = geen facties.
## AANNAME, nog met Maik afstemmen. Werkt voor de 11 ringen uit LevelManager.LAYER_WIDTHS.
const RING_TRIANGLE: Array = [-1, 0, 0, 0, 1, 1, 1, 2, 2, 2, -1]

## Standaardwaarden. Elke waarde kan in de SSOT-rij SETTINGS_ROW een eigen kolom krijgen.
const DEFAULTS := {
	"world_progression_start": 60.0,        # seconden speeltijd voordat de oorlog begint
	"world_progression_rate": 0.004,        # hoe hard een factie per seconde naar buren duwt (× sterkte)
	"faction_expansion_speed_modifier": 0.0, # percentage bovenop de duwsnelheid (0 = neutraal)
	"start_strength": 60.0,                  # sterkte van de startkamers
	"max_strength": 100.0,                   # hoogste sterkte van een kamer
	"growth_per_second": 0.5,                # hoe snel een kamer sterker wordt als hij niet aangevallen wordt
	"up_fraction": 0.15,                     # deel van de druk dat omhoog gaat (0.15 = 15%)
	"own_reinforce_fraction": 0.25,          # hoeveel eigen buren een kamer versterken
	"claim_threshold": 10.0,                 # hoeveel druk nodig is om een lege kamer in te nemen
	"takeover_strength": 10.0,               # sterkte direct na een overname
	"hybrid_spawn_delay": 90.0,              # seconden strijd voordat een kamer hybride wordt
	"hybrid_start_strength": 40.0,           # sterkte van een net ontstane hybride kamer
	"hybrid_expansion_multiplier": 1.5,      # hybrides duwen en vechten zoveel keer harder
	"tier_power": 3.0,                       # gevechtskracht per hogere driehoek (×3, ×9)
	"reoccupy_delay": 120.0,                 # seconden dat een door de speler geleegde kamer leeg blijft
	"kill_damage": 4.0,                      # sterkte die een factie verliest per gedode vijand
}

var active: bool = false
var war_time: float = 0.0        # speeltijd van deze oorlog, in seconden
var war_seed: int = 0
## Alleen voor testen: hoeveel keer sneller de oorlog loopt (de debugkaart zet dit).
var debug_time_scale: float = 1.0

## rooms[ring][kamer] = Dictionary met:
##   "owner"        welke factie de kamer bezit ("" = leeg)
##   "strength"     hoe sterk die factie daar is (0 tot max_strength)
##   "attacker"     wie de kamer deze tik het hardst aanvalt (voor de kaart)
##   "claim_by", "claim"          wie een lege kamer aan het innemen is, en hoe ver
##   "contest", "contest_time"    welke hybride hier aan het ontstaan is, en hoe lang al
##   "cleared_at"   wanneer de speler de kamer leegmaakte (-1 = niet)
var rooms: Array = []

var _settings: Dictionary = {}
var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if not active or not RunState.active:
		return

	_accumulator += delta * debug_time_scale
	var ticks: int = 0
	while _accumulator >= TICK_SECONDS and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= TICK_SECONDS
		war_time += TICK_SECONDS
		ticks += 1
		if war_time >= get_setting("world_progression_start"):
			_tick(TICK_SECONDS)
	# Bij een enorme versnelling niet eindeloos achterstand opbouwen.
	_accumulator = minf(_accumulator, TICK_SECONDS * MAX_TICKS_PER_FRAME)

	if ticks > 0:
		tick_done.emit()


# ============================================================================
# STARTEN, STOPPEN, OPSLAAN
# ============================================================================

## Begint een nieuwe oorlog. Zelfde seed = zelfde startplekken.
func start_new_war(seed_value: int = -1) -> void:
	_load_settings()
	if seed_value < 0:
		seed_value = randi()
	war_seed = seed_value
	war_time = 0.0
	_accumulator = 0.0

	rooms.clear()
	for r in LevelManager.LAYER_WIDTHS.size():
		var ring_rooms: Array = []
		for i in LevelManager.LAYER_WIDTHS[r]:
			ring_rooms.append(_empty_room())
		rooms.append(ring_rooms)

	# Elke driehoek krijgt een willekeurige draaiing; de drie facties staan 120° uit elkaar.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = war_seed
	for t in TRIANGLES.size():
		var offset: float = rng.randf_range(0.0, 360.0)
		for r in rooms.size():
			if _ring_triangle(r) != t:
				continue
			var width: int = rooms[r].size()
			for k in 3:
				var angle: float = fmod(offset + k * 120.0, 360.0)
				var index: int = int(floor(angle / 360.0 * width)) % width
				var room: Dictionary = rooms[r][index]
				room["owner"] = TRIANGLES[t][k]
				room["strength"] = get_setting("start_strength")

	active = true
	print("FACTIEOORLOG: nieuwe oorlog gestart (seed ", war_seed, ").")


## Stopt de oorlog en wist alles (einde van de run).
func stop() -> void:
	active = false
	rooms.clear()
	war_time = 0.0
	_accumulator = 0.0


## Alles wat bewaard moet worden. RunState zet dit in de save.
func get_state() -> Dictionary:
	return {
		"active": active,
		"seed": war_seed,
		"time": war_time,
		"rooms": rooms,
	}


## Zet een bewaarde oorlog terug (Continue). Klopt de bewaarde oorlog niet (oude save, ander
## aantal kamers), dan begint er een nieuwe.
func load_state(data: Dictionary) -> void:
	_load_settings()
	var saved_rooms: Variant = data.get("rooms", [])
	if not saved_rooms is Array or not _matches_world(saved_rooms):
		start_new_war()
		return

	rooms.clear()
	for ring_data in saved_rooms:
		var ring_rooms: Array = []
		for saved in ring_data:
			var room: Dictionary = _empty_room()
			if saved is Dictionary:
				room["owner"] = str(saved.get("owner", ""))
				room["strength"] = float(saved.get("strength", 0.0))
				room["attacker"] = str(saved.get("attacker", ""))
				room["claim_by"] = str(saved.get("claim_by", ""))
				room["claim"] = float(saved.get("claim", 0.0))
				room["contest"] = str(saved.get("contest", ""))
				room["contest_time"] = float(saved.get("contest_time", 0.0))
				room["cleared_at"] = float(saved.get("cleared_at", -1.0))
			ring_rooms.append(room)
		rooms.append(ring_rooms)

	war_seed = int(data.get("seed", 0))
	war_time = float(data.get("time", 0.0))
	active = bool(data.get("active", true))
	_accumulator = 0.0
	print("FACTIEOORLOG: oorlog hersteld op ", int(war_time), " seconden.")


# ============================================================================
# OPVRAGEN (voor de kamer, de plaatsingspunten en de kaart)
# ============================================================================

## Welke factie bezit deze kamer? "" = leeg.
## (Niet get_owner: die naam heeft elke Godot-node al.)
func get_room_owner(ring: int, room_index: int) -> String:
	var room: Dictionary = _get_room(ring, room_index)
	if room.is_empty():
		return ""
	return str(room["owner"])


## Een kopie van alles over deze kamer (owner, strength, attacker ...). Leeg als hij niet bestaat.
func get_room_info(ring: int, room_index: int) -> Dictionary:
	return _get_room(ring, room_index).duplicate()


## Hoeveel kamers elke factie bezit, bijvoorbeeld {"a": 12, "b": 9, "": 200}.
func owner_counts() -> Dictionary:
	var counts: Dictionary = {}
	for ring_rooms in rooms:
		for room in ring_rooms:
			var holder: String = room["owner"]
			counts[holder] = int(counts.get(holder, 0)) + 1
	return counts


## Een instelling uit de SSOT (of de standaard).
func get_setting(setting_name: String) -> float:
	return float(_settings.get(setting_name, DEFAULTS.get(setting_name, 0.0)))


## Is dit een hybride factie (twee letters)?
static func is_hybrid(faction: String) -> bool:
	return faction.length() == 2


## In welke driehoek hoort deze factie? 0, 1 of 2. -1 = onbekend of leeg.
static func triangle_of(faction: String) -> int:
	if faction == "":
		return -1
	var first: String = faction.substr(0, 1)
	for t in TRIANGLES.size():
		if TRIANGLES[t].has(first):
			return t
	return -1


## De hybride van twee basisfacties uit dezelfde driehoek: a+b = "ab", b+c = "bc", c+a = "ca".
## "" als ze geen hybride kunnen vormen.
static func hybrid_of(x: String, y: String) -> String:
	if x.length() != 1 or y.length() != 1 or x == y:
		return ""
	for tri in TRIANGLES:
		var i: int = tri.find(x)
		var j: int = tri.find(y)
		if i < 0 or j < 0:
			continue
		if (i + 1) % 3 == j:
			return x + y
		if (j + 1) % 3 == i:
			return y + x
	return ""


# ============================================================================
# WAT DE SPELER DOET
# ============================================================================

## De speler heeft deze kamer leeggemaakt. De kamer blijft een tijd leeg (reoccupy_delay).
## Mag elk frame aangeroepen worden: doet niets als de kamer al leeg is.
func on_room_cleared(ring: int, room_index: int) -> void:
	var room: Dictionary = _get_room(ring, room_index)
	if room.is_empty() or room["owner"] == "":
		return
	var old_owner: String = room["owner"]
	room["owner"] = ""
	room["strength"] = 0.0
	room["cleared_at"] = war_time
	_reset_attack(room)
	room_changed.emit(ring, room_index, "")
	print("FACTIEOORLOG: ring ", ring, " kamer ", room_index, " leeggemaakt (was ", old_owner, ").")


## De speler heeft een vijand gedood in deze kamer: de factie daar wordt iets zwakker.
func on_enemy_killed(ring: int, room_index: int) -> void:
	var room: Dictionary = _get_room(ring, room_index)
	if room.is_empty() or room["owner"] == "":
		return
	room["strength"] = maxf(0.0, room["strength"] - get_setting("kill_damage"))


# ============================================================================
# DE SIMULATIE
# ============================================================================

func _tick(dt: float) -> void:
	# 1. Druk verzamelen: elke bezette kamer duwt naar links, rechts en een beetje omhoog.
	#    Alles wordt eerst verzameld en daarna pas toegepast, zodat de volgorde niet uitmaakt.
	var incoming: Dictionary = {}   # Vector2i(ring, kamer) -> {factie: druk}
	for r in rooms.size():
		var width: int = rooms[r].size()
		for i in width:
			var room: Dictionary = rooms[r][i]
			var holder: String = room["owner"]
			if holder == "" or room["strength"] <= 0.0:
				continue
			var push: float = room["strength"] * get_setting("world_progression_rate") * _speed(holder) * dt
			if width > 1:
				_add_push(incoming, Vector2i(r, posmod(i - 1, width)), holder, push)
				_add_push(incoming, Vector2i(r, posmod(i + 1, width)), holder, push)
			for above in _rooms_above(r, i):
				_add_push(incoming, above, holder, push * get_setting("up_fraction"))

	# 2. Toepassen. Onthoud welke kamers aangevallen of ingenomen worden.
	var contested: Dictionary = {}
	for key in incoming:
		if _apply_push(key, incoming[key], dt):
			contested[key] = true

	# 3. Kamers die niet aangevallen worden, worden sterker en vergeten hun aanvaller.
	var max_strength: float = get_setting("max_strength")
	var growth: float = get_setting("growth_per_second") * dt
	for r in rooms.size():
		for i in rooms[r].size():
			if contested.has(Vector2i(r, i)):
				continue
			var room: Dictionary = rooms[r][i]
			_reset_attack(room)
			if room["owner"] != "":
				room["strength"] = minf(max_strength, room["strength"] + growth)


## Past alle druk op één kamer toe. Geeft true terug als de kamer aangevallen of ingenomen wordt.
func _apply_push(key: Vector2i, pushes: Dictionary, dt: float) -> bool:
	var room: Dictionary = rooms[key.x][key.y]
	var holder: String = room["owner"]
	var ring_triangle: int = _ring_triangle(key.x)
	var cleared_by_player: bool = room["cleared_at"] >= 0.0
	
	# Net leeggemaakt door de speler: nog even met rust laten.
	if cleared_by_player and war_time - room["cleared_at"] < get_setting("reoccupy_delay"):
		return false
	
	# Wie duwt er het hardst? Eigen buren versterken de kamer alleen.
	var strongest: String = ""
	var strongest_force: float = 0.0
	var strongest_push: float = 0.0
	var foreign_force: float = 0.0
	for faction in pushes:
		var amount: float = pushes[faction]
		if faction == holder:
			room["strength"] = minf(get_setting("max_strength"), room["strength"] + amount * get_setting("own_reinforce_fraction"))
			continue
		# Een factie uit een lagere driehoek komt in een hogere ring alleen binnen via een kamer
		# die de speler heeft leeggemaakt. Bezette of nooit bezochte kamers zijn voor hem dicht.
		if triangle_of(faction) < ring_triangle and not (holder == "" and cleared_by_player):
			continue
		var force: float = amount * _combat_power(faction)
		foreign_force += force
		if force > strongest_force or (is_equal_approx(force, strongest_force) and faction < strongest):
			strongest = faction
			strongest_force = force
			strongest_push = amount
	
	if strongest == "":
		return false
	room["attacker"] = strongest
	
	# --- Lege kamer: wie het langst en hardst duwt, neemt hem in.
	if holder == "":
		if room["claim_by"] == strongest:
			room["claim"] += strongest_push
		else:
			room["claim_by"] = strongest
			room["claim"] = strongest_push
		if room["claim"] >= get_setting("claim_threshold"):
			_set_owner(key, strongest, room["claim"])
		return true
	
	# --- Bezette kamer: de verdediger vangt de klap op met zijn eigen gevechtskracht.
	room["strength"] -= foreign_force / _combat_power(holder)
	
	# Vechten twee basisfacties uit dezelfde driehoek om deze kamer, dan telt de tijd mee,
	# ook als de kamer onderweg een paar keer van eigenaar wisselt.
	var pair: String = hybrid_of(holder, strongest)
	if pair != "" and room["contest"] == pair:
		room["contest_time"] += dt
	else:
		room["contest"] = pair
		room["contest_time"] = dt if pair != "" else 0.0
	
	if pair != "" and room["contest_time"] >= get_setting("hybrid_spawn_delay"):
		var start: float = maxf(room["strength"], get_setting("hybrid_start_strength"))
		_set_owner(key, pair, start)
		print("FACTIEOORLOG: ring ", key.x, " kamer ", key.y, " is hybride geworden: ", pair)
		return true
	
	if room["strength"] <= 0.0:
		# Overname. De strijdtijd blijft staan, zodat een heen-en-weer-front toch hybride wordt.
		_set_owner(key, strongest, get_setting("takeover_strength"), true)
	return true


func _set_owner(key: Vector2i, new_owner: String, strength: float, keep_contest: bool = false) -> void:
	var room: Dictionary = rooms[key.x][key.y]
	var contest: String = room["contest"]
	var contest_time: float = room["contest_time"]
	room["owner"] = new_owner
	room["strength"] = minf(get_setting("max_strength"), strength)
	room["cleared_at"] = -1.0
	_reset_attack(room)
	if keep_contest:
		room["contest"] = contest
		room["contest_time"] = contest_time
	room_changed.emit(key.x, key.y, new_owner)


## Hoe snel een factie zich uitbreidt.
func _speed(faction: String) -> float:
	var speed: float = 1.0 + get_setting("faction_expansion_speed_modifier")
	if is_hybrid(faction):
		speed *= get_setting("hybrid_expansion_multiplier")
	return speed


## Hoe sterk een factie in een gevecht is. Hogere driehoeken zijn veel sterker.
func _combat_power(faction: String) -> float:
	var power: float = pow(get_setting("tier_power"), maxi(triangle_of(faction), 0))
	if is_hybrid(faction):
		power *= get_setting("hybrid_expansion_multiplier")
	return power


## De kamer(s) in de ring erboven die boven deze kamer liggen. Leeg als die ring niet meedoet.
func _rooms_above(r: int, i: int) -> Array:
	var up: int = r + 1
	if up >= rooms.size() or _ring_triangle(up) < 0:
		return []
	var from_width: int = rooms[r].size()
	var to_width: int = rooms[up].size()
	var first: int = int(floor(float(i) * to_width / from_width))
	var last: int = int(floor(float(i + 1) * to_width / from_width))
	if last <= first:
		last = first + 1
	var result: Array = []
	for k in range(first, last):
		result.append(Vector2i(up, clampi(k, 0, to_width - 1)))
	return result


func _add_push(incoming: Dictionary, key: Vector2i, faction: String, amount: float) -> void:
	if _ring_triangle(key.x) < 0:
		return
	if not incoming.has(key):
		incoming[key] = {}
	var pushes: Dictionary = incoming[key]
	pushes[faction] = float(pushes.get(faction, 0.0)) + amount


func _reset_attack(room: Dictionary) -> void:
	room["attacker"] = ""
	room["claim_by"] = ""
	room["claim"] = 0.0
	room["contest"] = ""
	room["contest_time"] = 0.0


func _empty_room() -> Dictionary:
	return {
		"owner": "",
		"strength": 0.0,
		"attacker": "",
		"claim_by": "",
		"claim": 0.0,
		"contest": "",
		"contest_time": 0.0,
		"cleared_at": -1.0,
	}


func _get_room(ring: int, room_index: int) -> Dictionary:
	if ring < 0 or ring >= rooms.size():
		return {}
	var ring_rooms: Array = rooms[ring]
	if room_index < 0 or room_index >= ring_rooms.size():
		return {}
	return ring_rooms[room_index]


func _ring_triangle(r: int) -> int:
	if r < 0 or r >= RING_TRIANGLE.size():
		return -1
	return int(RING_TRIANGLE[r])


## Klopt een bewaarde oorlog nog met de huidige wereld (zelfde aantal ringen en kamers)?
func _matches_world(saved_rooms: Array) -> bool:
	if saved_rooms.size() != LevelManager.LAYER_WIDTHS.size():
		return false
	for r in saved_rooms.size():
		if not saved_rooms[r] is Array or saved_rooms[r].size() != LevelManager.LAYER_WIDTHS[r]:
			return false
	return true


func _load_settings() -> void:
	_settings = DEFAULTS.duplicate()
	if not Ssot.has_row(SETTINGS_ROW):
		return
	for key in DEFAULTS:
		if Ssot.has_value(SETTINGS_ROW, key):
			_settings[key] = Ssot.get_number(SETTINGS_ROW, key, DEFAULTS[key])
