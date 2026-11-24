extends CharacterBody2D
# SSoT TEST-VIJAND: Geconsolideerd met Bewegings-AI, CSV-Geboorte & Loot-Explosies

# --- VARIABELEN (Gekoppeld aan de database) ---
var max_health: int = 50
var current_health: int = 50

# Bewegingsstats (Snelheid waarmee ze achter je aan jagen)
@export var movement_speed: float = 140.0
@export var rotation_speed: float = 4.0

# Editor-keuze voor welk Excel-type deze vijand is
@export_range(1, 6) var test_body_type: int = 1

# --- FACTIE EN TYPE ---
# Samen bepalen ze welke waarden deze vijand krijgt (zie Systems/enemy_stats.gd).
# De fabriek vult ze in bij het maken. Voor een vijand die vast in de kamer staat,
# vul je ze in de Inspector in. Leeg = de oude manier via test_body_type.
@export var faction: String = ""
## Testvijand (testkamer): staat stil, valt niet aan en wordt niet onthouden (dropt wel loot).
@export var passive: bool = false
@export var unit_type: String = ""

# Hoe de stats in de SSOT heten (base_max_health, max_health_modifier, base_speed ...).
const STAT_HEALTH := "max_health"
const STAT_SPEED := "speed"

# --- DRAAIEN ---
## Aan: de vijand draait zijn voorkant naar de speler (zoals een schip).
## Uit: de vijand heeft geen voorkant en tolt rustig rond, zoals iets dat door de ruimte zweeft
## (bijvoorbeeld de organische spore). Zet dit per vijand-scene in de Inspector.
@export var faces_player: bool = true
## Bij tollen: de draaisnelheid wordt bij de geboorte willekeurig gekozen, tussen min en max
## (in radialen per seconde; 1 is ongeveer een zesde rondje per seconde). Linksom of rechtsom is ook willekeurig.
@export var tumble_speed_min: float = 0.3
@export var tumble_speed_max: float = 1.2
## Bij tollen: hoeveel een treffer de draai een zetje geeft.
@export var hit_spin_kick: float = 0.8

## De huidige draaisnelheid bij tollen (radialen per seconde, min = linksom).
var spin: float = 0.0

# --- GEDRAG (komt uit de SSOT, zie _load_behavior) ---
## Wat de vijand doet zolang hij de speler niet heeft opgemerkt (kolom behavior_searching):
##   "hunt"   = weet altijd waar de speler is en komt er meteen op af (standaard)
##   "wander" = zwerft langzaam rond, tot hij de speler ziet of het alarm gaat
var behavior_searching: String = "hunt"
## Wat de vijand doet zodra hij gealarmeerd is (kolom behavior_agro):
##   "chase"         = op de speler af (standaard)
##   "kamikaze"      = snel op de speler af en ontploffen
##   "keep_distance" = op afstand blijven, met de speler in zicht (verkenner)
var behavior_agro: String = "chase"
## Hoe ver de vijand kan kijken, in pixels (kolom behavior_scan_radius). 0 of leeg = blind:
## ziet de speler en voorbijvliegende kogels niet.
var scan_radius: float = 0.0
## Kamikaze: schade en straal van de ontploffing (kolommen base_explosion_damage en base_explosion_radius).
var explosion_damage: float = 25.0
var explosion_radius: float = 120.0

## Snelheden als deel van de gewone snelheid.
@export var wander_speed_factor: float = 0.35
@export var investigate_speed_factor: float = 0.6
@export var kamikaze_speed_factor: float = 2.5
## Kamikaze: op deze afstand van de speler ontploft hij.
@export var kamikaze_trigger_distance: float = 40.0
## Kamikaze: hoeveel loot hij laat vallen als hij zichzelf opblaast (0.1 = 10%).
@export var kamikaze_loot_factor: float = 0.1
## Verkenner: blijft op dit deel van zijn kijkafstand van de speler (0.7 = 70%).
@export var keep_distance_factor: float = 0.7
## Geraakt worden: zoveel seconden duurt het voor deze vijand alarm slaat.
## Schiet je hem binnen die tijd dood, dan gaat er geen alarm af (stil uitschakelen).
@export var hit_alarm_delay: float = 1.5

