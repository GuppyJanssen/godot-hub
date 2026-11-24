extends CharacterBody2D
class_name Player
## De speler: bewegen, draaien, schieten, schild/energie/levens en botsen.
##
## ALLE getallen komen uit de SSOT-rij PLAYER_ROW ("player_base"), met de skills erbovenop
## (StatCalc.player_value). Kolommen die gelezen worden:
##   max_health, max_shield, max_energy                     – maxima
##   base_health_regen, base_energy_regen                   – levens / energie per seconde
##   shield_regen_amount, shield_regen_delay                – schild per seconde, wachttijd na een treffer
##   shield_energy_cost                                     – energie per schildpunt bij herstellen
##   base_speed, base_acceleration, base_friction           – bewegen
##   base_rotation_speed                                    – draaien naar de muis (radialen per seconde)
##   base_damage, base_damage_type                          – rammen: schade aan de vijand en het type
##   base_knockback_force, base_recoil_force                – rammen: duw aan de vijand, terugstoot voor jezelf
## Wapens: zie SsotWeapon (energie per schot = energy_cost_per_dps × schade per schot).
##
## Ontwikkelaarsnotities:
## - Vroeger kwamen de stats uit user://<slot>/Player_Data.tres. Dat is weg: een .tres uit
##   user:// kan een script bevatten dat meteen wordt uitgevoerd (onveilig), en de waarden
##   stonden dubbel naast de sheet. De stand (HP/schild/energie) gaat nu via Game-meta
##   (kamerwissel) en RunState.extra["player_status"] (Continue).
## - Regeneratie gebruikt accumulators, zodat kommagetallen per seconde (0,02 HP/s) kloppen.

@export var weapon_output_scene: PackedScene = preload("res://Entities/Weapon Output/weapon_output.tscn")

var stats: PlayerStats = null
var can_fire: bool = true

var current_weapon_stats: Dictionary = {}
## Toetsen voor de vier wapenvakken: 1 = boven, 2 = rechts, 3 = onder, 4 = links.
const WEAPON_SLOT_KEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4]
var _weapon_wheel: Node = null
## De SSOT-rij met de stats van de speler.
const PLAYER_ROW := "player_base"
## Afstand tussen twee lopen, in pixels (vorm van het schip, geen balanswaarde).
const MUZZLE_SPACING := 14.0
## Ondergrens voor de tijd tussen schoten, ook met F1 of skills.
const MIN_FIRE_INTERVAL := 0.02
## Rand van de speler voor RoomBounds (botsvorm van het schip).
const BODY_RADIUS := 30.0

## Tijd tot het schild weer mag laden (na een treffer).
var _shield_delay_left: float = 0.0
var _shield_accumulator: float = 0.0
var _health_accumulator: float = 0.0
var _energy_accumulator: float = 0.0
var _shield_energy_debt: float = 0.0
var _shot_energy_debt: float = 0.0
var _dead: bool = false


func _ready() -> void:
	if is_instance_valid(Game):
		Game.active_player = self

	# 1. Skills (gekocht + run-punten) in Mods zetten, vóór de stats worden uitgerekend.
	SkillEffects.refresh_from_save()
	if not RunState.run_points_changed.is_connected(_on_run_points_changed):
		RunState.run_points_changed.connect(_on_run_points_changed)

	# 2. Stats uit de SSOT en de stand van deze run.
	stats = PlayerStats.new()
	_refresh_max_stats()
	_restore_status()

	# 3. Wachten tot de LevelManager en het SaveSystem klaar zijn.
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return

	# 4. Het wapen uit het gekozen wapenvak van deze run.
	Game.active_weapon_key = RunState.selected_weapon()
	_load_weapon_stats(Game.active_weapon_key)
	_weapon_wheel = load("res://Systems/weapon_wheel.gd").new()
	add_child(_weapon_wheel)

	if Game.should_load_run:
		call_deferred("_force_continue_position")

	# Uit een kamerwissel: het schild begint pas na de wachttijd te laden.
	if Game.has_meta("transit_health"):
		_shield_delay_left = _stat("shield_regen_delay", 3.0)


func _exit_tree() -> void:
	if RunState.run_points_changed.is_connected(_on_run_points_changed):
		RunState.run_points_changed.disconnect(_on_run_points_changed)


# ---------------------------------------------------------------- stats

func _stat(stat_name: String, fallback: float) -> float:
	return StatCalc.player_value(PLAYER_ROW, stat_name, fallback)


