extends CharacterBody2D
# SSoT TEST-VIJAND: Geconsolideerd met Bewegings-AI, CSV-Geboorte & Loot-Explosies

# --- VARIABELEN (Gekoppeld aan de database) ---
var max_health: int = 50
var current_health: int = 50

# Bewegingsstats (Snelheid waarmee ze achter je aan jagen)
@export var movement_speed: float = 140.0
@export var rotation_speed: float = 4.0
## Versnellen en afremmen (pixels per seconde²). Komen uit de SSOT: base_acceleration en
## base_friction van het type (met _modifier van type en factie). Dit zijn de standaarden als die leeg zijn.
var acceleration: float = 400.0
var friction: float = 300.0
## Schild (max_shield, shield_regen_amount, shield_regen_delay in de SSOT). Zie EnemyShield.
var shield: EnemyShield = null

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
## Waar een zwervende vijand naartoe mag: de kamer, met een rand van WANDER_MARGIN pixels.
const WANDER_MARGIN := 100.0

var _sight_timer: float = 0.0
## Loopt af na een treffer; bij 0 slaat de vijand alarm. -1 = er loopt niets.
var _hit_alarm_timer: float = -1.0
## Seconden tot het alarm van een andere vijand binnenkomt (communicatievertraging). -1 = niets onderweg.
var _pending_alarm: float = -1.0
var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0
var _investigating: bool = false
var _investigate_target: Vector2 = Vector2.ZERO
var _exploding: bool = false
# Doel van een ANDERE factie (unit of gebouw) waar deze vijand nu op aanvalt, of null = de speler.
# Gekozen door TargetPicker (zwakte in bereik), elke zoekronde opnieuw. Niet bewaard.
var _unit_target: Node2D = null
# Seconden tot deze vijand weer contactschade mag doen aan een unit van een andere factie.
var _contact_left: float = 0.0
# Terugstoot die nog doorwerkt (zie apply_knockback).
var _knockback: Vector2 = Vector2.ZERO
# Voor F1 "AI-labels": wat de vijand deze frame doet, en het label zelf.
var _ai_state: String = ""
var _ai_label: Label = null
# Iets speling bij "aanraken" van een andere unit (pixels), zodat duwen ook telt.
const CONTACT_SLACK := 6.0
# Jagers (behavior_searching "hunt") jagen alleen op de speler als ze hem zien (kijkafstand + zicht).
# Ziet een unit de speler, dan hoort de rest van zijn factie de plek, na de communicatievertraging,
# en wie niet in gevecht is gaat die kant op.
var _player_in_sight: bool = false
# Communicatie (Daan, 26 nov): berichten van de eigen factie komen na de communicatievertraging binnen.
# Meerdere berichten: eerst naar de dichtstbijzijnde.
#   _leads          plekken waar de speler gezien is (Vector2), hooguit MAX_LEADS
#   _told_targets   units/gebouwen van andere facties die een factiegenoot zag (bijv. scout -> spores)
#   _pending        berichten die nog onderweg zijn: [seconden_over, plek of node]
var _leads: Array[Vector2] = []
var _told_targets: Array = []
var _pending: Array = []
var _share_left: float = 0.0
var _share_unit_left: float = 0.0
const MAX_LEADS := 4
const MAX_PENDING := 8
# Veiligheidsgrenzen voor een momentopname uit een save (geen gameplaywaarden).
const SNAPSHOT_MAX_SPEED := 5000.0
const SNAPSHOT_MAX_TIMER := 600.0
# Hoe vaak een unit die de speler ziet de plek doorgeeft (seconden). Alleen om rekenwerk te sparen.
const SHARE_INTERVAL := 1.0
# Dichter dan dit bij de laatst bekende plek: aangekomen, de speler is er niet meer.
const LAST_SEEN_REACHED := 40.0
# De hoeveelste unit van een eeuwige fabriek (-1 = geen eeuwige fabriek). Zet de fabriek.
var factory_order: int = -1
# Welke factie deze vijand het laatst raakte ("" = de speler of iets neutraals). Voor de loot.
var _last_hit_by: String = ""
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
	# Bovenaanzicht: "floating". In de standaardstand (grounded, voor platformspellen) ziet Godot wat
	# eronder zit als vloer en neemt hij de snelheid van die "vloer" over, waardoor units naar beneden
	# schoten (Daan, 26 nov). Zo is er geen boven/onder meer.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group("targets")
	add_to_group("enemies")
	if not passive:
		add_to_group("saveable")  # deze vijand wil onthouden worden (zie game_room.gd)
	
	# Hitboxen passend bij de sprite (vóór de grootte uit de SSOT); body_radius volgt mee.
	var fitted: float = SpriteFit.fit(self)
	if fitted > 0.0:
		body_radius = fitted
	
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
		rotation_speed = maxf(0.0, EnemyStats.value(faction, unit_type, "rotation_speed", rotation_speed))
		acceleration = maxf(0.0, EnemyStats.value(faction, unit_type, "acceleration", acceleration))
		friction = maxf(0.0, EnemyStats.value(faction, unit_type, "friction", friction))
		if shield == null:
			shield = EnemyShield.create(self, faction, unit_type, body_radius + 8.0)
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
	# Gedrag-getallen uit de SSOT (type-rij, met _modifier van type en factie). Leeg = de Inspector-waarde.
	wander_speed_factor = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_wander_speed", wander_speed_factor))
	investigate_speed_factor = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_investigate_speed", investigate_speed_factor))
	keep_distance_factor = clampf(EnemyStats.value(faction, unit_type, "behavior_keep_distance", keep_distance_factor), 0.0, 1.0)
	kamikaze_speed_factor = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_kamikaze_speed", kamikaze_speed_factor))
	kamikaze_trigger_distance = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_kamikaze_trigger", kamikaze_trigger_distance))
	kamikaze_loot_factor = clampf(EnemyStats.value(faction, unit_type, "behavior_kamikaze_loot", kamikaze_loot_factor), 0.0, 1.0)
	hit_alarm_delay = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_alarm_delay", hit_alarm_delay))
	tumble_speed_min = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_tumble_min", tumble_speed_min))
	tumble_speed_max = maxf(tumble_speed_min, EnemyStats.value(faction, unit_type, "behavior_tumble_max", tumble_speed_max))
	hit_spin_kick = maxf(0.0, EnemyStats.value(faction, unit_type, "behavior_hit_spin", hit_spin_kick))
	if not faces_player:
		spin = randf_range(tumble_speed_min, tumble_speed_max) * (1.0 if spin >= 0.0 else -1.0)


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
	# Klein naambordje met het wapen, alleen in de testkamer (in het gewone spel niet in beeld).
	if _weapon_label == null and LevelManager.in_test_room:
		_weapon_label = Label.new()
		_weapon_label.position = Vector2(-60, -body_radius - 30)
		_weapon_label.size = Vector2(120, 20)
		_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_weapon_label.add_theme_font_size_override("font_size", 12)
		# Los van de draaiing van de vijand (anders draait de tekst mee); positie in _process.
		_weapon_label.top_level = true
		add_child(_weapon_label)
		GameCamera.fit_world_label(_weapon_label)
	if _weapon_label != null:
		_weapon_label.text = Ssot.get_text(weapon_id, "ingame_name", weapon_id)