## Heeft deze vijand de speler opgemerkt (zelf gezien, of via het alarm)?
var alerted: bool = false

## Ongeveer hoe groot de vijand is, voor de kamergrenzen. Groeit mee met base_size.
var body_radius: float = 30.0

const SIGHT_CHECK_SECONDS := 0.2
## Waar een zwervende vijand naartoe mag: de kamer, met een rand van 100 pixels.
const WANDER_AREA := Rect2(100.0, 100.0, 1720.0, 880.0)

var _sight_timer: float = 0.0
## Loopt af na een treffer; bij 0 slaat de vijand alarm. -1 = er loopt niets.
var _hit_alarm_timer: float = -1.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _investigating: bool = false
var _investigate_target: Vector2 = Vector2.ZERO
var _exploding: bool = false
var _loot_factor: float = 1.0

# --- WAPEN (commando's, zie EnemyGun) ---
## Het wapen van deze vijand (entry_id uit de SSOT). Leeg = geen wapen.
var weapon_id: String = ""
var _weapon: SsotWeapon = null
var _fire_cooldown: float = 0.0
var _weapon_label: Label = null

# Levens van de oude testvijanden zonder factie (test_body_type 1 en 2, uit de oude Master-CSV).
const LEGACY_TEST_HEALTH := {1: 50, 2: 80}


func _ready() -> void:
	add_to_group("targets")
	add_to_group("enemies")
	if not passive:
		add_to_group("saveable")  # deze vijand wil onthouden worden (zie game_room.gd)
	
	# 1. DATA LADEN UIT DE SINGLE SOURCE OF TRUTH (SSoT) CSV
	_load_stats()
	
	# Geen voorkant: begin in een willekeurige stand en kies een eigen draaisnelheid.
	if not faces_player:
		global_rotation = randf() * TAU
		spin = randf_range(tumble_speed_min, tumble_speed_max) * (1.0 if randf() < 0.5 else -1.0)
	
	# 2. SSoT GEBOORTE-CHECK (Voorkomt herrijzenis uit de dood)
	# Onzichtbaar tot we weten of dit object deze run al kapot is (anders zie je hem even flitsen).
	if passive:
		return  # testvijand: niets terugzetten of onthouden
	visible = false
	await get_tree().process_frame
	
	if RunState.is_dead(LevelManager.current_layer, LevelManager.current_room_index, name):
		print("RUNSTATE: ", name, " is deze run al gedood. queue_free() geactiveerd!")
		queue_free()
		return
	visible = true
	
	# Was deze vijand er al toen je de kamer verliet? Zet dan zijn HP en zijn plek terug.
	var saved: Dictionary = RunState.get_saved_unit(LevelManager.current_layer, LevelManager.current_room_index, name)
	if not saved.is_empty():
		apply_run_state(saved)
		print("RUNSTATE: ", name, " teruggezet met HP ", current_health, "/", max_health)
	
	# Is er in deze kamer al alarm geslagen voor mijn factie? Dan begin ik meteen in de aanval.
	if not alerted and faction != "":
		if RunState.get_room_change(LevelManager.current_layer, LevelManager.current_room_index, "alarm_" + faction, false):
			alerted = true