## Maxima uit de SSOT (met skills). Huidige waarden worden zo nodig begrensd.
func _refresh_max_stats() -> void:
	if stats == null:
		return
	stats.max_health = maxi(1, roundi(_stat("max_health", 100.0)))
	stats.max_shield = maxi(0, roundi(_stat("max_shield", 50.0)))
	stats.max_energy = maxi(0, roundi(_stat("max_energy", 100.0)))
	stats.current_health = clampi(stats.current_health, 0, stats.max_health)
	stats.current_shield = clampi(stats.current_shield, 0, stats.max_shield)
	stats.current_energy = clampi(stats.current_energy, 0, stats.max_energy)


## Zet HP, schild en energie: uit een kamerwissel, uit een Continue, of vol bij een nieuwe run.
func _restore_status() -> void:
	var source: Dictionary = {}
	if Game.has_meta("transit_health"):
		source = {
			"health": Game.get_meta("transit_health"),
			"shield": Game.get_meta("transit_shield", stats.max_shield),
			"energy": Game.get_meta("transit_energy", stats.max_energy),
		}
	elif Game.should_load_run:
		source = SaveSystem.dict_or_empty(RunState.extra.get("player_status"))

	if source.is_empty():
		stats.current_health = stats.max_health
		stats.current_shield = stats.max_shield
		stats.current_energy = stats.max_energy
		return
	stats.current_health = clampi(SaveSystem._safe_int(source.get("health", stats.max_health)), 1, stats.max_health)
	stats.current_shield = clampi(SaveSystem._safe_int(source.get("shield", stats.max_shield)), 0, stats.max_shield)
	stats.current_energy = clampi(SaveSystem._safe_int(source.get("energy", stats.max_energy)), 0, stats.max_energy)


func _on_run_points_changed(_skill_id: String, _total: float) -> void:
	SkillEffects.refresh_from_save()
	_refresh_max_stats()
	reload_weapon_stats()


# ---------------------------------------------------------------- elk frame

func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().paused or _dead:
		return

	# 1. Draaien naar de muis, met de draaisnelheid uit de SSOT.
	var turn_speed: float = _stat("rotation_speed", 10.0)
	var target_angle: float = (get_global_mouse_position() - global_position).angle()
	global_rotation = rotate_toward(global_rotation, target_angle, maxf(0.0, turn_speed) * delta)

	# 2. Bewegen (ijs/schaatsen): versnellen naar de topsnelheid, afremmen zonder invoer.
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_dir.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_D): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_A): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_S): input_dir.y += 1.0
		if Input.is_key_pressed(KEY_W): input_dir.y -= 1.0
	input_dir = input_dir.normalized()

	var current_accel: float = _stat("acceleration", 1600.0) * Game.debug_acceleration_multiplier
	var current_friction: float = _stat("friction", 300.0) * Game.debug_friction_multiplier
	var current_max_speed: float = _stat("speed", 450.0) * Game.debug_max_speed_multiplier
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * current_max_speed, current_accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_friction * delta)
	move_and_slide()

	# 3. Herstel: schild, levens en energie.
	_regenerate(delta)

	# 4. Kamergrenzen (Systems/room_bounds.gd).
	if is_instance_valid(LevelManager):
		if LevelManager.current_layer == 0 and has_node("Camera2D"):
			var cam: Camera2D = get_node("Camera2D")
			cam.limit_left = -10000
			cam.limit_right = 10000
		var enemies_alive: bool = get_tree().get_nodes_in_group("targets").size() + get_tree().get_nodes_in_group("enemies").size() > 0
		RoomBounds.apply(self, BODY_RADIUS, enemies_alive)

	# 5. Schieten (full-auto: knop vasthouden, semi: per klik).
	if can_fire:
		var weapon_is_auto: bool = float(current_weapon_stats.get("is_full_auto", 0.0)) == 1.0
		if weapon_is_auto:
			if Input.is_action_pressed("fire_primary") or Input.is_action_pressed("ui_accept"):
				fire_primary_weapon()
		elif Input.is_action_just_pressed("fire_primary") or Input.is_action_just_pressed("ui_accept"):
			fire_primary_weapon()

	# 6. De stand doorgeven: aan Game (kamerwissel) en RunState (Continue).
	_publish_status()