# Schiet op het doel (de speler of een unit van een andere factie) als hij een wapen heeft,
# het doel ziet en het binnen bereik is.
func _try_shoot(target: Node2D, distance: float, delta: float) -> void:
	if _weapon == null:
		return
	_fire_cooldown -= delta
	if _fire_cooldown > 0.0 or distance > _weapon.weapon_range or not _can_see(target):
		return
	# Bom of raket: friendly fire telt mee. Te veel eigen units bij het doel? Even wachten.
	if _weapon.explosion_radius > 0.0 and _weapon.explosion_damage > 0.0 \
			and not TargetPicker.aoe_ok(self, faction, target.global_position, _weapon.explosion_radius,
					_weapon.explosion_damage, _weapon.damage_type):
		_fire_cooldown = SIGHT_CHECK_SECONDS
		return
	_fire_cooldown = EnemyGun.fire_interval(_weapon, faction, unit_type)
	EnemyGun.fire(self, _weapon, target.global_position, body_radius + 8.0)


# Jaagt deze vijand nu op de speler? Jagers alleen als ze hem zien; de rest na het alarm.
func _chases_player() -> bool:
	if behavior_searching == "hunt":
		return _player_in_sight
	return alerted


# Deze vijand ziet de speler: onthouden en (hooguit eens per SHARE_INTERVAL) doorgeven aan de eigen
# factie, met de communicatievertraging (alarm_communication_delay; alarm_instant_from = meteen).
func _remember_player(pos: Vector2) -> void:
	_leads = [_reachable(pos)]  # zelf gezien: dit is de nieuwste en beste plek
	_share_left -= SIGHT_CHECK_SECONDS
	if _share_left > 0.0:
		return
	_share_left = SHARE_INTERVAL
	_broadcast(pos)


