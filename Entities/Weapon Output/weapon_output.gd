extends Area2D
# BEDIENING: Kogel/Projectiel (Volledig F1 Dashboard-Bewust!)

@export var speed: float = 700.0
@export var damage: int = 10
## Het damage type van het wapen (base_damage_type in de SSOT), voor de testdummy en later de counters.
var damage_type: String = ""

# Bereik: komt uit de CSV via de wapenwaarden van de speler. Is het bereik op, dan verdwijnt de kogel.
const FALLBACK_RANGE := 600.0
var weapon_range: float = FALLBACK_RANGE
var traveled_distance: float = 0.0

# Zorgt dat de waarschuwing over een ontbrekend bereik maar één keer verschijnt.
static var _range_warning_shown: bool = false


func _ready() -> void:
	add_to_group("projectiles")
	# Deze kogel wil onthouden worden (zie game_room.gd), maar alleen bij
	# "terug naar hoofdmenu". Bij een kamerwissel vervalt hij.
	add_to_group("saveable")
	add_to_group("save_only_on_quit")

	var size_mult = Game.debug_bullet_size_multiplier if Game.debug_bullet_size_multiplier else 1.0
	var speed_mult = Game.debug_bullet_speed_multiplier if Game.debug_bullet_speed_multiplier else 1.0

	scale = Vector2(size_mult, size_mult)
	speed *= speed_mult

	if Game.debug_damage_multiplier:
		damage *= int(Game.debug_damage_multiplier)
	
	weapon_range = _read_weapon_range()
	if Game.debug_range_multiplier:
		weapon_range *= Game.debug_range_multiplier


# Haalt het bereik van het actieve wapen op uit de wapenwaarden van de speler
# (dezelfde bron die weapon.gd gebruikt, en die uit de CSV gevuld wordt).
func _read_weapon_range() -> float:
	var player = Game.active_player
	if is_instance_valid(player) and "current_weapon_stats" in player:
		var stats = player.current_weapon_stats
		if stats is Dictionary:
			for key in ["weapon_range", "range", "base_range"]:
				if stats.has(key):
					return float(stats[key])
	
	if not _range_warning_shown:
		_range_warning_shown = true
		push_warning("KOGEL: geen bereik gevonden in de wapenwaarden van de speler. Standaard %s gebruikt." % FALLBACK_RANGE)
	return FALLBACK_RANGE


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().paused: return

	# GECORRIGEERD: Gebruikt de betrouwbare transform-richting van Godot 4.7
	# Dit voorkomt dat de kogel bij een verkeerde rotatie-matrix naar (0,0) schiet!
	var move_amount: float = speed * delta
	global_position += transform.x * move_amount
	
	# Bereik-controle: ruim de kogel op als zijn bereik op is.
	traveled_distance += move_amount
	if traveled_distance >= weapon_range:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if body.is_in_group("targets") or body.is_in_group("Enemies") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			# De vliegrichting van de kogel gaat mee, zodat de loot de goede kant op spat.
			var impact_direction: Vector2 = transform.x.normalized()
			# Wie het wil weten (de testdummy), hoort eerst welk damage type deze treffer heeft.
			if body.has_method("on_hit_info"):
				body.on_hit_info(damage, damage_type)
			body.take_damage(damage, true, impact_direction)
		queue_free()


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# Een kogel heeft geen vaste naam, dus elke kogel krijgt een eigen nummer.
func get_run_id() -> String:
	return "bullet_" + str(get_instance_id())


# Wat deze kogel wil bewaren: plek, richting, snelheid, schade en hoe ver hij al gevlogen heeft.
func get_run_state() -> Dictionary:
	# Een kogel die al ver buiten de kamer vliegt, hoeft niet bewaard te worden.
	var room: Rect2 = Rect2(-200.0, -200.0, 1920.0 + 400.0, 1080.0 + 400.0)
	if not room.has_point(global_position):
		return {}
	return {
		"x": global_position.x,
		"y": global_position.y,
		"rot": global_rotation,
		"speed": speed,
		"damage": damage,
		"range": weapon_range,
		"traveled": traveled_distance,
	}


# Zet de bewaarde gegevens terug. Snelheid en schade zijn bewaard MET de F1-vermenigvuldigers
# erin, dus ze worden hier gewoon overgenomen en niet nog een keer vermenigvuldigd.
func apply_run_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	global_rotation = float(data.get("rot", global_rotation))
	speed = float(data.get("speed", speed))
	damage = int(data.get("damage", damage))
	weapon_range = float(data.get("range", weapon_range))
	traveled_distance = float(data.get("traveled", traveled_distance))