func _regenerate(delta: float) -> void:
	if stats == null:
		return
	var god: bool = Game.debug_is_invincible

	# Schild: na de wachttijd 'shield_regen_amount' per seconde, zolang er energie is.
	if _shield_delay_left > 0.0:
		_shield_delay_left -= delta
	elif stats.current_shield < stats.max_shield and (stats.current_energy > 0 or god):
		_shield_accumulator += maxf(0.0, _stat("shield_regen_amount", 5.0)) * delta
		var points: int = mini(int(_shield_accumulator), stats.max_shield - stats.current_shield)
		if points > 0:
			_shield_accumulator -= points
			stats.current_shield += points
			if not god:
				_shield_energy_debt += points * maxf(0.0, _stat("shield_energy_cost", 0.1))
				var energy_cost: int = int(_shield_energy_debt)
				if energy_cost > 0:
					_shield_energy_debt -= energy_cost
					stats.current_energy = maxi(0, stats.current_energy - energy_cost)
	else:
		_shield_accumulator = 0.0

	# Levens per seconde (0 = geen herstel).
	if stats.current_health < stats.max_health:
		_health_accumulator += maxf(0.0, _stat("health_regen", 0.0)) * delta
		var hp: int = int(_health_accumulator)
		if hp > 0:
			_health_accumulator -= hp
			stats.current_health = mini(stats.max_health, stats.current_health + hp)
	else:
		_health_accumulator = 0.0

	# Energie per seconde.
	if stats.current_energy < stats.max_energy:
		_energy_accumulator += maxf(0.0, _stat("energy_regen", 0.0)) * delta
		var en: int = int(_energy_accumulator)
		if en > 0:
			_energy_accumulator -= en
			stats.current_energy = mini(stats.max_energy, stats.current_energy + en)
	else:
		_energy_accumulator = 0.0


func _publish_status() -> void:
	if stats == null:
		return
	Game.set_meta("transit_health", stats.current_health)
	Game.set_meta("transit_shield", stats.current_shield)
	Game.set_meta("transit_energy", stats.current_energy)
	if RunState.active:
		RunState.extra["player_status"] = {
			"health": stats.current_health,
			"shield": stats.current_shield,
			"energy": stats.current_energy,
		}


# ---------------------------------------------------------------- wapens

# Scrollen bladert door de vakken met een wapen, 1 t/m 4 kiest een vak. Het wiel is dan even zichtbaar.
func _unhandled_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed:
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			RunState.cycle_weapon(1)
			on_weapons_changed()
			get_viewport().set_input_as_handled()
		elif mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP:
			RunState.cycle_weapon(-1)
			on_weapons_changed()
			get_viewport().set_input_as_handled()
		return
	var key_event: InputEventKey = event as InputEventKey
	if key_event != null and key_event.pressed and not key_event.echo:
		var slot: int = WEAPON_SLOT_KEYS.find(key_event.keycode)
		if slot >= 0:
			RunState.select_weapon_slot(slot)
			on_weapons_changed()
			get_viewport().set_input_as_handled()


## Laadt de stats van het huidige wapen opnieuw (bijvoorbeeld na een F1-instelling of skill).
func reload_weapon_stats() -> void:
	_load_weapon_stats(Game.active_weapon_key)


## Na een wissel, een nieuw wapen of een ruil: laad het gekozen wapen en toon het wiel.
func on_weapons_changed() -> void:
	var weapon: String = RunState.selected_weapon()
	if weapon != Game.active_weapon_key:
		Game.active_weapon_key = weapon
		_load_weapon_stats(weapon)
	if is_instance_valid(_weapon_wheel):
		_weapon_wheel.show_wheel()