# Stuurt een bericht (plek van de speler, of een vijandige unit) naar de eigen factie in deze kamer.
func _broadcast(message: Variant) -> void:
	if faction == "":
		return
	var delay: float = maxf(0.0, Ssot.get_number("world", "alarm_communication_delay", 2.0))
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not other.has_method("hear_message") or not "faction" in other or other.faction != faction:
			continue
		var instant: bool = other.has_method("hears_alarm_instantly_from") and other.hears_alarm_instantly_from(unit_type)
		other.hear_message(message, 0.0 if instant else delay)


## Bericht van een factiegenoot: een Vector2 = daar is de speler gezien; een node = die vijandige unit
## of dat gebouw is gezien. Komt na 'delay' seconden binnen.
func hear_message(message: Variant, delay: float) -> void:
	if passive or current_health <= 0:
		return
	if not (message is Vector2 or (message is Node2D and is_instance_valid(message))):
		return
	if delay <= 0.0:
		_receive(message)
		return
	if _pending.size() >= MAX_PENDING:
		_pending.pop_front()  # het oudste bericht valt weg
	_pending.append([delay, message])


func _tick_messages(delta: float) -> void:
	var still: Array = []
	for entry in _pending:
		entry[0] -= delta
		if entry[0] <= 0.0:
			_receive(entry[1])
		else:
			still.append(entry)
	_pending = still


# Een bericht is binnen. Wie in gevecht is met een andere factie, negeert berichten over de speler.
func _receive(message: Variant) -> void:
	if message is Vector2:
		if is_instance_valid(_unit_target):
			return
		for lead in _leads:
			if lead.distance_to(message) < LAST_SEEN_REACHED * 2.0:
				return  # al bekend
		if _leads.size() >= MAX_LEADS:
			_leads.remove_at(0)
		_leads.append(_reachable(message))
	elif is_instance_valid(message) and TargetPicker.is_hostile_to(faction, message) and not _told_targets.has(message):
		if _told_targets.size() >= MAX_LEADS:
			_told_targets.remove_at(0)
		_told_targets.append(message)


# Een plek waar deze vijand echt kan komen (binnen het zwerfgebied). Een spoor vlak bij de rand
# (de speler verliet de kamer daar) bleef anders onbereikbaar: de vijand drukte dan eindeloos tegen de
# wand ("vallende" units, Daan 26 nov).
static func _reachable(pos: Vector2) -> Vector2:
	var area: Rect2 = _wander_area()
	return Vector2(clampf(pos.x, area.position.x, area.end.x), clampf(pos.y, area.position.y, area.end.y))


# De dichtstbijzijnde plek waar de speler gezien is (index in _leads), of -1.
func _nearest_lead() -> int:
	var best: int = -1
	var best_d: float = INF
	for k in _leads.size():
		var d: float = global_position.distance_squared_to(_leads[k])
		if d < best_d:
			best_d = d
			best = k
	return best


# De dichtstbijzijnde nog levende vijand die een factiegenoot doorgaf, of null.
func _nearest_told_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = INF
	var alive: Array = []
	for node in _told_targets:
		# Een doorgegeven doel kan intussen kapot zijn: eerst controleren, dan pas doorgeven
		# (een vrijgegeven object in een getypeerde parameter laat Godot crashen).
		if not is_instance_valid(node) or not TargetPicker.is_hostile_to(faction, node):
			continue
		alive.append(node)
		var d: float = global_position.distance_squared_to(node.global_position)
		if d < best_d:
			best_d = d
			best = node
	_told_targets = alive
	return best


# Kamikaze: alleen ontploffen als het de moeite is (friendly fire, zie TargetPicker.aoe_ok).
# Kamikaze: bij aanraking van de speler of een vijand ALTIJD meteen ontploffen (Daan, 26 nov).
# De friendly-fire-afweging (TargetPicker.aoe_ok) geldt alleen voor bommen en raketten.
func _try_explode() -> bool:
	_explode()
	return true


## De speler raakt deze vijand aan. Een kamikaze ontploft dan meteen (zonder eerst te botsen).
## Geeft true terug als hij ontploft is; dan doet de speler geen ramschade of terugstoot.
func explode_on_contact() -> bool:
	if behavior_agro != "kamikaze" or _exploding or current_health <= 0 or passive:
		return false
	_explode()
	return true


