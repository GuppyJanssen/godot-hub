class_name LootDrops
## LootDrops – hoeveel loot een vijand of fabriek laat vallen, welke grondstof, en het neerzetten.
##
## Geen autoload nodig. Alles komt uit de SSOT via EnemyStats: de rij van het type (unit_light,
## unit_heavy, unit_factory), met de factie-modifiers, of een eigen vijand-rij die voorgaat.
##   base_loot_drop    minimum aantal blokjes
##   loot_drop_max     maximum aantal blokjes
##   loot_drop_chance  kans op telkens één blokje extra. Met 3 / 10 / 0.5: 50% kans op 3,
##                     25% op 4, 12,5% op 5, enzovoort.
##   loot_drop_type    welke grondstof: een entry_id van een rij met data_type loot (olrite, metal, biomass ...)
##   base_loot_splatter en de andere splatter-kolommen: zie loot_splatter.gd
##
## FACTIE-LOOT (bovenop de gewone loot hierboven):
##   faction_loot_type    op de FACTIE-rij: welke grondstof deze factie laat vallen (biomass ...).
##                        Hybrides: twee id's met een / ertussen (biomass/circuitry) = loot van beide ouders.
##   faction_loot_chance  op de TYPE-rij (unit_light ...): kans dat er factie-loot valt, 0 t/m 1.
##   faction_loot_min     op de TYPE-rij: minimum aantal blokjes als er factie-loot valt.
##   faction_loot_max     op de TYPE-rij: maximum aantal blokjes.
##   Een eigen vijand-rij (enemy_organic_light) of een _modifier op de factie-rij werkt ook, net als bij
##   de gewone loot. Zo valt er bij een grunt weinig en bij een HQ altijd factie-loot.
##
## EXTRA DROP (los van factie, bijvoorbeeld Keepium van het HQ), op de TYPE-rij:
##   bonus_loot_type      welke grondstof (een loot-rij), bijvoorbeeld keepium. Leeg = geen extra drop.
##   bonus_loot_chance    kans per kill, 0 t/m 1 (HQ: 0.2 = 20%).
##   bonus_loot_min / bonus_loot_max   aantal blokjes als het valt.
##
## Gebruik:
##   var aantal: int = LootDrops.roll_count("a", "light")
##   LootDrops.spawn(get_tree().current_scene, global_position, richting, aantal,
##       LootDrops.resource_id("a", "light"), LootDrops.splatter_settings("a", "light"))

const LOOT_SCENE := "res://Entities/Loot/loot_drop.tscn"

## Zonder SSOT-waarden: 3 tot 10 blokjes, 50% kans op telkens één extra.
const DEFAULT_MIN := 3.0
const DEFAULT_MAX := 10.0
const DEFAULT_CHANCE := 0.5
## Hoeveel losse stukjes er hooguit per keer neervallen (SSOT-rij world, kolom
## loot_max_pieces_per_drop). Valt er meer, dan komt de rest meteen als klompjes en stenen neer.
## De hoeveelheid blijft gelijk; er liggen alleen minder losse stukjes (veel stukjes = framedrops).
const DEFAULT_MAX_PIECES := 24.0
## Hoeveel stukjes loot er hooguit tegelijk liggen (SSOT world, loot_room_budget). 0 = geen grens.
const DEFAULT_ROOM_BUDGET := 150.0


## Hoeveel blokjes er vallen. Zonder factie of type: de standaard hierboven.
static func roll_count(faction: String, unit_type: String) -> int:
	var minimum: float = DEFAULT_MIN
	var maximum: float = DEFAULT_MAX
	var chance: float = DEFAULT_CHANCE
	if faction != "" and unit_type != "":
		minimum = EnemyStats.value(faction, unit_type, "loot_drop", minimum)
		maximum = EnemyStats.value(faction, unit_type, "loot_drop_max", maximum)
		chance = EnemyStats.value(faction, unit_type, "loot_drop_chance", chance)
	var count: int = maxi(0, roundi(minimum))
	var top: int = maxi(count, roundi(maximum))
	chance = clampf(chance, 0.0, 0.99)
	while count < top and randf() < chance:
		count += 1
	return count


