extends Node2D
class_name TestRoom
## TestRoom – de testkamer onder de startkamer (alleen bereikbaar met God Mode).
##
## - Een schietschijf die schade, damage type en schade per seconde laat zien.
## - Testobjecten van één factie: één van elk type uit de SSOT (de rijen unit_<type> met
##   data_type unit_type: light, heavy, factory, en vanzelf ook nieuwe zoals unit_tower of unit_hq).
##   Ze vallen niet aan, komen na 1 seconde terug en droppen wel loot.
##   Wat beweegt (light, medium, heavy) staat op de bovenste rij en gebruikt de vijand-scene.
##   Gebouwen (base_speed 0: factory, tower, hq) staan op een eigen rij met meer ruimte en
##   gebruiken de gebouw-scene; hun base_size telt vanaf een fabriek.
## - Een wisselvlak: vlieg eroverheen om naar de volgende factie te gaan.
## Niets in deze kamer wordt bewaard.

## Welke facties je kunt kiezen, in deze volgorde. Facties zonder SSOT-rijen worden overgeslagen.
const FACTIONS: Array = ["a", "b", "c", "ab", "bc", "ca", "d", "e", "f", "g", "h", "i"]
## Zonder SSOT-rijen: deze types.
const FALLBACK_UNIT_TYPES: Array = ["light", "heavy", "factory"]
## Testobjecten staan in rijen van maximaal zoveel naast elkaar.
const PER_ROW := 5
const UNIT_ROW_Y := 620.0
const UNIT_SPACING := 320.0
## Gebouwen kunnen groot zijn (een HQ is zo'n 3 fabrieken breed), dus meer ruimte.
const BUILDING_ROW_Y := 860.0
const BUILDING_SPACING := 460.0
const PAD_POSITION := Vector2(1640, 330)
const PAD_SIZE := Vector2(200, 90)

var _factions: Array = []
var _index: int = 0
var _respawners: Array = []
var _pad_label: Label


## Zet de testkamer neer in 'parent' (de kamer).
static func build(parent: Node) -> void:
	var room: TestRoom = TestRoom.new()
	# De indeling is gemaakt voor 1920 × 1080; in een grotere kamer staat hij in het midden.
	room.position = (RoomBounds.size() - RoomBounds.BASE_SIZE) / 2.0
	parent.add_child(room)


func _ready() -> void:
	for f in FACTIONS:
		if EnemyStats.exists(str(f), "light"):
			_factions.append(str(f))
	if _factions.is_empty():
		_factions.append("a")

	var dummy: TestDummy = TestDummy.new()
	dummy.position = Vector2(960, 330)
	add_child(dummy)

	var movers: Array = []
	var buildings: Array = []
	for unit_type in _unit_types():
		if TestEnemyRespawner.is_building_type(str(unit_type)):
			buildings.append(str(unit_type))
		else:
			movers.append(str(unit_type))
	_place_row(movers, UNIT_ROW_Y, UNIT_SPACING, 220.0)
	_place_row(buildings, BUILDING_ROW_Y, BUILDING_SPACING, 420.0)

	_build_pad()
	_update_pad_label()


# Zet testobjecten in rijen van PER_ROW naast elkaar, gecentreerd in de kamer.
func _place_row(types: Array, start_y: float, spacing: float, row_gap: float) -> void:
	for k in types.size():
		var respawner: TestEnemyRespawner = TestEnemyRespawner.new()
		respawner.faction = _factions[_index]
		respawner.unit_type = str(types[k])
		var row: int = floori(float(k) / PER_ROW)
		var in_row: int = mini(PER_ROW, types.size() - row * PER_ROW)
		var col: int = k - row * PER_ROW
		respawner.position = Vector2(960.0 + (col - (in_row - 1) / 2.0) * spacing, start_y + row * row_gap)
		add_child(respawner)
		_respawners.append(respawner)


# Alle vijandtypes uit de SSOT: de rijen met data_type unit_type, zonder "unit_" ervoor.
func _unit_types() -> Array:
	var types: Array = []
	for row_id in Ssot.get_ids("unit_type"):
		var type_name: String = str(row_id)
		if type_name.begins_with(EnemyStats.UNIT_PREFIX):
			type_name = type_name.substr(EnemyStats.UNIT_PREFIX.length())
		types.append(type_name)
	return types if not types.is_empty() else FALLBACK_UNIT_TYPES.duplicate()


# Het wisselvlak: een gekleurd vlak met tekst. Erover vliegen = volgende factie.
func _build_pad() -> void:
	var pad: Area2D = Area2D.new()
	pad.position = PAD_POSITION
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = PAD_SIZE
	shape.shape = rect
	pad.add_child(shape)
	var visual: ColorRect = ColorRect.new()
	visual.position = -PAD_SIZE / 2.0
	visual.size = PAD_SIZE
	visual.color = Color(0.2, 0.5, 0.9, 0.5)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.add_child(visual)
	_pad_label = Label.new()
	_pad_label.position = -PAD_SIZE / 2.0
	_pad_label.size = PAD_SIZE
	_pad_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pad_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pad.add_child(_pad_label)
	GameCamera.fit_world_label(_pad_label)
	pad.body_entered.connect(_on_pad_entered)
	# De speler botst via zijn Area2D (groep "player"), niet via zijn CharacterBody2D.
	pad.area_entered.connect(_on_pad_area_entered)
	add_child(pad)


func _on_pad_area_entered(area: Area2D) -> void:
	if area.is_in_group("player"):
		_on_pad_entered(area.get_parent())


func _on_pad_entered(body: Node2D) -> void:
	if body != Game.active_player:
		return
	_index = (_index + 1) % _factions.size()
	for respawner in _respawners:
		respawner.set_faction(_factions[_index])
	_update_pad_label()


func _update_pad_label() -> void:
	var faction: String = _factions[_index]
	var label_name: String = Ssot.get_text(EnemyStats.faction_row(faction), "ingame_name", faction)
	_pad_label.text = "Factie: %s\n(vlieg erover: volgende)" % label_name