# Kiest of deze vijand een unit/gebouw van een andere factie aanvalt (_unit_target) of de speler (null).
# Volgorde (Daan, 26 nov):
#   1. Een doel van een andere factie onder target_finish_health (7%) eerst afmaken, ook vóór de speler.
#   2. De speler gaat voor, zodra deze vijand van hem weet (alarm, of hij jaagt altijd: "hunt").
#   3. Anders: TargetPicker kiest in de buurt, met wissel naar een zwakte (resistance of schild).
func _update_unit_target(player: Node2D) -> void:
	if faction == "" or passive:
		_unit_target = null
		return
	if is_instance_valid(_unit_target) and TargetPicker.is_hostile_to(faction, _unit_target) \
			and TargetPicker.should_finish(_unit_target) \
			and global_position.distance_to(_unit_target.global_position) <= _fight_radius() * 1.5:
		return
	if is_instance_valid(player) and _chases_player():
		_unit_target = null
		return
	var seen: Node2D = TargetPicker.pick(self, faction, _attack_damage_type(), _fight_radius())
	if seen != null:
		# Zelf gezien: doorgeven aan de factie (bijv. de scout aan de spores), niet vaker dan nodig.
		_share_unit_left -= SIGHT_CHECK_SECONDS
		if seen != _unit_target or _share_unit_left <= 0.0:
			_share_unit_left = SHARE_INTERVAL
			_broadcast(seen)
		_unit_target = seen
		return
	# Niets in de buurt: dan het dichtstbijzijnde doel dat een factiegenoot doorgaf.
	_unit_target = _nearest_told_target()


# Met welk damage type valt deze vijand aan? Het wapen, of anders base_damage_type van zijn rij.
func _attack_damage_type() -> String:
	if _weapon != null:
		return DamageCalc.normalize(_weapon.damage_type)
	return DamageCalc.attack_type(self)


# Hoe ver kijkt deze vijand naar units van andere facties? Zijn kijkafstand; een blinde kamikaze
# merkt alleen wat hij bijna aanraakt (dan ontploft hij).
func _fight_radius() -> float:
	if behavior_agro == "kamikaze":
		return maxf(scan_radius, kamikaze_trigger_distance + body_radius)
	return scan_radius


# Contactschade aan een unit van een andere factie als hij hem aanraakt (alleen zonder wapen en
# geen kamikaze), hooguit eens per contact_damage_interval seconden (SSOT world).
func _touch_unit(target: Node2D, distance: float, delta: float) -> void:
	_contact_left -= delta
	if _weapon != null or behavior_agro == "kamikaze" or _contact_left > 0.0:
		return
	if distance > body_radius + _target_radius(target) + CONTACT_SLACK or not target.has_method("take_damage"):
		return
	_contact_left = maxf(0.1, Ssot.get_number("world", "contact_damage_interval", 1.0))
	DamageCalc.mark_attacker(target, faction)
	target.take_damage(DamageCalc.scaled(get_contact_damage(), DamageCalc.attack_type(self), target),
			true, (target.global_position - global_position).normalized())


# Straal van een ander doel (unit: body_radius; gebouw zonder body_radius: een ruwe schatting).
static func _target_radius(target: Node) -> float:
	if "body_radius" in target:
		return float(target.body_radius)
	return 60.0


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
		"shield": shield.current if shield != null else 0.0,
		"order": factory_order,
		# Momentopname (pauze/opslaan mag geen cheatknop zijn): vaart, lopende wachttijden en
		# beslissingen. Berichten over vijandige units (nodes) kunnen niet bewaard worden; die
		# komen na het laden vanzelf opnieuw binnen.
		"vx": velocity.x,
		"vy": velocity.y,
		"t_alarm": _pending_alarm,
		"t_hit": _hit_alarm_timer,
		"t_fire": _fire_cooldown,
		"t_contact": _contact_left,
		"t_sight": _sight_timer,
		"inv": _investigating,
		"inv_x": _investigate_target.x,
		"inv_y": _investigate_target.y,
		"wan_x": _wander_target.x,
		"wan_y": _wander_target.y,
		"t_wan": _wander_timer,
		"leads": _leads.map(func(v: Vector2) -> Array: return [v.x, v.y]),
		"msgs": _pending.filter(func(e: Array) -> bool: return e[1] is Vector2).map(
				func(e: Array) -> Array: return [e[0], e[1].x, e[1].y]),
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	# Eerst factie en type terug, zodat de juiste waarden (max HP, snelheid, kleur) geladen worden.
	# Het wapen eerst, zodat _load_stats() geen nieuw wapen kiest.
	var saved_weapon: String = str(data.get("weapon", weapon_id))
	# Alleen een wapen dat in de SSOT bestaat (een aangepaste save kan van alles bevatten).
	if saved_weapon != "" and not Ssot.has_row(saved_weapon):
		saved_weapon = ""
	if saved_weapon != weapon_id:
		weapon_id = saved_weapon
		_load_weapon()
	var saved_faction: String = str(data.get("faction", faction))
	var saved_type: String = str(data.get("unit_type", unit_type))
	if saved_faction != faction or saved_type != unit_type:
		faction = saved_faction
		unit_type = saved_type
		_load_stats()
	current_health = clampi(SaveSystem._safe_int(data.get("hp", max_health)), 1, max_health)
	if shield != null:
		shield.restore(SaveSystem._safe_float(data.get("shield", shield.max_value)))
	global_position = Vector2(float(data.get("x", global_position.x)), float(data.get("y", global_position.y)))
	global_rotation = float(data.get("rot", global_rotation))
	spin = float(data.get("spin", spin))
	alerted = bool(data.get("alerted", alerted))
	factory_order = clampi(SaveSystem._safe_int(data.get("order", factory_order)), -1, 1000000)
	_apply_snapshot(data)