# Laadt de waarden van deze vijand. Wordt aangeroepen bij de geboorte, en opnieuw
# als een bewaarde vijand zijn factie en type terugkrijgt.
func _load_stats() -> void:
	if faction != "" and unit_type != "" and EnemyStats.exists(faction, unit_type):
		# NIEUW: factie × type uit de SSOT.
		max_health = int(EnemyStats.value(faction, unit_type, STAT_HEALTH, max_health))
		movement_speed = EnemyStats.value(faction, unit_type, STAT_SPEED, movement_speed)
		_apply_size(EnemyStats.value(faction, unit_type, "size", 1.0))
		print(name, " geboren als factie ", faction, " / ", unit_type, ". HP: ", max_health)
	else:
		# Geen factie of type ingevuld: een oude testvijand. De waarden kwamen vroeger uit de
		# oude Master-CSV (enemy_test_1 en _2); die zijn hier overgenomen tot alles een factie heeft.
		max_health = LEGACY_TEST_HEALTH.get(test_body_type, 50)
	
	# Heeft deze vijand een voorkant? Uit de SSOT (kolom behavior_faces_player, op de rij van de
	# factie of een eigen vijand-rij). 1 = ja, 0 = nee (tolt rond). Leeg = het vinkje in de Inspector telt.
	if faction != "":
		var faces: String = EnemyStats.text(faction, unit_type, "behavior_faces_player", "")
		if faces != "":
			var value: String = faces.replace(",", ".")
			if value.is_valid_float():
				faces_player = value.to_float() != 0.0
			else:
				faces_player = value.to_lower() in ["true", "waar", "ja", "yes"]
	
	_load_behavior()
	_load_weapon()
	
	# De kleur van de factie over de hele vijand. De witte flits bij een treffer zit op de
	# sprite zelf, dus die blijft gewoon werken.
	if faction != "":
		modulate = EnemyStats.color(faction)
	
	current_health = max_health


# Leest het gedrag uit de SSOT: eerst een eigen vijand-rij (enemy_a_light), dan de factie, dan het type.
# Staat er niets, dan blijft het standaardgedrag: meteen op de speler af.
func _load_behavior() -> void:
	if faction == "":
		return
	var searching: String = EnemyStats.text(faction, unit_type, "behavior_searching", "").to_lower()
	if searching in ["hunt", "wander"]:
		behavior_searching = searching
	var agro: String = EnemyStats.text(faction, unit_type, "behavior_agro", "").to_lower()
	if agro in ["chase", "kamikaze", "keep_distance"]:
		behavior_agro = agro
	scan_radius = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_scan_radius", 0.0))
	explosion_damage = EnemyStats.value(faction, unit_type, "explosion_damage", explosion_damage)
	explosion_radius = EnemyStats.value(faction, unit_type, "explosion_radius", explosion_radius)


# Geeft dit type een wapen uit de pool van de factie (SSOT: uses_weapon, weapon_pool).
# Heeft hij er al een (teruggezet uit de save), dan blijft dat wapen.
func _load_weapon() -> void:
	if weapon_id == "" and EnemyGun.uses_weapon(faction, unit_type):
		weapon_id = EnemyGun.pick_weapon(faction)
	_weapon = SsotWeapon.from_ssot(weapon_id, false) if weapon_id != "" else null
	if weapon_id == "":
		return
	# Met een wapen blaas je jezelf niet op: een gewapende vijand van een kamikaze-factie
	# (bijvoorbeeld een Organic-commando) houdt afstand en schiet.
	if behavior_agro == "kamikaze":
		behavior_agro = "keep_distance"
	# Klein naambordje, zodat je ziet welk wapen hij heeft (en straks kunt oprapen).
	if _weapon_label == null:
		_weapon_label = Label.new()
		_weapon_label.position = Vector2(-60, -body_radius - 30)
		_weapon_label.size = Vector2(120, 20)
		_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weapon_label.add_theme_font_size_override("font_size", 12)
		# Los van de draaiing van de vijand (anders draait de tekst mee); positie in _process.
		_weapon_label.top_level = true
		add_child(_weapon_label)
	_weapon_label.text = Ssot.get_text(weapon_id, "ingame_name", weapon_id)


