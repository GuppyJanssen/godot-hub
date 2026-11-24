extends Area2D
class_name WeaponPickup
## WeaponPickup – een wapen dat in de kamer ligt en opgepakt kan worden.
##
## - Vlieg erover: is er een leeg wapenvak, dan pak je het meteen op.
## - Zijn alle vier de vakken vol: druk op F (gebruik-knop) om het wapen dat je nu vasthoudt te ruilen.
##   Dat wapen valt dan op deze plek op de grond en blijft daar liggen.
## - Een opgepakt wapen wordt meteen gekozen.
## - Een wapen dat je al hebt, pak je niet nog een keer op.
## De kamer onthoudt waar een wapen ligt (groep "saveable"), net als loot.

const SCENE_PATH := "res://Entities/Loot/weapon_pickup.tscn"
## De gebruik-knop (voorlopig F).
const SWAP_KEY := KEY_F
## Even wachten voordat je een net gevallen wapen kunt oppakken of ruilen.
const PICKUP_DELAY := 0.6

var weapon_id: String = ""
var _player_inside: Node2D = null
var _delay: float = PICKUP_DELAY
var _swap_key_was_down: bool = true

@onready var name_label: Label = get_node_or_null("NameLabel")
@onready var hint_label: Label = get_node_or_null("HintLabel")


## Maakt een wapen op de grond en zet het in 'parent'. Geeft het nieuwe wapen terug.
static func spawn(parent: Node, id: String, at: Vector2) -> Node:
	var scene: PackedScene = load(SCENE_PATH)
	if scene == null or not is_instance_valid(parent) or id == "":
		return null
	var pickup: Node = scene.instantiate()
	pickup.weapon_id = id
	pickup.position = at
	parent.add_child(pickup)
	return pickup


func _ready() -> void:
	add_to_group("saveable")
	add_to_group("weapon_pickups")
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	_refresh_labels()


func _process(delta: float) -> void:
	_delay = maxf(0.0, _delay - delta)
	if not is_instance_valid(_player_inside):
		_player_inside = null
		return
	if _delay > 0.0:
		return
	# Ruilen alleen bij een nieuwe druk op F (niet door hem ingedrukt te houden).
	var swap_down: bool = Input.is_key_pressed(SWAP_KEY)
	if swap_down and not _swap_key_was_down:
		_try_pickup(true)
	_swap_key_was_down = swap_down


func _on_body_entered(body: Node2D) -> void:
	if not _is_player(body):
		return
	_player_inside = body
	_swap_key_was_down = Input.is_key_pressed(SWAP_KEY)
	if _delay <= 0.0:
		_try_pickup(false)
	_refresh_labels()


func _on_body_exited(body: Node2D) -> void:
	if body == _player_inside:
		_player_inside = null
		_refresh_labels()


func _is_player(body: Node) -> bool:
	return is_instance_valid(body) and (body.is_in_group("player") or "player" in body.name.to_lower())


func _try_pickup(swap: bool) -> void:
	if weapon_id == "" or RunState.has_weapon(weapon_id):
		_refresh_labels()
		return
	# Een leeg vak? Dan meteen oppakken.
	if RunState.add_weapon(weapon_id) >= 0:
		print("WAPEN: ", weapon_id, " opgepakt.")
		_tell_player()
		queue_free()
		return
	if not swap:
		_refresh_labels()
		return
	# Alles vol: ruil met het wapen dat de speler nu vasthoudt.
	var dropped: String = RunState.replace_selected_weapon(weapon_id)
	if dropped == "":
		_refresh_labels()
		return
	print("WAPEN: ", dropped, " geruild voor ", weapon_id, ".")
	var new_pickup: Node = spawn(get_parent(), dropped, position)
	if new_pickup != null:
		new_pickup._delay = PICKUP_DELAY
	_tell_player()
	queue_free()


func _tell_player() -> void:
	var player: Node = Game.active_player
	if is_instance_valid(player) and player.has_method("on_weapons_changed"):
		player.on_weapons_changed()


func _refresh_labels(message: String = "") -> void:
	if is_instance_valid(name_label):
		name_label.text = Ssot.get_text(weapon_id, "ingame_name", weapon_id)
	if not is_instance_valid(hint_label):
		return
	var text: String = message
	if text == "" and _player_inside != null:
		if RunState.has_weapon(weapon_id):
			text = "Heb je al"
		else:
			var current: String = RunState.selected_weapon()
			text = "F: ruil met " + Ssot.get_text(current, "ingame_name", current)
	hint_label.text = text
	hint_label.visible = text != ""


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

func get_run_id() -> String:
	return "weapon_" + str(get_instance_id())


func get_run_state() -> Dictionary:
	return {"weapon_id": weapon_id, "x": global_position.x, "y": global_position.y}


func apply_run_state(data: Dictionary) -> void:
	weapon_id = str(data.get("weapon_id", weapon_id))
	global_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	_delay = 0.0
	_refresh_labels()