# Zet de momentopname terug (zie get_run_state). Alles begrensd: een aangepaste save kan van alles
# bevatten. Ontbreekt een veld (oude save), dan blijft de standaardwaarde staan.
func _apply_snapshot(data: Dictionary) -> void:
	var v := Vector2(_snap_num(data, "vx", 0.0), _snap_num(data, "vy", 0.0))
	velocity = v.limit_length(SNAPSHOT_MAX_SPEED)
	_pending_alarm = clampf(_snap_num(data, "t_alarm", _pending_alarm), -1.0, SNAPSHOT_MAX_TIMER)
	_hit_alarm_timer = clampf(_snap_num(data, "t_hit", _hit_alarm_timer), -1.0, SNAPSHOT_MAX_TIMER)
	_fire_cooldown = clampf(_snap_num(data, "t_fire", _fire_cooldown), 0.0, SNAPSHOT_MAX_TIMER)
	_contact_left = clampf(_snap_num(data, "t_contact", _contact_left), 0.0, SNAPSHOT_MAX_TIMER)
	_sight_timer = clampf(_snap_num(data, "t_sight", _sight_timer), 0.0, SIGHT_CHECK_SECONDS)
	_investigating = bool(data.get("inv", _investigating))
	_investigate_target = _snap_point(data.get("inv_x"), data.get("inv_y"), _investigate_target)
	_wander_target = _snap_point(data.get("wan_x"), data.get("wan_y"), _wander_target)
	_wander_timer = clampf(_snap_num(data, "t_wan", _wander_timer), 0.0, SNAPSHOT_MAX_TIMER)
	var leads: Variant = data.get("leads", [])
	if leads is Array:
		_leads.clear()
		for entry in leads.slice(0, MAX_LEADS):
			if entry is Array and entry.size() == 2:
				_leads.append(_reachable(_snap_point(entry[0], entry[1], global_position)))
	var msgs: Variant = data.get("msgs", [])
	if msgs is Array:
		_pending.clear()
		for entry in msgs.slice(0, MAX_PENDING):
			if entry is Array and entry.size() == 3:
				var t: float = clampf(SaveSystem._safe_float(entry[0]), 0.0, SNAPSHOT_MAX_TIMER)
				_pending.append([t, _snap_point(entry[1], entry[2], global_position)])


static func _snap_num(data: Dictionary, key: String, fallback: float) -> float:
	if not data.has(key):
		return fallback
	var n: float = SaveSystem._safe_float(data[key])
	return n if is_finite(n) else fallback


# Een punt uit de save, binnen (of vlak naast) de kamer; anders de fallback.
static func _snap_point(x: Variant, y: Variant, fallback: Vector2) -> Vector2:
	if x == null or y == null:
		return fallback
	var p := Vector2(SaveSystem._safe_float(x), SaveSystem._safe_float(y))
	var room := Rect2(Vector2(-200.0, -200.0), RoomBounds.size() + Vector2(400.0, 400.0))
	return p if p.is_finite() and room.has_point(p) else fallback


# Het naambordje van het wapen blijft recht boven de vijand hangen.
func _process(_delta: float) -> void:
	if _weapon_label != null:
		_weapon_label.global_position = global_position + Vector2(-60, -body_radius - 30)
	_update_ai_label()