# Schiet op de speler als hij een wapen heeft, de speler ziet en binnen bereik is.
func _try_shoot(player: Node2D, distance: float, delta: float) -> void:
	if _weapon == null:
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0 or distance > _weapon.weapon_range or not _can_see(player):
		return
	_fire_cooldown = EnemyGun.fire_interval(_weapon, faction, unit_type)
	EnemyGun.fire(self, _weapon, player.global_position, body_radius + 8.0)


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# De naam waaraan deze vijand herkend wordt binnen de kamer.
func get_run_id() -> String:
	return str(name)


# Wat deze vijand wil bewaren als je de kamer verlaat of naar het hoofdmenu gaat.
func get_run_state() -> Dictionary:
	if current_health <= 0:
		return {}  # dood: niet bewaren, de dodenlijst regelt dat
	return {
		"keep_name": true,
		"faction": faction,
		"unit_type": unit_type,
		"hp": current_health,
		"x": global_position.x,
		"y": global_position.y,
		"rot": global_rotation,
		"spin": spin,
		"alerted": alerted,
		"weapon": weapon_id,
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	# Eerst factie en type terug, zodat de juiste waarden (max HP, snelheid, kleur) geladen worden.
	# Het wapen eerst, zodat _load_stats() geen nieuw wapen kiest.
	var saved_weapon: String = str(data.get("weapon", weapon_id))
	if saved_weapon != weapon_id:
		weapon_id = saved_weapon
		_load_weapon()
	var saved_faction: String = str(data.get("faction", faction))
	var saved_type: String = str(data.get("unit_type", unit_type))
	if saved_faction != faction or saved_type != unit_type:
		faction = saved_faction
		unit_type = saved_type
		_load_stats()
	current_health = int(data.get("hp", max_health))
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	global_rotation = float(data.get("rot", global_rotation))
	spin = float(data.get("spin", spin))
	alerted = bool(data.get("alerted", alerted))


# Het naambordje van het wapen blijft recht boven de vijand hangen.
func _process(_delta: float) -> void:
	if _weapon_label != null:
		_weapon_label.global_position = global_position + Vector2(-60, -body_radius - 30)


# --- 3. GEDRAG EN BEWEGING (60x per seconde) ---
func _physics_process(delta: float) -> void:
	if _exploding:
		return
	
	# Geen voorkant: gewoon doortollen. In de ruimte remt niets het draaien af.
	if not faces_player:
		global_rotation += spin * delta
	
	# Testvijand: niet bewegen of aanvallen, alleen uitrollen na een zetje.
	if passive:
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		RoomBounds.apply(self, body_radius, true)
		return
	
	var player = Game.active_player
	if not is_instance_valid(player):
		# Rem rustig af tot stilstand als de speler dood of onzichtbaar is
		velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
		move_and_slide()
		RoomBounds.apply(self, body_radius, true)
		return
	
	# Na een treffer: even schrikken, dan pas alarm slaan.
	if _hit_alarm_timer >= 0.0:
		_hit_alarm_timer -= delta
		if _hit_alarm_timer < 0.0 and current_health > 0:
			_raise_alarm()
	
	# Rondkijken, niet elk frame (dat scheelt rekenwerk).
	_sight_timer -= delta
	if _sight_timer <= 0.0:
		_sight_timer = SIGHT_CHECK_SECONDS
		_look_around(player)
	
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized()
	var facing: Vector2 = direction
	
	if alerted or behavior_searching == "hunt":
		match behavior_agro:
			"kamikaze":
				if distance <= kamikaze_trigger_distance:
					_explode()
					return
				velocity = direction * movement_speed * kamikaze_speed_factor
			"keep_distance":
				var keep: float = (scan_radius if scan_radius > 0.0 else 400.0) * keep_distance_factor
				var target_velocity: Vector2 = Vector2.ZERO
				if distance > keep + 40.0 or not _can_see(player):
					target_velocity = direction * movement_speed       # dichterbij, of terug in zicht
				elif distance < keep - 40.0:
					target_velocity = -direction * movement_speed      # te dichtbij: afstand nemen
				velocity = velocity.move_toward(target_velocity, 400.0 * delta)
			_:
				velocity = direction * movement_speed
		if behavior_agro != "kamikaze":
			_try_shoot(player, distance, delta)
	elif _investigating:
		# Een kogel gezien: kijken waar hij vandaan kwam.
		var to_target: Vector2 = _investigate_target - global_position
		if to_target.length() < 30.0:
			_investigating = false
		velocity = velocity.move_toward(to_target.normalized() * movement_speed * investigate_speed_factor, 300.0 * delta)
		facing = velocity
	else:
		_wander(delta)
		facing = velocity
	
	# Draai de neus van de vijand mee (alleen als hij een voorkant heeft).
	if faces_player and facing.length() > 1.0:
		global_rotation = rotate_toward(global_rotation, facing.angle(), rotation_speed * delta)
	
	move_and_slide()
	# Dezelfde bewegingsruimte als de speler (Systems/room_bounds.gd).
	RoomBounds.apply(self, body_radius, true)


# Maakt de vijand groter of kleiner (kolom base_size in de SSOT, 1 = normaal, 1.5 = anderhalf keer zo groot).
# We schalen de onderdelen (sprite, botsvorm, hitbox) en niet de vijand zelf, want Godot
# rekent niet goed met een geschaald physics-lichaam.
func _apply_size(size: float) -> void:
	if size <= 0.0 or is_equal_approx(size, 1.0) or has_meta("size_applied"):
		return
	set_meta("size_applied", true)
	body_radius *= size
	for child in get_children():
		if child is Node2D:
			child.scale *= size


# Rustig rondzwerven: steeds een nieuw punt in de kamer kiezen.
func _wander(delta: float) -> void:
	_wander_timer -= delta
	if _wander_timer <= 0.0 or global_position.distance_to(_wander_target) < 20.0:
		_wander_target = Vector2(
				randf_range(WANDER_AREA.position.x, WANDER_AREA.end.x),
				randf_range(WANDER_AREA.position.y, WANDER_AREA.end.y))
		_wander_timer = randf_range(3.0, 6.0)
	var to_target: Vector2 = (_wander_target - global_position).normalized()
	velocity = velocity.move_toward(to_target * movement_speed * wander_speed_factor, 200.0 * delta)


# Kijkt of de vijand de speler ziet, of een kogel voorbij ziet komen. Blinde vijanden doen niets.
func _look_around(player: Node2D) -> void:
	if scan_radius <= 0.0 or alerted:
		return
	if _can_see(player):
		_raise_alarm()
		return
	if behavior_searching == "hunt":
		return
	# Een kogel van de speler binnen kijkafstand? Ga kijken waar hij vandaan kwam.
	for bullet in get_tree().get_nodes_in_group("projectiles"):
		if not bullet is Node2D:
			continue
		var bullet_pos: Vector2 = bullet.global_position
		if bullet_pos.distance_to(global_position) > scan_radius or not _has_line_of_sight(bullet_pos, null):
			continue
		var flight: Vector2 = bullet.global_transform.x.normalized()
		var travelled: float = float(bullet.get("traveled_distance")) if "traveled_distance" in bullet else scan_radius
		var origin: Vector2 = bullet_pos - flight * travelled
		_investigate_target = Vector2(
				clampf(origin.x, WANDER_AREA.position.x, WANDER_AREA.end.x),
				clampf(origin.y, WANDER_AREA.position.y, WANDER_AREA.end.y))
		if not _investigating:
			print(name, " ziet een kogel en gaat kijken waar hij vandaan kwam.")
		_investigating = true
		return


# Ziet de vijand de speler? Binnen kijkafstand, en niets ertussen.
func _can_see(player: Node2D) -> bool:
	if scan_radius <= 0.0:
		return false
	if global_position.distance_to(player.global_position) > scan_radius:
		return false
	return _has_line_of_sight(player.global_position, player)


# Een denkbeeldige lijn van de vijand naar een punt. Andere vijanden, loot en de speler zelf
# blokkeren het zicht niet; al het andere (later bijvoorbeeld asteroïden) wel.
func _has_line_of_sight(point: Vector2, target: Node) -> bool:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]
	for _attempt in 8:
		var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(global_position, point)
		query.exclude = exclude
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty():
			return true
		var collider = hit.get("collider")
		if target != null and collider == target:
			return true
		if collider is Node and (collider == Game.active_player or collider.is_in_group("enemies")
				or collider.is_in_group("targets") or collider.is_in_group("loot")):
			exclude.append(hit.get("rid"))
			continue
		return false
	return true


