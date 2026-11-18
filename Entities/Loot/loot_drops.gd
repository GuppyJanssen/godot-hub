class_name LootDrops
## LootDrops – hoeveel loot een vijand of fabriek laat vallen, welke grondstof, en het neerzetten.
##
## Geen autoload nodig. Alles komt uit de SSOT via EnemyStats: de rij van het type (unit_light,
## unit_heavy, unit_factory), met de factie-modifiers, of een eigen vijand-rij die voorgaat.
##   base_loot_drop    minimum aantal blokjes
##   loot_drop_max     maximum aantal blokjes
##   loot_drop_chance  kans op telkens één blokje extra. Met 3 / 10 / 0.5: 50% kans op 3,
##                     25% op 4, 12,5% op 5, enzovoort.
##   loot_drop_type    welke grondstof: olrite, metal, keepium, element_1, element_2, element_3
##   base_loot_splatter en de andere splatter-kolommen: zie loot_splatter.gd
##
## Gebruik:
##   var aantal: int = LootDrops.roll_count("a", "light")
##   LootDrops.spawn(get_tree().current_scene, global_position, richting, aantal,
##       LootDrops.currency_index("a", "light"), LootDrops.splatter_settings("a", "light"))

const LOOT_SCENE := "res://Entities/Loot/loot_drop.tscn"
## Volgorde van de grondstoffen. Het nummer van een blokje is de plek in deze lijst + 1 (olrite = 1).
const CURRENCIES := ["olrite", "metal", "keepium", "element_1", "element_2", "element_3"]

## Zonder SSOT-waarden: 3 tot 10 blokjes, 50% kans op telkens één extra.
const DEFAULT_MIN := 3.0
const DEFAULT_MAX := 10.0
const DEFAULT_CHANCE := 0.5


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


## Welke grondstof er valt, als nummer (1 = olrite, 2 = metal ...). 'fallback' als de SSOT niets zegt.
static func currency_index(faction: String, unit_type: String, fallback: int = 1) -> int:
	if faction == "" or unit_type == "":
		return fallback
	var wanted: String = EnemyStats.text(faction, unit_type, "loot_drop_type", "").strip_edges().to_lower().replace(" ", "_")
	if wanted == "":
		return fallback
	for i in CURRENCIES.size():
		if str(CURRENCIES[i]).replace("_", "") == wanted.replace("_", ""):
			return i + 1
	push_warning("LootDrops: onbekende loot_drop_type '%s'." % wanted)
	return fallback


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
static func spawn(parent: Node, origin: Vector2, hit_dir: Vector2, count: int, currency: int, settings: Dictionary) -> void:
	if count <= 0 or not is_instance_valid(parent):
		return
	if hit_dir == Vector2.ZERO and is_instance_valid(Game.active_player):
		hit_dir = (origin - Game.active_player.global_position).normalized()
	var loot_scene: PackedScene = load(LOOT_SCENE)
	if loot_scene == null:
		return
	var offset: float = float(settings.get("start_offset", LootSplatter.DEFAULT_START_OFFSET))
	for i in count:
		var loot: Node = loot_scene.instantiate()
		loot.init_loot(currency, 1)
		loot.global_position = origin + Vector2(randf_range(-offset, offset), randf_range(-offset, offset))
		loot.launch_splatter(hit_dir, settings)
		parent.add_child(loot)