## Vult current_weapon_stats uit de SSOT (via SsotWeapon, met skills).
## De sleutels blijven hetzelfde, want de kogel en het F1-scherm lezen ze.
func _load_weapon_stats(weapon_key: String) -> void:
	if not Ssot.has_row(weapon_key):
		push_warning("PLAYER: wapen '%s' staat niet in de SSOT; terug naar het startwapen." % weapon_key)
		weapon_key = RunState.STARTER_WEAPON
	var w: SsotWeapon = SsotWeapon.from_ssot(weapon_key, true)
	current_weapon_stats = {
		"damage": w.damage,
		"base_fire_rate": w.fire_interval,
		"weapon_range": w.weapon_range,
		"bullet_speed": w.projectile_speed,
		"size_multiplier": w.size,
		"is_full_auto": 1.0 if w.full_auto else 0.0,
		"bullet_per_shot": w.bullets_per_shot,
		"muzzle_count": w.muzzle_count,
		"bullet_spread": w.spread_degrees,
		"damage_type": w.damage_type,
		"energy_per_shot": w.energy_per_shot(),
		"pierce_count": w.pierce_count,
		"bounce_count": w.bounce_count,
		"knockback_force": w.knockback_force,
		"explosion_damage": w.explosion_damage,
		"explosion_radius": w.explosion_radius,
	}
	# F1 Weapon Mode: 1 = altijd auto, 2 = altijd semi, 0 = wat het wapen in de SSOT heeft.
	if Game.debug_weapon_mode == 1:
		current_weapon_stats["is_full_auto"] = 1.0
	elif Game.debug_weapon_mode == 2:
		current_weapon_stats["is_full_auto"] = 0.0


func fire_primary_weapon() -> void:
	if not weapon_output_scene or stats == null:
		return

	# Energie: wapens met energy_cost_per_dps in de SSOT kosten energie per schot.
	var energy_cost: float = float(current_weapon_stats.get("energy_per_shot", 0.0))
	var god: bool = Game.debug_is_invincible
	if energy_cost > 0.0 and stats.current_energy <= 0 and not god:
		return

	can_fire = false

	var bullets_to_spawn: int = maxi(1, int(current_weapon_stats.get("bullet_per_shot", 1)))
	var spread_rad: float = deg_to_rad(maxf(0.0, float(current_weapon_stats.get("bullet_spread", 0.0))))
	var dmg: float = float(current_weapon_stats.get("damage", 1.0))
	var muzzles: int = Game.debug_muzzle_count if Game.debug_muzzle_count > 0 else maxi(1, int(current_weapon_stats.get("muzzle_count", 1)))
	var side: Vector2 = global_transform.y.normalized()

	for shot in range(bullets_to_spawn * muzzles):
		var i: int = shot % bullets_to_spawn
		var m: int = floori(float(shot) / bullets_to_spawn)
		var muzzle_offset: Vector2 = side * ((m - (muzzles - 1) / 2.0) * MUZZLE_SPACING)
		var bullet = weapon_output_scene.instantiate()

		var final_spread: float = 0.0
		if bullets_to_spawn > 1:
			# Meerdere kogels: een waaier over de hele spreiding.
			final_spread = lerpf(-spread_rad, spread_rad, float(i) / float(bullets_to_spawn - 1))
		elif spread_rad > 0.0:
			final_spread = randf_range(-spread_rad, spread_rad)

		# Vóór add_child, want de kogel rekent in _ready verder.
		bullet.speed = float(current_weapon_stats.get("bullet_speed", bullet.speed))
		bullet.damage_type = str(current_weapon_stats.get("damage_type", ""))
		bullet.size_scale = float(current_weapon_stats.get("size_multiplier", 1.0))
		bullet.damage = dmg
		bullet.range_override = float(current_weapon_stats.get("weapon_range", -1.0))
		bullet.pierce_left = int(current_weapon_stats.get("pierce_count", 0))
		bullet.bounce_left = int(current_weapon_stats.get("bounce_count", 0))
		bullet.knockback_force = float(current_weapon_stats.get("knockback_force", 0.0))
		bullet.explosion_damage = float(current_weapon_stats.get("explosion_damage", 0.0))
		bullet.explosion_radius = float(current_weapon_stats.get("explosion_radius", 0.0))
		bullet.global_position = global_position + muzzle_offset
		bullet.global_rotation = global_rotation + final_spread
		get_tree().current_scene.add_child(bullet)

	if energy_cost > 0.0 and not god:
		_shot_energy_debt += energy_cost
		var whole: int = int(_shot_energy_debt)
		if whole > 0:
			_shot_energy_debt -= whole
			stats.current_energy = maxi(0, stats.current_energy - whole)

	var fire_rate: float = float(current_weapon_stats.get("base_fire_rate", 0.5))
	# F1 Fire Rate: 2x = twee keer zo snel schieten (de wachttijd wordt gedeeld).
	if Game.debug_fire_rate_multiplier > 0.0:
		fire_rate /= Game.debug_fire_rate_multiplier
	fire_rate = maxf(fire_rate, MIN_FIRE_INTERVAL)

	await get_tree().create_timer(fire_rate).timeout
	can_fire = true


