class_name SkillTreeLayout
## SkillTreeLayout – bepaalt de stamboom en de plek van elke skill in de skill tree.
##
## Twee dingen, met elk een eigen regel:
## 1. WIE IS DE PARENT? Altijd gelijk, in elke save. Komt uit de SSOT-kolom parent_skill_id.
##    Is die leeg, dan kiest de code een vaste parent (op basis van de skill-id, niet van de save),
##    zodat de boom ook werkt zolang de sheet nog niet is ingevuld.
## 2. WAAR STAAT HIJ? Verschilt per save. Komt uit tree_seed in de save (MetaProgress).
##    Vanuit het midden groeien takken alle kanten op; elke skill krijgt een richting die
##    ongeveer van zijn parent af wijst, met een willekeurige afwijking. Zo ontstaat een wirwar.
##    Takken kruisen elkaar nooit en lopen niet vlak langs een andere skill, zodat altijd
##    duidelijk is welke lijn waarheen loopt.
##
## Ontwikkelaarsnotities:
## - Een skill verbergen: zet skill_menu_visible op 0 in de sheet.
## - De eerste zichtbare skill in de sheet (of een skill met parent_skill_id "root") is het midden.
## - Alle maten staan hieronder als const; pas ze daar aan als de boom te krap of te ruim is.

const SKILL_TYPE := "upgrade_skill"
const PARENT_COLUMN := "parent_skill_id"
const VISIBLE_COLUMN := "skill_menu_visible"
const ROOT_MARKER := "root"

## Hoeveel kinderen een skill hooguit krijgt als de code zelf een parent kiest.
const AUTO_MAX_CHILDREN := 3
## Afstand van een skill tot zijn parent (in pixels), willekeurig tussen deze twee.
const MIN_LINK_LENGTH := 150.0
const MAX_LINK_LENGTH := 230.0
## Hoe ver een kind mag afwijken van de richting van zijn parent (in graden, naar beide kanten).
const MAX_BEND_DEGREES := 75.0
## Minimale ruimte tussen twee skills, zodat ze elkaar niet raken (cirkels + naam eronder).
const MIN_NODE_SPACING := 125.0
## Een tak mag niet dichter dan dit langs een andere skill lopen (anders lijkt hij erbij te horen).
const MIN_LINE_CLEARANCE := 50.0
## Hoe vaak de code een andere plek probeert voordat hij de tak langer maakt.
const PLACE_ATTEMPTS := 30
## Hoe vaak de tak langer gemaakt mag worden als er geen plek is.
const PLACE_ROUNDS := 12
## Hoe vaak de hele boom opnieuw gelegd mag worden als een tak klem zit.
const LAYOUT_ATTEMPTS := 20


## Alle skills die in de boom horen, in de volgorde van de sheet.
static func skill_ids() -> Array:
	var result: Array = []
	for skill_id in Ssot.get_ids(SKILL_TYPE):
		if Ssot.has_value(skill_id, VISIBLE_COLUMN) and not Ssot.get_bool(skill_id, VISIBLE_COLUMN, true):
			continue
		result.append(skill_id)
	return result


## Geeft een Dictionary skill_id -> parent_id ("" voor het midden). Gelijk voor elke save.
static func build_parents(ids: Array) -> Dictionary:
	var parents: Dictionary = {}
	var child_count: Dictionary = {}
	if ids.is_empty():
		return parents

	# Het midden: een skill met parent "root", anders de eerste in de sheet.
	var root_id: String = ids[0]
	for skill_id in ids:
		if Ssot.get_text(skill_id, PARENT_COLUMN, "").strip_edges().to_lower() == ROOT_MARKER:
			root_id = skill_id
			break
	parents[root_id] = ""
	child_count[root_id] = 0

	# Eerst alle parents uit de sheet (als die skill bestaat en geen lus maakt).
	for skill_id in ids:
		if skill_id == root_id:
			continue
		var wanted: String = Ssot.get_text(skill_id, PARENT_COLUMN, "").strip_edges()
		if wanted != "" and wanted != skill_id and wanted in ids:
			parents[skill_id] = wanted
	_break_loops(parents, root_id)

	# Dan de rest: een vaste keuze uit de skills die al in de boom hangen.
	var placed: Array = [root_id]
	for skill_id in parents:
		if skill_id != root_id:
			child_count[parents[skill_id]] = int(child_count.get(parents[skill_id], 0)) + 1
	for skill_id in ids:
		if parents.has(skill_id):
			if not placed.has(skill_id):
				placed.append(skill_id)
			continue
		var candidates: Array = placed.filter(func(p): return int(child_count.get(p, 0)) < AUTO_MAX_CHILDREN)
		if candidates.is_empty():
			candidates = placed
		var pick: String = candidates[absi(hash(skill_id)) % candidates.size()]
		parents[skill_id] = pick
		child_count[pick] = int(child_count.get(pick, 0)) + 1
		placed.append(skill_id)
	return parents


## Een parent-keten die rondloopt (A -> B -> A) of nergens uitkomt, wordt aan het midden gehangen.
static func _break_loops(parents: Dictionary, root_id: String) -> void:
	for skill_id in parents.keys():
		var seen: Dictionary = {}
		var current: String = skill_id
		while current != root_id and parents.has(current) and not seen.has(current):
			seen[current] = true
			current = parents[current]
		if current != root_id:
			push_warning("SkillTreeLayout: parent van '%s' maakt een lus of loopt dood; hangt nu aan het midden." % skill_id)
			parents[skill_id] = root_id