# Deze vijand heeft de speler gezien: alle vijanden van zijn factie in deze kamer gaan in de aanval.
func _raise_alarm() -> void:
	if alerted:
		return
	alerted = true
	_investigating = false
	print("ALARM: ", name, " heeft de speler gezien! Factie ", faction, " valt aan.")
	if faction == "":
		return
	# Onthouden voor deze kamer, ook voor vijanden die de fabriek hierna nog maakt.
	RunState.set_room_change(LevelManager.current_layer, LevelManager.current_room_index, "alarm_" + faction, true)
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("on_alarm") and "faction" in other and other.faction == faction:
			other.on_alarm()


# Een andere vijand van mijn factie heeft alarm geslagen.
func on_alarm() -> void:
	alerted = true
	_investigating = false


# Kamikaze: ontploffen. Raakt alles binnen de straal: de speler, andere vijanden en fabrieken.
func _explode() -> void:
	if _exploding:
		return
	_exploding = true
	var center: Vector2 = global_position
	
	var flash_script: Script = load("res://Entities/Effects/explosion_flash.gd")
	if flash_script != null:
		var flash: Node2D = Node2D.new()
		flash.set_script(flash_script)
		flash.set("radius", explosion_radius)
		get_tree().current_scene.add_child(flash)
		flash.global_position = center
	
	var victims: Array = []
	for node in get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("enemies"):
		if node == self or victims.has(node) or not node is Node2D or not node.has_method("take_damage"):
			continue
		if node.global_position.distance_to(center) <= explosion_radius:
			victims.append(node)
	var player = Game.active_player
	if is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(center) <= explosion_radius:
			victims.append(player)
	
	print("BOEM: ", name, " ontploft en raakt ", victims.size(), " doelen.")
	for victim in victims:
		var push: Vector2 = (victim.global_position - center).normalized()
		victim.take_damage(int(round(explosion_damage)), true, push)
	
	# Zelf dood, en maar een fractie van de loot.
	_loot_factor = kamikaze_loot_factor
	current_health = 0
	call_deferred("_deferred_death", Vector2.ZERO)