## Welke grondstof er valt, als id uit de SSOT (olrite, metal, biomass ...). 'fallback' als de SSOT
## niets zegt of de grondstof niet bestaat.
static func resource_id(faction: String, unit_type: String, fallback: String = "olrite") -> String:
	if fallback == "":
		fallback = "olrite"
	if faction == "" or unit_type == "":
		return fallback
	var wanted: String = LootResources.normalize(EnemyStats.text(faction, unit_type, "loot_drop_type", ""))
	if wanted == "":
		return fallback
	if not LootResources.exists(wanted):
		push_warning("LootDrops: onbekende loot_drop_type '%s' (geen rij met data_type loot)." % wanted)
		return fallback
	return wanted


## De splatter-instellingen. base_loot_splatter = de maximale snelheid; leeg = de standaard.
static func splatter_settings(faction: String, unit_type: String) -> Dictionary:
	var settings: Dictionary = LootSplatter.default_settings()
	if faction == "" or unit_type == "":
		return settings
	settings["max_speed"] = EnemyStats.value(faction, unit_type, LootSplatter.STAT_MAX_SPEED, float(settings["max_speed"]))
	settings["spread_degrees"] = EnemyStats.value(faction, unit_type, LootSplatter.COL_SPREAD, float(settings["spread_degrees"]))
	settings["min_speed"] = EnemyStats.value(faction, unit_type, LootSplatter.COL_MIN_SPEED, float(settings["min_speed"]))
	settings["drag"] = EnemyStats.value(faction, unit_type, LootSplatter.COL_DRAG, float(settings["drag"]))
	settings["start_offset"] = EnemyStats.value(faction, unit_type, LootSplatter.COL_START_OFFSET, float(settings["start_offset"]))
	return settings


## Zet 'count' blokjes van één eenheid neer en laat ze uitspatten in de richting 'hit_dir'.
## Geen richting (Vector2.ZERO)? Dan de lijn van de speler naar 'origin'.
static func spawn(parent: Node, origin: Vector2, hit_dir: Vector2, count: int, resource: String, settings: Dictionary) -> void:
	if count <= 0 or not is_instance_valid(parent):
		return
	if hit_dir == Vector2.ZERO and is_instance_valid(Game.active_player):
		hit_dir = (origin - Game.active_player.global_position).normalized()
	var loot_scene: PackedScene = load(LOOT_SCENE)
	if loot_scene == null:
		return
	var offset: float = float(settings.get("start_offset", LootSplatter.DEFAULT_START_OFFSET))
	for piece_amount in split_into_pieces(count, resource):
		var loot: Node = loot_scene.instantiate()
		loot.init_loot(resource, piece_amount)
		loot.global_position = origin + Vector2(randf_range(-offset, offset), randf_range(-offset, offset))
		loot.launch_splatter(hit_dir, settings)
		parent.add_child(loot)