# ---------------------------------------------------------------- botsen en schade

# Tegen een vijand of gebouw aan vliegen: jij krijgt zijn contactschade, hij jouw ramschade.
func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body) or _dead:
		return
	if not (body.is_in_group("enemies") or body.is_in_group("targets")):
		return

	# 1. Schade aan de speler: base_damage van die vijand (zie get_contact_damage).
	var incoming: float = _stat("damage", 10.0)
	if body.has_method("get_contact_damage"):
		incoming = float(body.get_contact_damage())
	if take_damage(incoming):
		return

	# 2. Schade aan de vijand / het gebouw (rammen), zonder wapenskills.
	if body.has_method("take_damage"):
		var ram_damage: float = StatCalc.value(PLAYER_ROW, "damage", 10.0)
		var ram_type: String = Ssot.get_text(PLAYER_ROW, "base_damage_type", "kinetic")
		var hit_direction: Vector2 = (body.global_position - global_position).normalized()
		if body.has_method("on_hit_info"):
			body.on_hit_info(ram_damage, ram_type)
		body.take_damage(maxi(1, roundi(ram_damage)), true, hit_direction)

	# 3. Terugstoot voor jezelf, duw voor de vijand.
	var knockback_dir: Vector2 = (global_position - body.global_position).normalized()
	velocity = knockback_dir * StatCalc.value(PLAYER_ROW, "recoil_force", 350.0)
	if "velocity" in body:
		body.velocity = -knockback_dir * StatCalc.value(PLAYER_ROW, "knockback_force", 250.0)


## Schade aan de speler, met schild-absorptie. Geeft true terug als de speler hierdoor sterft.
func take_damage(amount: float, _flash: bool = true, _hit_dir: Vector2 = Vector2.ZERO) -> bool:
	if stats == null or Game.debug_is_invincible or _dead:
		return false
	var incoming_damage: int = maxi(0, roundi(amount))
	if incoming_damage == 0:
		return false

	# Het schild laadt pas weer na de wachttijd.
	_shield_delay_left = maxf(0.0, _stat("shield_regen_delay", 3.0))
	_shield_accumulator = 0.0

	var absorbed: int = mini(stats.current_shield, incoming_damage)
	stats.current_shield -= absorbed
	incoming_damage -= absorbed
	if incoming_damage > 0:
		stats.current_health = maxi(0, stats.current_health - incoming_damage)
	_publish_status()

	if stats.current_health <= 0:
		_die()
		return true
	return false


func _die() -> void:
	_dead = true
	print("PLAYER: overleden. De buit gaat naar de kluis, de run wordt afgesloten.")
	LootResources.bank_run_loot()
	Game.should_load_run = false
	Game.remove_meta("transit_health")
	Game.remove_meta("transit_shield")
	Game.remove_meta("transit_energy")
	SaveSystem.new().delete_current_run_save()
	RunState.end_run()
	if is_instance_valid(LevelManager):
		LevelManager.reset_manager_for_new_run()
	get_tree().call_deferred("change_scene_to_file", "res://Systems/main_menu.tscn")


# ---------------------------------------------------------------- opslaan en Continue

func _force_continue_position() -> void:
	var run_data: Dictionary = SaveSystem.read_json(SaveSystem.slot_file(SaveSystem.RUN_FILE))
	if not (run_data.has("player_x") and run_data.has("player_y")):
		return
	var found_pos := Vector2(SaveSystem._safe_float(run_data["player_x"]), SaveSystem._safe_float(run_data["player_y"]))
	# Alleen een plek binnen (of vlak naast) de kamer overnemen.
	if found_pos != Vector2.ZERO and Rect2(-200.0, -200.0, 2320.0, 1480.0).has_point(found_pos):
		global_position = found_pos


## Schrijft de plek van de speler naar current_run.json (bij "terug naar hoofdmenu").
func save_live_run_state_to_disk() -> void:
	if stats == null:
		return
	_publish_status()
	var full_path: String = SaveSystem.slot_file(SaveSystem.RUN_FILE)
	if full_path == "":
		return
	var run_data: Dictionary = SaveSystem.read_json(full_path)
	run_data["current_layer"] = LevelManager.current_layer
	run_data["current_room_index"] = LevelManager.current_room_index
	run_data["player_x"] = global_position.x
	run_data["player_y"] = global_position.y
	SaveSystem.write_json(full_path, run_data)