# --- 4. SCHADE-AFHANDELING EN ARCADE-FLITS ---
func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0: 
		return
		
	current_health = max(0, current_health - amount)
	print(name, " geraakt tijdens het spelen! HP over: ", current_health, "/", max_health)
	
	# Geraakt worden is een duidelijk teken: een vijand die kan kijken, weet zo dat de speler er is.
	# Hij slaat pas alarm na hit_alarm_delay seconden, zodat je hem nog stil kunt uitschakelen.
	if not passive and scan_radius > 0.0 and not alerted and not _exploding and _hit_alarm_timer < 0.0:
		_hit_alarm_timer = hit_alarm_delay
	
	# Een treffer geeft een tollende vijand een zetje, linksom of rechtsom.
	if not faces_player:
		spin = clampf(spin + randf_range(-1.0, 1.0) * hit_spin_kick, -tumble_speed_max * 2.0, tumble_speed_max * 2.0)
	
	if flash and has_method("flash_white"):
		call("flash_white")
	elif flash:
		_flash_white()
	
	if current_health <= 0:
		call_deferred("_deferred_death", hit_dir)


# GECORRIGEERD: Smijt de grunt direct uit de groepen zodat de deuren per direct openvliegen!
func _deferred_death(hit_dir: Vector2) -> void:
	# BINGO: Haal de node direct administratief uit de actieve groepen.
	# Dit voorkomt dat queue_free() de deurenteller in game_room.gd een frame lang gijzelt!
	if is_in_group("targets"): remove_from_group("targets")
	if is_in_group("enemies"): remove_from_group("enemies")
	
	# Testvijand: niets onthouden en geen oorlog, wel loot (om loot en samenklonteren te testen).
	if passive:
		_drop_specific_loot(hit_dir)
		queue_free()
		return
	
	# Onthoud in RunState dat deze vijand dood is. RunState bewaart dat voor de hele run.
	RunState.mark_dead(LevelManager.current_layer, LevelManager.current_room_index, name)
	# De factie-oorlog: de factie in deze kamer wordt iets zwakker.
	var war: Node = get_node_or_null("/root/FactionWar")
	if war != null:
		war.on_enemy_killed(LevelManager.current_layer, LevelManager.current_room_index)
	print("VIJAND: Overlijden van ", name, " onthouden in RunState.")

	_drop_specific_loot(hit_dir)
	queue_free()


