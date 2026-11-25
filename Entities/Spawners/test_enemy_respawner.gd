extends Node2D
class_name TestEnemyRespawner
## TestEnemyRespawner – zet in de testkamer één passief testobject neer (vijand of fabriek),
## en een nieuwe als het kapot is (na RESPAWN_SECONDS). Het valt niet aan, maakt geen vijanden
## en wordt niet bewaard, maar dropt wel loot. Met set_faction() wissel je van factie.

const ENEMY_SCENE := "res://Entities/Objects/test_body.tscn"
const FACTORY_SCENE := "res://Entities/Spawners/factory.tscn"
const RESPAWN_SECONDS := 1.0

var faction: String = "a"
## Een unit_type uit de SSOT: "light", "heavy", "factory", "tower", "hq" ...
var unit_type: String = "light"
var _object: Node = null
var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(-90, 70)
	_label.size = Vector2(180, 24)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	GameCamera.fit_world_label(_label)
	_spawn()


## Wissel van factie: het huidige object verdwijnt en er komt meteen een nieuw.
func set_faction(new_faction: String) -> void:
	faction = new_faction
	if is_instance_valid(_object):
		if _object.tree_exited.is_connected(_on_object_gone):
			_object.tree_exited.disconnect(_on_object_gone)
		_object.queue_free()
	_object = null
	_spawn()


func _spawn() -> void:
	if not is_inside_tree():
		return
	var label_name: String = Ssot.get_text(EnemyStats.faction_row(faction), "ingame_name", faction)
	_label.text = "%s %s" % [label_name, unit_type]
	var is_building: bool = is_building_type(unit_type)
	# Naam onder het object; een groot gebouw (HQ) heeft zijn naam verder naar beneden.
	var label_y: float = 70.0
	if is_building:
		label_y = maxf(label_y, 62.0 * EnemyStats.value(faction, unit_type, "size", 1.0) + 12.0)
	_label.position = Vector2(-90, label_y)
	var scene: PackedScene = load(FACTORY_SCENE if is_building else ENEMY_SCENE)
	if scene == null:
		push_error("TestEnemyRespawner: scene niet gevonden.")
		return
	_object = scene.instantiate()
	_object.faction = faction
	_object.passive = true
	if is_building:
		_object.building_type = unit_type
		_object.spawn_unit_type = "light"
	else:
		_object.unit_type = unit_type
	_object.name = "Test_%s_%s_%d" % [faction, unit_type, get_instance_id()]
	_object.position = position
	_object.tree_exited.connect(_on_object_gone)
	# Uitgesteld: _spawn kan midden in een physics-stap komen (bijvoorbeeld als de testkamer opent
	# of een object net kapot is). Dan mag Godot geen nieuwe botsvormen toevoegen.
	get_parent().add_child.call_deferred(_object)


## Een gebouw staat stil: base_speed 0 in de SSOT (fabriek, toren, HQ). Die krijgen de gebouw-scene,
## met de grootte ten opzichte van een fabriek. Alles wat beweegt krijgt de vijand-scene.
static func is_building_type(type: String) -> bool:
	if type == "factory":
		return true
	var row: String = EnemyStats.unit_row(type)
	return Ssot.has_value(row, "base_speed") and Ssot.get_number(row, "base_speed", 1.0) == 0.0


func _on_object_gone() -> void:
	# Ook bij het verlaten van de kamer verdwijnt het object; dan niets meer doen.
	if not is_inside_tree() or is_queued_for_deletion():
		return
	_object = null
	# De timer is aan deze node gekoppeld: verdwijnt de node, dan vervalt de timer ook.
	get_tree().create_timer(RESPAWN_SECONDS, false).timeout.connect(_spawn)