## Geeft een Dictionary skill_id -> Vector2 (plek ten opzichte van het midden). Verschilt per tree_seed.
## Zit een tak ergens klem (geen plek zonder te kruisen), dan wordt de hele boom opnieuw gelegd
## met een afgeleide seed. Dat blijft vast per save, want de afgeleide seeds zijn steeds dezelfde.
static func build_positions(parents: Dictionary, tree_seed: int) -> Dictionary:
	var result: Dictionary = {}
	for attempt in LAYOUT_ATTEMPTS:
		var attempt_seed: int = tree_seed if attempt == 0 else hash([tree_seed, attempt])
		result = _try_layout(parents, attempt_seed)
		if not result.is_empty():
			return result
	push_warning("SkillTreeLayout: geen boom zonder kruisende takken gevonden; de boom is mogelijk te vol.")
	return _try_layout(parents, tree_seed, true)


## Legt de boom één keer. Geeft een lege Dictionary als een tak klem zit (tenzij allow_crossing).
static func _try_layout(parents: Dictionary, tree_seed: int, allow_crossing: bool = false) -> Dictionary:
	var positions: Dictionary = {}
	var outward: Dictionary = {}   # richting (hoek in radialen) waarin elke tak groeit
	var segments: Array = []       # alle getekende takken als [van, naar], om kruisen te voorkomen
	var rng := RandomNumberGenerator.new()
	rng.seed = tree_seed

	var children: Dictionary = {}
	var root_id: String = ""
	for skill_id in parents:
		var parent_id: String = parents[skill_id]
		if parent_id == "":
			root_id = skill_id
		else:
			if not children.has(parent_id):
				children[parent_id] = []
			children[parent_id].append(skill_id)
	if root_id == "":
		return positions

	positions[root_id] = Vector2.ZERO
	outward[root_id] = rng.randf() * TAU

	# Breedte-eerst: eerst alle kinderen van het midden, dan hun kinderen, enzovoort.
	var queue: Array = [root_id]
	while not queue.is_empty():
		var parent_id: String = queue.pop_front()
		var kids: Array = children.get(parent_id, [])
		_shuffle(kids, rng)
		for i in kids.size():
			var skill_id: String = kids[i]
			var base_angle: float
			if parent_id == root_id:
				# Rond het midden: gelijk verdeeld over de hele cirkel, met een beetje speling.
				base_angle = outward[root_id] + TAU * float(i) / float(kids.size())
				base_angle += deg_to_rad(rng.randf_range(-15.0, 15.0))
			else:
				base_angle = outward[parent_id] + deg_to_rad(rng.randf_range(-MAX_BEND_DEGREES, MAX_BEND_DEGREES))
			var spot: Vector2 = _find_spot(positions[parent_id], base_angle, positions, segments, rng)
			if not spot.is_finite():
				if not allow_crossing:
					return {}
				spot = positions[parent_id] + Vector2.from_angle(base_angle) * MAX_LINK_LENGTH * 3.0
			positions[skill_id] = spot
			segments.append([positions[parent_id], spot])
			outward[skill_id] = (spot - positions[parent_id]).angle()
			queue.append(skill_id)
	return positions


## Zoekt een vrije plek in de buurt van de gewenste richting. Lukt het niet, dan wordt de tak langer.
## Geen plek gevonden: geeft Vector2(INF, INF).
static func _find_spot(from: Vector2, angle: float, taken: Dictionary, segments: Array,
		rng: RandomNumberGenerator) -> Vector2:
	var length: float = rng.randf_range(MIN_LINK_LENGTH, MAX_LINK_LENGTH)
	for _round in PLACE_ROUNDS:
		for attempt in PLACE_ATTEMPTS:
			# Eerst dicht bij de gewenste richting zoeken, daarna steeds verder ernaast.
			var spread: float = deg_to_rad(10.0 + 170.0 * float(attempt) / float(PLACE_ATTEMPTS))
			var try_angle: float = angle + rng.randf_range(-spread, spread)
			var spot: Vector2 = from + Vector2.from_angle(try_angle) * length
			if _is_free(spot, from, taken, segments):
				return spot
		length += MIN_LINK_LENGTH * 0.5
	return Vector2(INF, INF)


static func _is_free(spot: Vector2, from: Vector2, taken: Dictionary, segments: Array) -> bool:
	for other in taken.values():
		if spot.distance_to(other) < MIN_NODE_SPACING:
			return false
		if other != from:
			var nearest: Vector2 = Geometry2D.get_closest_point_to_segment(other, from, spot)
			if nearest.distance_to(other) < MIN_LINE_CLEARANCE:
				return false
	# Mag geen bestaande tak kruisen. Takken die bij 'from' beginnen of eindigen raken hem
	# daar vanzelf; die tellen niet.
	for segment in segments:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		if a == from or b == from:
			continue
		if Geometry2D.segment_intersects_segment(from, spot, a, b) != null:
			return false
	return true


## Fisher-Yates met de eigen RNG, zodat dezelfde seed altijd dezelfde volgorde geeft.
static func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = items[i]
		items[i] = items[j]
		items[j] = tmp