# F1 "AI-labels": wat deze vijand nu doet en hoe hard hij gaat, boven zijn hoofd (alleen om te testen).
func _update_ai_label() -> void:
	if not Game.debug_ai_labels:
		if _ai_label != null:
			_ai_label.queue_free()
			_ai_label = null
		return
	if _ai_label == null:
		_ai_label = Label.new()
		_ai_label.top_level = true
		_ai_label.z_index = 100
		_ai_label.size = Vector2(220, 20)
		_ai_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_ai_label.add_theme_font_size_override("font_size", 12)
		add_child(_ai_label)
		GameCamera.fit_world_label(_ai_label)
	_ai_label.text = "%s %s | %s | v %d" % [faction, unit_type, _ai_state, roundi(velocity.length())]
	_ai_label.global_position = global_position + Vector2(-110, body_radius + 10)


# --- 3. GEDRAG EN BEWEGING (60x per seconde) ---
func _physics_process(delta: float) -> void:
	if _exploding:
		return
	if _pending_alarm >= 0.0:
		_pending_alarm -= delta
		if _pending_alarm < 0.0 and not alerted and current_health > 0:
			on_alarm()
	if not _pending.is_empty():
		_tick_messages(delta)
	if shield != null:
		shield.update(delta)
	
	# Geen voorkant: gewoon doortollen. In de ruimte remt niets het draaien af.
	if not faces_player:
		global_rotation += spin * delta
	
	# Testvijand: niet bewegen of aanvallen, alleen uitrollen na een zetje.
	if passive:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		RoomBounds.apply(self, body_radius, true)
		return
	
	var player = Game.active_player
	if not is_instance_valid(player):
		# Rem rustig af tot stilstand als de speler dood of onzichtbaar is
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
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
		_player_in_sight = behavior_searching == "hunt" and _can_see(player)
		if _player_in_sight:
			_remember_player(player.global_position)
		_update_unit_target(player)
	
	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()
	var direction: Vector2 = to_player.normalized()
	var facing: Vector2 = direction
	
	# Een kamikaze (spore) ontploft altijd als de speler hem aanraakt, ook als hij nog geen
	# alarm heeft (dan merkt hij de speler pas op het laatste moment op).
	if behavior_agro == "kamikaze" and current_health > 0 \
			and distance <= maxf(kamikaze_trigger_distance, body_radius + _player_radius(player) + CONTACT_SLACK):
		if _try_explode():
			return
	
	# Aanvallen op een unit of gebouw van een andere factie (zie _update_unit_target).
	var target: Node2D = player
	var fighting_unit: bool = is_instance_valid(_unit_target)
	if fighting_unit:
		target = _unit_target
		distance = global_position.distance_to(target.global_position)
		direction = (target.global_position - global_position).normalized()
		facing = direction
		if behavior_agro == "kamikaze" and distance <= maxf(kamikaze_trigger_distance, body_radius + _target_radius(target) + CONTACT_SLACK):
			if _try_explode():
				return
		_touch_unit(target, distance, delta)
	
	_ai_state = ""
	if fighting_unit or _chases_player():
		_ai_state = ("doel: " + str(target.name)) if fighting_unit else "jaagt op speler"
		match behavior_agro:
			"kamikaze":
				if distance <= kamikaze_trigger_distance and _try_explode():
					return
				velocity = velocity.move_toward(direction * movement_speed * kamikaze_speed_factor, acceleration * kamikaze_speed_factor * delta)
			"keep_distance":
				var keep: float = (scan_radius if scan_radius > 0.0 else 400.0) * keep_distance_factor
				var target_velocity: Vector2 = Vector2.ZERO
				if distance > keep + 40.0 or not _can_see(target):
					target_velocity = direction * movement_speed       # dichterbij, of terug in zicht
				elif distance < keep - 40.0:
					target_velocity = -direction * movement_speed      # te dichtbij: afstand nemen
				velocity = velocity.move_toward(target_velocity, acceleration * delta)
			_:
				velocity = velocity.move_toward(direction * movement_speed, acceleration * delta)
		if behavior_agro != "kamikaze":
			_try_shoot(target, distance, delta)
	elif not _leads.is_empty():
		# Plek waar de speler gezien is (zelf of doorgekregen): eerst de dichtstbijzijnde.
		var lead: int = _nearest_lead()
		var to_seen: Vector2 = _leads[lead] - global_position
		_ai_state = "spoor (%d)" % _leads.size()
		if to_seen.length() < LAST_SEEN_REACHED:
			_leads.remove_at(lead)
		velocity = velocity.move_toward(to_seen.normalized() * movement_speed, acceleration * delta)
		facing = velocity
	elif _investigating:
		# Een kogel gezien: kijken waar hij vandaan kwam.
		var to_target: Vector2 = _investigate_target - global_position
		_ai_state = "onderzoekt"
		if to_target.length() < 30.0:
			_investigating = false
		velocity = velocity.move_toward(to_target.normalized() * movement_speed * investigate_speed_factor, acceleration * delta)
		facing = velocity
	else:
		_wander(delta)
		_ai_state = "zwerft"
		facing = velocity
	
	# Draai de neus van de vijand mee (alleen als hij een voorkant heeft).
	if faces_player and facing.length() > 1.0:
		global_rotation = rotate_toward(global_rotation, facing.angle(), rotation_speed * delta)
	
	# Terugstoot (kogels, rammen) bovenop de eigen beweging, zodat de besturing hem niet meteen opeet.
	velocity += _knockback
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, maxf(friction, 1.0) * delta)
	# Kamikaze die toch tegen de speler of een vijand botst: meteen ontploffen.
	if behavior_agro == "kamikaze":
		for i in get_slide_collision_count():
			var other: Object = get_slide_collision(i).get_collider()
			if other == player or (other is Node and TargetPicker.is_hostile_to(faction, other)):
				_explode()
				return
	# Dezelfde bewegingsruimte als de speler (Systems/room_bounds.gd).
	RoomBounds.apply(self, body_radius, true)