## Verdeelt 'count' blokjes over stukjes: zoveel mogelijk los, maar nooit meer dan
## loot_max_pieces_per_drop stukjes. Daarboven worden blokjes eerst klompjes, dan stenen.
## Geeft een lijst met de hoeveelheid per stukje (samen precies 'count').
static func split_into_pieces(count: int, resource: String) -> Array:
	var max_pieces: int = maxi(1, roundi(Ssot.get_number("world", "loot_max_pieces_per_drop", DEFAULT_MAX_PIECES)))
	var sizes: Vector2i = LootResources.chunk_sizes(resource)
	# Ligt er al veel loot (loot_room_budget), dan valt de hele drop als één stuk neer. Zo blijft het
	# aantal stukjes (en dus de rekentijd) begrensd, hoe vaak je ook een HQ sloopt.
	var budget: int = roundi(Ssot.get_number("world", "loot_room_budget", DEFAULT_ROOM_BUDGET))
	var room_left: int = budget - LootDrop.live_count
	if budget > 0 and room_left < count:
		if room_left <= 0 or sizes == Vector2i.ZERO:
			return [count]
		max_pieces = mini(max_pieces, room_left)
	var singles: int = count
	var chunks: int = 0
	var stones: int = 0
	# Klompjes: elk klompje vervangt sizes.x losse blokjes door één stukje.
	if singles > max_pieces and sizes.x > 1:
		chunks = mini(ceili(float(singles - max_pieces) / (sizes.x - 1)), floori(float(singles) / sizes.x))
		singles -= chunks * sizes.x
	# Nog steeds te veel? Klompjes samen tot stenen.
	if singles + chunks > max_pieces and sizes.y > sizes.x and sizes.x > 0 and sizes.y % sizes.x == 0:
		var per_stone: int = floori(float(sizes.y) / sizes.x)
		var stones_needed: int = ceili(float(singles + chunks - max_pieces) / maxi(1, per_stone - 1))
		stones = mini(stones_needed, floori(float(chunks) / per_stone))
		chunks -= stones * per_stone
	var pieces: Array = []
	for i in stones:
		pieces.append(sizes.y)
	for i in chunks:
		pieces.append(sizes.x)
	for i in singles:
		pieces.append(1)
	# Past het nog steeds niet (geen klompjes voor deze grondstof)? Dan één stuk met alles erin.
	if pieces.size() > max_pieces:
		return [count]
	return pieces


## Factie-loot: met kans faction_loot_chance valt er per grondstof van de factie (hybrides: beide
## ouders) tussen faction_loot_min en faction_loot_max blokjes. Zie de uitleg bovenaan.
static func spawn_faction_loot(parent: Node, origin: Vector2, hit_dir: Vector2, faction: String, unit_type: String, settings: Dictionary) -> void:
	if faction == "" or unit_type == "":
		return
	var resources_text: String = Ssot.get_text(EnemyStats.faction_row(faction), "faction_loot_type", "")
	if resources_text.strip_edges() == "":
		return
	var chance: float = clampf(EnemyStats.value(faction, unit_type, "faction_loot_chance", 0.0), 0.0, 1.0)
	var minimum: int = maxi(0, roundi(EnemyStats.value(faction, unit_type, "faction_loot_min", 1.0)))
	var maximum: int = maxi(minimum, roundi(EnemyStats.value(faction, unit_type, "faction_loot_max", float(minimum))))
	for part in resources_text.split("/"):
		var id: String = LootResources.normalize(part)
		if id == "" or not LootResources.exists(id):
			push_warning("LootDrops: onbekende faction_loot_type '%s' bij factie %s." % [part, faction])
			continue
		if randf() >= chance:
			continue
		var count: int = randi_range(minimum, maximum)
		spawn(parent, origin, hit_dir, count, id, settings)


## Extra drop van een vijandtype (bijvoorbeeld Keepium van het HQ). Zie de uitleg bovenaan.
static func spawn_bonus_loot(parent: Node, origin: Vector2, hit_dir: Vector2, faction: String, unit_type: String, settings: Dictionary) -> void:
	if unit_type == "":
		return
	var id: String = LootResources.normalize(EnemyStats.text(faction, unit_type, "bonus_loot_type", ""))
	if id == "":
		return
	if not LootResources.exists(id):
		push_warning("LootDrops: onbekende bonus_loot_type '%s' bij %s." % [id, unit_type])
		return
	var chance: float = clampf(EnemyStats.value(faction, unit_type, "bonus_loot_chance", 0.0), 0.0, 1.0)
	if randf() >= chance:
		return
	var minimum: int = maxi(0, roundi(EnemyStats.value(faction, unit_type, "bonus_loot_min", 1.0)))
	var maximum: int = maxi(minimum, roundi(EnemyStats.value(faction, unit_type, "bonus_loot_max", float(minimum))))
	var count: int = randi_range(minimum, maximum)
	spawn(parent, origin, hit_dir, count, id, settings)
