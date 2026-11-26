extends Area2D
# BEDIENING: Kogel/Projectiel (Volledig F1 Dashboard-Bewust!)
## Alle waarden komen van het wapen (SsotWeapon) en worden vóór add_child gezet door de schutter
## (Player.gd of EnemyGun). Effecten uit de SSOT:
##   base_pierce_count      zoveel vijanden extra doorboren voordat de kogel stopt
##   base_bounce_count      zoveel keer stuiteren: tegen de rand van de kamer of van een vijand af
##   base_knockback_force   duw op wat geraakt wordt (pixels per seconde erbij)
##   base_explosion_damage / base_explosion_radius   ontploffen bij een treffer of aan het eind van
##                          het bereik; raakt alles binnen de straal (spelerkogels: vijanden en
##                          gebouwen, vijandkogels: de speler en ALLE facties, ook de eigen:
##                          friendly fire)
## Ontwikkelaarsnotitie: een kogel raakt hetzelfde doel nooit twee keer (_hit_ids), ook niet bij pierce.

@export var speed: float = 700.0
## Schade per treffer. Een kommagetal, zodat skills (+1% per level) niet wegvallen door afronden.
## Pas bij de treffer wordt hij afgerond (minimaal 1).
@export var damage: float = 10.0
## Grootte uit de SSOT (base_size van het wapen, met skills). Zet dit vóór add_child.
var size_scale: float = 1.0
## Het damage type van het wapen (base_damage_type in de SSOT), voor de testdummy en later de counters.
var damage_type: String = ""
## Kogel van een vijand (commando): raakt de speler en units/gebouwen van ANDERE facties (niet de
## eigen factie), en de F1-instellingen van de speler (schade, grootte, snelheid, bereik) gelden er
## niet voor. Zet dit vóór add_child.
var from_enemy: bool = false
## De factie van de schutter (alleen bij from_enemy). Zet EnemyGun vóór add_child.
var shooter_faction: String = ""
## Bereik van het wapen. De schutter zet dit; -1 = uit de wapenwaarden van de speler lezen (oud).
var range_override: float = -1.0
## Snelheid van de schutter op het moment van schieten. Een deel ervan gaat mee met de kogel
## (world: shot_inherit_velocity), in alle richtingen: vooruit vliegend schiet je verder, achteruit
## minder ver, zijwaarts gaat de kogel schuin mee (zoals in Isaac). Zet dit vóór add_child.
var shooter_velocity: Vector2 = Vector2.ZERO
## De kogel gaat nooit langzamer dan dit deel van zijn eigen snelheid (ook niet bij hard achteruit).
const MIN_INHERIT_FACTOR := 0.3
## Homing (lock-on op het maximale level): hierheen bijsturen, met turn_speed radialen per seconde.
## Zet de schutter vóór add_child (Player); null = rechtdoor.
var homing_target: Node2D = null
var homing_turn_speed: float = 0.0
var pierce_left: int = 0
var bounce_left: int = 0
var knockback_force: float = 0.0
var explosion_damage: float = 0.0
var explosion_radius: float = 0.0
var _hit_ids: Dictionary = {}
var _exploded: bool = false

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
	# Hitbox passend bij de sprite; de schaal van de kogel (base_size) geldt daarna voor beide.
	SpriteFit.fit(self)

	if from_enemy:
		weapon_range = range_override if range_override > 0.0 else FALLBACK_RANGE
		var enemy_size: float = maxf(0.05, size_scale)
		scale = Vector2(enemy_size, enemy_size)
		_apply_shooter_velocity()
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
		explosion_damage *= Game.debug_damage_multiplier
	
	weapon_range = range_override if range_override > 0.0 else _read_weapon_range()
	if Game.debug_range_multiplier:
		weapon_range *= Game.debug_range_multiplier
	_apply_shooter_velocity()