## Een duw (pixels per seconde) die uitdooft met de friction van deze vijand. Kogels en rammen.
func apply_knockback(push: Vector2) -> void:
	if push.is_finite():
		_knockback = (_knockback + push).limit_length(SNAPSHOT_MAX_SPEED)


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
				randf_range(_wander_area().position.x, _wander_area().end.x),
				randf_range(_wander_area().position.y, _wander_area().end.y))
		_wander_timer = randf_range(3.0, 6.0)
	var to_target: Vector2 = (_wander_target - global_position).normalized()
	velocity = velocity.move_toward(to_target * movement_speed * wander_speed_factor, acceleration * delta)


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
				clampf(origin.x, _wander_area().position.x, _wander_area().end.x),
				clampf(origin.y, _wander_area().position.y, _wander_area().end.y))
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


# Deze vijand heeft de speler gezien: alle vijanden van zijn factie in deze kamer gaan in de aanval,
# na de communicatievertraging (SSOT world: alarm_communication_delay). Een vijand die het van dit
# type meteen hoort (alarm_instant_from, bijv. organic grunt van heavy en toren) gaat direct.
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
	var delay: float = maxf(0.0, Ssot.get_number("world", "alarm_communication_delay", 2.0))
	for other in get_tree().get_nodes_in_group("enemies"):
		if other != self and other.has_method("on_alarm") and "faction" in other and other.faction == faction:
			if delay <= 0.0 or (other.has_method("hears_alarm_instantly_from") and other.hears_alarm_instantly_from(unit_type)):
				other.on_alarm()
			elif other.has_method("on_alarm_delayed"):
				other.on_alarm_delayed(delay)
			else:
				other.on_alarm()


## Hoort deze vijand het alarm van dit unit-type meteen? (SSOT: alarm_instant_from, types met /.)
func hears_alarm_instantly_from(sender_type: String) -> bool:
	var list: String = EnemyStats.text(faction, unit_type, "alarm_instant_from", "")
	for part in list.split("/", false):
		if part.strip_edges().to_lower() == sender_type.to_lower():
			return true
	return false


## Het alarm komt over 'delay' seconden binnen (communicatievertraging). Een eerder bericht wint.
func on_alarm_delayed(delay: float) -> void:
	if alerted:
		return
	if _pending_alarm < 0.0 or delay < _pending_alarm:
		_pending_alarm = delay


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
		if "faction" in victim and str(victim.faction) != faction:
			DamageCalc.mark_attacker(victim, faction)
		victim.take_damage(DamageCalc.scaled(explosion_damage, DamageCalc.attack_type(self), victim), true, push)
	
	# Spore: een corrosive wolkje blijft hangen (SSOT: explosion_cloud_duration, explosion_cloud_radius,
	# base_corrosive_damage). Leeg of 0 = geen wolkje.
	var cloud_radius: float = EnemyStats.value(faction, unit_type, "explosion_cloud_radius", explosion_radius)
	CorrosiveCloud.spawn(get_tree().current_scene, center,
			EnemyStats.value(faction, unit_type, "explosion_cloud_duration", 0.0),
			cloud_radius if cloud_radius > 0.0 else explosion_radius,
			EnemyStats.value(faction, unit_type, "corrosive_damage", 0.0),
			EnemyStats.value(faction, unit_type, "explosion_cloud_growth", 3.0))
	
	# Zelf dood, en maar een fractie van de loot.
	_loot_factor = kamikaze_loot_factor
	current_health = 0
	call_deferred("_deferred_death", Vector2.ZERO)


