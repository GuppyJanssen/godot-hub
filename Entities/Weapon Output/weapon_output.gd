extends Area2D
# BEDIENING: Kogel/Projectiel (Volledig F1 Dashboard-Bewust!)

@export var speed: float = 700.0
## Schade per treffer. Een kommagetal, zodat skills (+1% per level) niet wegvallen door afronden.
## Pas bij de treffer wordt hij afgerond (minimaal 1).
@export var damage: float = 10.0
## Grootte uit de SSOT (base_size van het wapen, met skills). Zet dit vóór add_child.
var size_scale: float = 1.0
## Het damage type van het wapen (base_damage_type in de SSOT), voor de testdummy en later de counters.
var damage_type: String = ""
## Kogel van een vijand (commando): raakt alleen de speler, en de F1-instellingen van de speler
## (schade, grootte, snelheid, bereik) gelden er niet voor. Zet dit vóór add_child.
var from_enemy: bool = false
## Bereik voor een vijandkogel (het bereik van zijn wapen). Bij spelerkogels komt het van de speler.
var range_override: float = -1.0

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

	if from_enemy:
		weapon_range = range_override if range_override > 0.0 else FALLBACK_RANGE
		# De speler heeft alleen een Area2D (groep "player"), geen botsvorm op zijn lichaam.
		area_entered.connect(_on_area_entered)
		return

	var size_mult: float = Game.debug_bullet_size_multiplier if Game.debug_bullet_size_multiplier > 0.0 else 1.0
	var speed_mult: float = Game.debug_bullet_speed_multiplier if Game.debug_bullet_speed_multiplier > 0.0 else 1.0

	var final_size: float = maxf(0.05, size_scale) * size_mult
	scale = Vector2(final_size, final_size)
	speed *= speed_mult

	# F1-schade: een kommagetal (0,3x moet ook werken; vroeger werd dat afgerond naar 0).
	if Game.debug_damage_multiplier > 0.0:
		damage *= Game.debug_damage_multiplier
	
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


# Vijandkogel raakt de speler.
func _on_area_entered(area: Area2D) -> void:
	if not from_enemy or not is_instance_valid(area) or not area.is_in_group("player"):
		return
	var player: Node = area.get_parent()
	if is_instance_valid(player) and player.has_method("take_damage"):
		player.take_damage(damage)
	queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if from_enemy:
		return  # vijandkogels raken geen andere vijanden of gebouwen
	if body.is_in_group("targets") or body.is_in_group("Enemies") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			# De vliegrichting van de kogel gaat mee, zodat de loot de goede kant op spat.
			var impact_direction: Vector2 = transform.x.normalized()
			# Wie het wil weten (de testdummy), hoort eerst welk damage type deze treffer heeft.
			if body.has_method("on_hit_info"):
				body.on_hit_info(damage, damage_type)
			body.take_damage(hit_damage(), true, impact_direction)
		queue_free()


## De schade als heel getal voor take_damage: afgerond, en minimaal 1 als er schade is.
func hit_damage() -> int:
	if damage <= 0.0:
		return 0
	return maxi(1, roundi(damage))


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
		"size": scale.x,
		"range": weapon_range,
		"traveled": traveled_distance,
		"enemy": from_enemy,
	}


# Zet de bewaarde gegevens terug. Snelheid en schade zijn bewaard MET de F1-vermenigvuldigers
# erin, dus ze worden hier gewoon overgenomen en niet nog een keer vermenigvuldigd.
func apply_run_state(data: Dictionary) -> void:
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	global_rotation = float(data.get("rot", global_rotation))
	speed = float(data.get("speed", speed))
	damage = float(data.get("damage", damage))
	var saved_size: float = float(data.get("size", scale.x))
	if saved_size > 0.0:
		scale = Vector2(saved_size, saved_size)
	weapon_range = float(data.get("range", weapon_range))
	traveled_distance = float(data.get("traveled", traveled_distance))
	if bool(data.get("enemy", false)) and not from_enemy:
		from_enemy = true
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)