# --- 5. SAPPIGE LOOT EXPLOSIE ---
func _drop_specific_loot(hit_dir: Vector2) -> void:
	# Het wapen van een commando kan vallen (SSOT: weapon_drop_chance op de type-rij).
	if weapon_id != "" and randf() < clampf(EnemyStats.value(faction, unit_type, "weapon_drop_chance", 0.0), 0.0, 1.0):
		WeaponPickup.spawn(get_tree().current_scene, weapon_id, global_position)
		print("VIJAND DROP: '", name, "' laat wapen ", weapon_id, " vallen.")
	# Aantal, soort en splatter uit de SSOT (zie Entities/Loot/loot_drops.gd).
	var total_drops: int = LootDrops.roll_count(faction, unit_type)

	# Opgeblazen kamikaze: maar een deel van de loot. Bij 0,3 blokje is er 30% kans op 1 blokje.
	if _loot_factor < 1.0:
		var scaled: float = total_drops * _loot_factor
		total_drops = int(floor(scaled)) + (1 if randf() < scaled - floor(scaled) else 0)

	# Oude testvijanden zonder factie houden hun grondstof uit test_body_type.
	var resource: String = LootDrops.resource_id(faction, unit_type, LootResources.normalize(test_body_type))
	LootDrops.spawn(get_tree().current_scene, global_position, hit_dir, total_drops, resource, LootDrops.splatter_settings(faction, unit_type))
	# Factie-loot (biomass, circuitry ...) bovenop de gewone loot. Een opgeblazen kamikaze geeft geen factie-loot.
	if _loot_factor >= 1.0:
		LootDrops.spawn_faction_loot(get_tree().current_scene, global_position, hit_dir, faction, unit_type, LootDrops.splatter_settings(faction, unit_type))
		LootDrops.spawn_bonus_loot(get_tree().current_scene, global_position, hit_dir, faction, unit_type, LootDrops.splatter_settings(faction, unit_type))
	print("VIJAND DROP: '", name, "' laat ", total_drops, " blokjes vallen.")


# Laat ALLE plaatjes van de vijand even wit oplichten. Eerst werd alleen het eerste plaatje
# met "Sprite" in de naam gebruikt; sinds de nieuwe sprite was dat het oude icoon dat eronder ligt.
func _flash_white() -> void:
	var sprites: Array = []
	for child in find_children("*", "", true, false):
		if (child is Sprite2D or child is AnimatedSprite2D) and child.visible:
			sprites.append(child)
	for s in sprites:
		s.modulate = Color(4.0, 4.0, 4.0, 1.0)
	await get_tree().create_timer(0.055, false).timeout
	for s in sprites:
		if is_instance_valid(s):
			s.modulate = Color.WHITE