# --- 4. SCHADE-AFHANDELING EN ARCADE-FLITS ---
## Schade die de speler krijgt als hij tegen deze vijand aan vliegt: base_damage van het type
## (met _modifier van type en factie). Leeg = 10.
func get_contact_damage() -> float:
	return maxf(0.0, EnemyStats.value(faction, unit_type, "damage", 10.0))


func take_damage(amount: int, flash: bool = true, hit_dir: Vector2 = Vector2.ZERO) -> void:
	if current_health <= 0: 
		return
		
	# Het schild vangt eerst op; alleen de rest gaat van de levens af.
	var through: int = amount
	if shield != null:
		through = roundi(shield.absorb(amount, DamageCalc.shield_factor_for(self)))
	current_health = max(0, current_health - through)
	
	# Geraakt worden is een duidelijk teken: een vijand die kan kijken, weet zo dat de speler er is.
	# Hij slaat pas alarm na hit_alarm_delay seconden, zodat je hem nog stil kunt uitschakelen.
	# Een treffer van een andere factie zegt niets over de speler: dan geen alarm.
	var hit_by_faction: String = DamageCalc.take_hit_by(self)
	_last_hit_by = hit_by_faction
	if hit_by_faction == "" and not passive and scan_radius > 0.0 and not alerted and not _exploding and _hit_alarm_timer < 0.0:
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

	# Minder loot: opgeblazen kamikaze (_loot_factor), de zoveelste unit van een eeuwige fabriek
	# (loot_factory_falloff ^ volgnummer) en gedood door een andere factie (loot_other_faction_factor).
	# Bij 0,3 blokje is er 30% kans op 1 blokje.
	var extra: float = _loot_scale_extra()
	var factor: float = _loot_factor * extra
	if factor < 1.0:
		var scaled: float = total_drops * factor
		total_drops = int(floor(scaled)) + (1 if randf() < scaled - floor(scaled) else 0)

	# Oude testvijanden zonder factie houden hun grondstof uit test_body_type.
	var resource: String = LootDrops.resource_id(faction, unit_type, LootResources.normalize(test_body_type))
	LootDrops.spawn(get_tree().current_scene, global_position, hit_dir, total_drops, resource, LootDrops.splatter_settings(faction, unit_type))
	# Factie-loot (biomass, circuitry ...) bovenop de gewone loot. Een opgeblazen kamikaze geeft geen factie-loot.
	if _loot_factor >= 1.0 and (extra >= 1.0 or randf() < extra):
		LootDrops.spawn_faction_loot(get_tree().current_scene, global_position, hit_dir, faction, unit_type, LootDrops.splatter_settings(faction, unit_type))
		LootDrops.spawn_bonus_loot(get_tree().current_scene, global_position, hit_dir, faction, unit_type, LootDrops.splatter_settings(faction, unit_type))
	print("VIJAND DROP: '", name, "' laat ", total_drops, " blokjes vallen.")


# Extra loot-factor (1 = alles): eeuwige fabriek en dader. Waarden uit SSOT world, begrensd 0..1.
func _loot_scale_extra() -> float:
	var f: float = 1.0
	if factory_order > 0:
		var falloff: float = clampf(Ssot.get_number("world", "loot_factory_falloff", 1.0), 0.0, 1.0)
		f *= pow(falloff, float(mini(factory_order, 1000)))
	if _last_hit_by != "" and _last_hit_by != faction:
		f *= clampf(Ssot.get_number("world", "loot_other_faction_factor", 1.0), 0.0, 1.0)
	return f


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


## De kamer (RoomBounds.size), met een rand van WANDER_MARGIN.
static func _wander_area() -> Rect2:
	var room: Vector2 = RoomBounds.size()
	return Rect2(WANDER_MARGIN, WANDER_MARGIN, room.x - 2.0 * WANDER_MARGIN, room.y - 2.0 * WANDER_MARGIN)


## Straal van het schip van de speler (passend bij zijn sprite), voor aanraken.
static func _player_radius(player: Node) -> float:
	if "body_radius" in player:
		return float(player.body_radius)
	return Player.BODY_RADIUS