# Vaart van de schutter erbij (als vector). De kogel draait mee naar de nieuwe richting en het bereik
# groeit en krimpt mee, zodat hij even lang vliegt: meer vaart = verder (zoals in The Binding of Isaac).
func _apply_shooter_velocity() -> void:
	var inherit: float = clampf(Ssot.get_number("world", "shot_inherit_velocity", 0.75), 0.0, 2.0)
	if inherit <= 0.0 or speed <= 0.0 or shooter_velocity == Vector2.ZERO:
		return
	var aim: Vector2 = Vector2.from_angle(global_rotation)
	var flight: Vector2 = aim * speed + shooter_velocity * inherit
	var new_speed: float = flight.length()
	if new_speed < speed * MIN_INHERIT_FACTOR:
		# Bijna stil of achteruit: dan toch vooruit, met de minimale snelheid.
		flight = aim * speed * MIN_INHERIT_FACTOR
		new_speed = flight.length()
	weapon_range *= new_speed / speed
	speed = new_speed
	global_rotation = flight.angle()


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
	# Homing: bijsturen naar het vastgezette doel, zo snel als de speler zelf kan draaien.
	if homing_target != null:
		if is_instance_valid(homing_target) and not homing_target.is_queued_for_deletion():
			var wanted: float = (homing_target.global_position - global_position).angle()
			global_rotation = rotate_toward(global_rotation, wanted, homing_turn_speed * delta)
		else:
			homing_target = null  # doel weg: verder rechtdoor
	var move_amount: float = speed * delta
	# Richting zonder schaal: transform.x is zo lang als de schaal van de kogel (base_size). Een kleine
	# kogel (pistool 0,5) vloog daardoor half zo snel en kwam maar tot de helft van zijn bereik.
	global_position += transform.x.normalized() * move_amount
	
	# Stuiteren tegen de rand van de kamer.
	if bounce_left > 0:
		var pos: Vector2 = global_position
		var bounced: bool = false
		var room: Vector2 = RoomBounds.size()
		if pos.x < 0.0 or pos.x > room.x:
			global_rotation = PI - global_rotation
			pos.x = clampf(pos.x, 0.0, room.x)
			bounced = true
		if pos.y < 0.0 or pos.y > room.y:
			global_rotation = -global_rotation
			pos.y = clampf(pos.y, 0.0, room.y)
			bounced = true
		if bounced:
			global_position = pos
			bounce_left -= 1
			_hit_ids.clear()  # na een stuit tegen de rand mag hij vijanden opnieuw raken
	
	# Bereik-controle: ruim de kogel op als zijn bereik op is (een explosieve kogel ontploft dan).
	traveled_distance += move_amount
	if traveled_distance >= weapon_range:
		_explode()
		queue_free()


# Vijandkogel raakt de speler.
func _on_area_entered(area: Area2D) -> void:
	if not from_enemy or not is_instance_valid(area) or not area.is_in_group("player"):
		return
	var player: Node = area.get_parent()
	if not is_instance_valid(player) or _hit_ids.has(player.get_instance_id()):
		return
	_hit_ids[player.get_instance_id()] = true
	if player.has_method("take_damage"):
		player.take_damage(DamageCalc.scaled(damage, damage_type, player))
	if knockback_force > 0.0 and "velocity" in player:
		player.velocity += transform.x.normalized() * knockback_force
	_after_hit(player)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if from_enemy and not TargetPicker.is_hostile_to(shooter_faction, body):
		return  # vijandkogels gaan door de eigen factie heen (en raken niets zonder factie)
	if body.is_in_group("targets") or body.is_in_group("Enemies") or body.is_in_group("enemies"):
		if _hit_ids.has(body.get_instance_id()):
			return  # dit doel is al geraakt (pierce/bounce)
		_hit_ids[body.get_instance_id()] = true
		# De vliegrichting van de kogel gaat mee, zodat de loot de goede kant op spat.
		var impact_direction: Vector2 = transform.x.normalized()
		if body.has_method("take_damage"):
			# Wie het wil weten (de testdummy), hoort eerst welk damage type deze treffer heeft.
			if body.has_method("on_hit_info"):
				body.on_hit_info(damage, damage_type)
			# Resistances en zwaktes van het doel tellen mee (DamageCalc).
			if from_enemy:
				DamageCalc.mark_attacker(body, shooter_faction)
			body.take_damage(DamageCalc.scaled(damage, damage_type, body), true, impact_direction)
		if knockback_force > 0.0 and "velocity" in body:
			body.velocity += impact_direction * knockback_force
		_after_hit(body)


# Na een treffer: ontploffen, doorboren, stuiteren of verdwijnen (in die volgorde).
func _after_hit(target: Node2D) -> void:
	if explosion_radius > 0.0 and explosion_damage > 0.0:
		_explode()
		queue_free()
	elif pierce_left > 0:
		pierce_left -= 1
	elif bounce_left > 0:
		bounce_left -= 1
		# Na een stuit mag de kogel eerdere doelen opnieuw raken (heen en weer tussen twee vijanden);
		# alleen het doel waar hij net vanaf stuit niet, anders raakt hij het meteen nog eens.
		_hit_ids = {target.get_instance_id(): true}
		var normal: Vector2 = (global_position - target.global_position).normalized()
		if normal == Vector2.ZERO:
			normal = -transform.x.normalized()
		global_rotation = transform.x.normalized().bounce(normal).angle()
	else:
		queue_free()


# Ontploffing: schade aan alles binnen explosion_radius (één keer per kogel).
func _explode() -> void:
	if _exploded or explosion_radius <= 0.0 or explosion_damage <= 0.0 or not is_inside_tree():
		return
	_exploded = true
	var center: Vector2 = global_position
	var flash_script: Script = load("res://Entities/Effects/explosion_flash.gd")
	if flash_script != null:
		var flash: Node2D = Node2D.new()
		flash.set_script(flash_script)
		flash.set("radius", explosion_radius)
		get_tree().current_scene.add_child(flash)
		flash.global_position = center
	if from_enemy:
		var player: Node2D = Game.active_player
		if is_instance_valid(player) and player.global_position.distance_to(center) <= explosion_radius:
			player.take_damage(DamageCalc.scaled(explosion_damage, damage_type, player))
		if shooter_faction == "":
			return
	var victims: Dictionary = {}
	for node in get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("enemies"):
		if victims.has(node) or not node is Node2D or not node.has_method("take_damage"):
			continue
		# Vijandbom: friendly fire, dus ook de eigen factie (de schutter heeft vooraf gekeken of het
		# de moeite is, zie TargetPicker.aoe_ok). Zonder factie (testdummy) niet.
		if from_enemy and not ("faction" in node and str(node.faction) != ""):
			continue
		if node.global_position.distance_to(center) <= explosion_radius:
			victims[node] = true
	for victim in victims:
		var push: Vector2 = (victim.global_position - center).normalized()
		if victim.has_method("on_hit_info"):
			victim.on_hit_info(explosion_damage, damage_type)
		if from_enemy:
			DamageCalc.mark_attacker(victim, shooter_faction)
		victim.take_damage(DamageCalc.scaled(explosion_damage, damage_type, victim), true, push)


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
	var room: Rect2 = Rect2(Vector2(-200.0, -200.0), RoomBounds.size() + Vector2(400.0, 400.0))
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
		"faction": shooter_faction,
		"type": damage_type,
		"pierce": pierce_left,
		"bounce": bounce_left,
		"knockback": knockback_force,
		"explosion_damage": explosion_damage,
		"explosion_radius": explosion_radius,
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
	pierce_left = maxi(0, SaveSystem._safe_int(data.get("pierce", 0)))
	bounce_left = maxi(0, SaveSystem._safe_int(data.get("bounce", 0)))
	knockback_force = maxf(0.0, SaveSystem._safe_float(data.get("knockback", 0.0)))
	explosion_damage = maxf(0.0, SaveSystem._safe_float(data.get("explosion_damage", 0.0)))
	explosion_radius = maxf(0.0, SaveSystem._safe_float(data.get("explosion_radius", 0.0)))
	# Factie en damage type: alleen korte, nette namen (een aangepaste save kan van alles bevatten).
	var saved_faction: String = str(data.get("faction", ""))
	if saved_faction.length() <= 2 and (saved_faction == "" or saved_faction.is_valid_identifier()):
		shooter_faction = saved_faction
	var saved_type: String = str(data.get("type", damage_type))
	if saved_type.length() <= 24 and (saved_type == "" or saved_type.is_valid_identifier()):
		damage_type = saved_type
	if bool(data.get("enemy", false)) and not from_enemy:
		from_enemy = true
		if not area_entered.is_connected(_on_area_entered):
			area_entered.connect(_on_area_entered)
