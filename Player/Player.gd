extends CharacterBody2D
class_name Player

# --- CONFIGURATIE & SCENE LINKS ---
@export var weapon_output_scene: PackedScene = preload("res://Entities/Weapon Output/weapon_output.tscn")

var stats: Resource = null
var can_fire: bool = true

# De grondstoffen staan niet meer in de speler: de kluis in MetaProgress.resources,
# de buit van deze run in RunState.loot (zie LootResources).

# --- REGENERATIE EN ENERGIE MOTOR ---
var shield_regen_timer: Timer
var health_regen_timer: Timer
var can_regen_shield: bool = false
var shield_accumulator: float = 0.0


var current_weapon_stats: Dictionary = {}
## Toetsen voor de vier wapenvakken: 1 = boven, 2 = rechts, 3 = onder, 4 = links.
const WEAPON_SLOT_KEYS: Array = [KEY_1, KEY_2, KEY_3, KEY_4]
var _weapon_wheel: Node = null
## Afstand tussen twee lopen, in pixels.
const MUZZLE_SPACING := 14.0


func _ready() -> void:
	# 1. AUTOLOAD LINK: Registreer deze actieve speler direct in de globale cockpit
	if is_instance_valid(Game):
		Game.active_player = self
		print("PLAYER: Succesvol gekoppeld aan de Game Global Hub.")
		
	# 2. INLADEN RESOURCE DATA (GECORRIGEERD: Breekt de RAM-cache voor een loepzuivere New Run start!)
	var slot_folder = "user://" + Game.active_save_slot + "/"
	var custom_tres_path = slot_folder + "Player_Data.tres"
	
	if not FileAccess.file_exists(custom_tres_path):
		var base_tres = load("res://Resources/Player_Data.tres")
		if base_tres:
			var dir = DirAccess.open("user://")
			if dir and not dir.dir_exists(Game.active_save_slot):
				dir.make_dir(Game.active_save_slot)
			ResourceSaver.save(base_tres.duplicate(), custom_tres_path)
			
	# BINGO: We dwingen Godot om de cache volledig te omzeilen en de schijf-data NU live in te laden!
	var raw_stats = ResourceLoader.load(custom_tres_path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if raw_stats:
		stats = raw_stats.duplicate()
		print("PLAYER ENGINE: Unieke, slot-geïsoleerde resource-kopie online via schijf: ", custom_tres_path)


	if stats:
		if stats.max_health <= 0: stats.max_health = 100
		if stats.max_shield <= 0: stats.max_shield = 50
		if stats.max_energy <= 0: stats.max_energy = 100
		
		# SSoT DRIFT-BEVEILIGING: Laad direct de overgedragen status in als de Hub metadata bezit!
		if is_instance_valid(Game) and Game.has_meta("transit_health"):
			stats.current_health = int(Game.get_meta("transit_health"))
			stats.current_shield = int(Game.get_meta("transit_shield"))
			stats.current_energy = int(Game.get_meta("transit_energy"))
			print("PLAYER ENGINE: Status succesvol herstelt bij schermtransitie! HP: ", stats.current_health)
		else:
			# Triggert uitsluitend bij een absolute, schone start vanaf het hoofdmenu
			print("PLAYER ENGINE: Geen transitie-data aanwezig. Start op met MAX status.")
			stats.current_health = stats.max_health
			stats.current_shield = stats.max_shield
			stats.current_energy = stats.max_energy
		
	# 3. TIMING FIX: We wachten tot de LevelManager én het SaveSystem klaar zijn
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. LEIDENDE AS: Wapenstats inladen uit de CSV
	# Het wapen komt uit het gekozen wapenvak van deze run (RunState).
	Game.active_weapon_key = RunState.selected_weapon()
	_load_weapon_stats(Game.active_weapon_key)
	# Het wapenwiel (zichtbaar bij wisselen).
	_weapon_wheel = load("res://Systems/weapon_wheel.gd").new()
	add_child(_weapon_wheel)

	# BINGO: Als we een run hervatten via Continue, roepen we uitgesteld de pixel-forcerder aan!
	if Game.should_load_run:
		call_deferred("_force_continue_position")


	# --- INITIALISATIE REGENERATIE EN ENERGIE TIMERS ---
	# 1. Schild Timer: Regelt de 3 seconden afkoeltijd na het incasseren van schade
	shield_regen_timer = Timer.new()
	shield_regen_timer.wait_time = 3.0
	shield_regen_timer.one_shot = true
	shield_regen_timer.timeout.connect(func(): can_regen_shield = true)
	add_child(shield_regen_timer)
	
	# BINGO: Als we uit een transitie komen, starten we de timer direct!
	# Dit garandeert dat de 3 seconden klok gaat lopen en het opladen daarna direct hervat.
	if is_instance_valid(Game) and Game.has_meta("transit_health"):
		shield_regen_timer.start()
	
	
	# 2. Health Timer: Tikt onvoorwaardelijk elke 3 seconden voor de 33% kans-check
	health_regen_timer = Timer.new()
	health_regen_timer.wait_time = 3.0
	health_regen_timer.one_shot = false
	health_regen_timer.timeout.connect(_on_health_regen_tick)
	add_child(health_regen_timer)
	health_regen_timer.start()


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return
	if get_tree().paused: return

	# 1. ROTATIE NAAR DE MUISCURSOR (Rondkijken)
	var mouse_pos = get_global_mouse_position()
	look_at(mouse_pos)

	# 2. HAAL DE RECHTSTREEKSE INPUT OP (Bewegen)
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
	input_dir.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
	
	# Proactieve WASD-fallback mochten de ui_ actions korter gekoppeld staan
	if input_dir == Vector2.ZERO:
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): input_dir.x += 1.0
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): input_dir.y += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): input_dir.y -= 1.0
		
	input_dir = input_dir.normalized()

	# Haal multipliers op uit de globale Game hub
	var current_accel = current_weapon_stats.get("acceleration", 1500.0) * Game.debug_acceleration_multiplier
	var current_friction = current_weapon_stats.get("friction", 800.0) * Game.debug_friction_multiplier
	var current_max_speed = current_weapon_stats.get("max_speed", 450.0) * Game.debug_max_speed_multiplier

	# 3. BEREKEN DE GLIJDENDE ICE/SKATER PHYSICS
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * current_max_speed, current_accel * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, current_friction * delta)

	# Voer de officiële verplaatsing uit van de engine
	move_and_slide()

	# --- REALTIME SCHILD REGENERATIE (GEKOPPELD AAN INTEGER ENERGIE) ---
	if can_regen_shield and stats:
		# God mode: schild laden kost geen energie en mag ook zonder energie.
		if stats.current_shield < stats.max_shield and (stats.current_energy > 0 or Game.debug_is_invincible):
			shield_accumulator += 10 * delta #tijd per punt regen
			
			if shield_accumulator >= 1.0:
				var points_to_add = int(shield_accumulator)
				shield_accumulator -= points_to_add
				
				var space_left = stats.max_shield - stats.current_shield
				var final_add = min(points_to_add, space_left)
				
				if final_add > 0:
					stats.current_shield += final_add
					
					# WISSELKOERS FIX: We trekken pas 1 energiepunt af zodra er cumulatief 10 schildpunten zijn gevuld!
					if stats.current_shield % 10 == 0 and not Game.debug_is_invincible:
						# GECORRIGEERD: Harde integer-afname tegen zwevende floating-point spookgetallen!
						var new_energy = int(stats.current_energy) - 1
						if new_energy <= 0:
							new_energy = 0
						stats.current_energy = new_energy
						
						# Werk de Global Hub direct live en type-veilig bij
						if is_instance_valid(Game):
							Game.set_meta("transit_shield", stats.current_shield)
							Game.set_meta("transit_energy", stats.current_energy)
						print("ENERGIE-ACCU: 10 schildpunten gevuld! 1 Energiepunt afgerekend. Rest: ", stats.current_energy)

	# 4. SCHIETEN gebeurt verderop in deze functie, onder "2. SCHIETMOTOR".
	# Daar wordt eerst gecontroleerd of het wapen klaar is met herladen (can_fire).


	# --- 5. WERELDGRENZEN ---
	# De regels staan in Systems/room_bounds.gd, zodat vijanden precies dezelfde ruimte hebben.
	if is_instance_valid(LevelManager):
		# Op de Zuidpool loop je links/rechts rond: houd de camera daar wijd open.
		if LevelManager.current_layer == 0 and has_node("Camera2D"):
			var cam = get_node("Camera2D")
			cam.limit_left = -10000
			cam.limit_right = 10000
		var enemies_alive: bool = get_tree().get_nodes_in_group("targets").size() + get_tree().get_nodes_in_group("enemies").size() > 0
		RoomBounds.apply(self, 30.0, enemies_alive)
	
	# 1. WAPENWISSEL: zie _unhandled_input (scrollen of 1 t/m 4).

	# =========================================================================
	# 2. GECORRIGEERDE SCHIETMOTOR: Nu met harde herlaad-beveiliging!
	# =========================================================================
	# De herlaad-as is vanaf nu de baas: als de timer loopt, mag er NIET geschoten worden.
	# Dit haalt de dubbele/viervoudige schade onvoorwaardelijk weg bij alle wapens!
	if can_fire:
		# B. CSV-GESTUURDE VUURMODUS
		var weapon_is_auto: bool = current_weapon_stats.get("is_full_auto", 1.0) == 1.0
		
		if weapon_is_auto:
			# AUTOMATISCH: Vuren zolang je de knop ingedrukt houdt
			if Input.is_action_pressed("fire_primary") or Input.is_action_pressed("ui_accept"):
				fire_primary_weapon()
		else:
			# SEMI-AUTOMATISCH: Je moet de knop herhaaldelijk EENMALIG indrukken per schot
			if Input.is_action_just_pressed("fire_primary") or Input.is_action_just_pressed("ui_accept"):
				fire_primary_weapon()
			
			
				# --- REALTIME SSoT HUB SYNCHRONISATIE ---
	# Dit garandeert dat ELK los puntje HP, Schild of Energie (zoals 77 of 88) 
	# direct wereldwijd bekend is, wat afrondings-terugval bij poorten 100% uitsluit!
	if is_instance_valid(Game) and stats:
		Game.set_meta("transit_health", int(stats.current_health))
		Game.set_meta("transit_shield", int(stats.current_shield))
		Game.set_meta("transit_energy", int(stats.current_energy))

	# =========================================================================


# --- WAPENWISSEL ---
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


## Na een wissel, een nieuw wapen of een ruil: laad het gekozen wapen en toon het wiel.
func on_weapons_changed() -> void:
	var weapon: String = RunState.selected_weapon()
	if weapon != Game.active_weapon_key:
		Game.active_weapon_key = weapon
		_load_weapon_stats(weapon)
		print("WAPEN: gewisseld naar ", weapon)
	if is_instance_valid(_weapon_wheel):
		_weapon_wheel.show_wheel()


# --- WAPENWAARDEN UIT DE SSOT ---
# Vult current_weapon_stats met de waarden van dit wapen uit de SSOT (via SsotWeapon).
# Skills en items tellen mee (StatCalc.player_value). De sleutels blijven hetzelfde als
# vroeger, zodat de kogel en het F1-scherm ze gewoon kunnen blijven lezen.
func _load_weapon_stats(weapon_key: String) -> void:
	if not Ssot.has_row(weapon_key):
		push_warning("PLAYER: wapen '%s' staat niet in de SSOT; standaardwaarden gebruikt." % weapon_key)
		current_weapon_stats = {"damage": 5.0, "base_fire_rate": 0.5, "weapon_range": 300.0, "is_full_auto": 0.0, "bullet_per_shot": 1, "muzzle_count": 1, "bullet_spread": 0.0, "bullet_speed": 700.0}
		return
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
	}


# --- SCHIETMOTOR: 100% Uitgelijnd op de SSoT CSV Kolommen ---
func fire_primary_weapon() -> void:
	if not weapon_output_scene or not stats: return
	
	# Controleer energieverbruik voor speciale wapens (alles behalve het startpistool)
	var active_key = str(Game.active_weapon_key).to_lower()
	var is_special_weapon = "pistol" not in active_key and active_key != ""
	
	# God mode negeert de energie helemaal: schieten mag altijd en kost niets.
	if is_special_weapon and stats.current_energy <= 0 and not Game.debug_is_invincible:
		print("WAPEN GEBLOKKEERD: Geen energie meer! Schakel terug naar je startpistool.")
		return
		
	can_fire = false
	
	# BINGO: We halen de waarden RECHTSTREEKS uit de achterste kolommen van de actieve CSV-rij!
	# Als de dictionary de kolommen niet heeft, vallen we veilig terug op de stabiele standaarden (1 kogel, 0 spread)
	var bullets_to_spawn = int(current_weapon_stats.get("bullet_per_shot", 1))
	var spread = float(current_weapon_stats.get("bullet_spread", 0.0))
	
	# De schade halen we uit de 'base_stats_or_targets' string die jullie in _ready() hebben geparsed
	var dmg = float(current_weapon_stats.get("damage", 5.0))
	
	# Converteer de spread van graden naar radialen als er spreiding in de kolom staat
	var spread_rad = deg_to_rad(spread) if spread > 0.0 else 0.0
	
	# Lopen (muzzles): uit de SSOT (base_muzzle_count), of het aantal uit het F1-menu als dat niet op SSOT staat.
	# De lopen staan naast elkaar, haaks op de schietrichting; elke loop schiet het hele patroon.
	var muzzles: int = Game.debug_muzzle_count if Game.debug_muzzle_count > 0 else maxi(1, int(current_weapon_stats.get("muzzle_count", 1)))
	var side: Vector2 = global_transform.y.normalized()
	
	# De exacte vuurlus: schiet exact 1 kogel voor het pistool (5 dmg) en exact 5 voor de shotgun!
	for shot in range(bullets_to_spawn * muzzles):
		var i: int = shot % bullets_to_spawn
		var m: int = floori(float(shot) / bullets_to_spawn)
		var muzzle_offset: Vector2 = side * ((m - (muzzles - 1) / 2.0) * MUZZLE_SPACING)
		var bullet = weapon_output_scene.instantiate()
		
		var final_spread = 0.0
		if bullets_to_spawn > 1:
			# Verdeelt de kogels netjes in een waaier-kegel op basis van de CSV-hoek
			final_spread = lerp(-spread_rad, spread_rad, float(i) / float(bullets_to_spawn - 1))
		elif spread_rad > 0.0:
			# Eén kogel: een willekeurige afwijking binnen de spreiding (basis voor de accuracy-skill).
			final_spread = randf_range(-spread_rad, spread_rad)
			
		# Kogelsnelheid uit de SSOT (base_bullet_speed). Vóór add_child, want de kogel rekent in _ready verder.
		if "speed" in bullet:
			bullet.speed = float(current_weapon_stats.get("bullet_speed", bullet.speed))
		# Het damage type gaat mee met de kogel (de testdummy laat het zien).
		if "damage_type" in bullet:
			bullet.damage_type = str(current_weapon_stats.get("damage_type", ""))
		bullet.global_position = global_position + muzzle_offset
		bullet.global_rotation = global_rotation + final_spread
		
		# Geef de exacte schade door aan het projectiel
		if bullet.has_method("init_projectile"):
			bullet.init_projectile(dmg)
		elif "damage" in bullet:
			bullet.damage = dmg
			
		get_tree().current_scene.add_child(bullet)
	
	# --- ENERGIEAFNAME BIJ SCHIETEN ---
	if is_special_weapon and not Game.debug_is_invincible:
		stats.current_energy = max(0, stats.current_energy - 2)
		print("SPECIAL SHOT: Energie verbruikt! Rest-energie: ", stats.current_energy)
	
	# --- SSoT VUURSNELHEID EXTRACTOR ---
	var fire_rate = 0.3 # Veilige standaard fallback
	
	# Controleer flexibel alle mogelijke SSoT naamgevingen uit de database
	if current_weapon_stats.has("base fire rate"):
		fire_rate = float(current_weapon_stats["base fire rate"])
	elif current_weapon_stats.has("base_fire_rate"):
		fire_rate = float(current_weapon_stats["base_fire_rate"])
	elif current_weapon_stats.has("base_stats") and current_weapon_stats["base_stats"] is Dictionary:
		var sub_stats = current_weapon_stats["base_stats"]
		if sub_stats.has("base fire rate"):
			fire_rate = float(sub_stats["base fire rate"])
		elif sub_stats.has("base_fire_rate"):
			fire_rate = float(sub_stats["base_fire_rate"])
			
	print("PLAYER GUN: Vuren geaccepteerd! Wachttijd tot volgend schot: ", fire_rate, " seconden.")
	
	# Activeer de herlaad-pauze conform de database
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true




# UNIVERSELE HITBOX: Regelt de contact-schade met schild-absorptie en regeneratie-resets
func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	
	if body.is_in_group("enemies") or body.is_in_group("targets"):
		print("BOTSING: Astronaut en ", body.name, " hebben elkaar geraakt!")
		
		# --- 1. SCHADE AAN DE SPELER (zie take_damage hieronder) ---
		if take_damage(10):
			return
		
		# --- 2. SCHADE AAN DE VIJAND / FABRIEK (Wederkerig!) ---
		if body.has_method("take_damage"):
			var hit_direction = (body.global_position - global_position).normalized()
			body.take_damage(10, true, hit_direction)
			
		# --- 3. ARCADE JUICE KNOCKBACK ---
		var knockback_dir = (global_position - body.global_position).normalized()
		velocity = knockback_dir * 350.0
		if "velocity" in body:
			body.velocity = -knockback_dir * 250.0


# Schade aan de speler, met schild-absorptie. Wordt gebruikt bij botsingen en ontploffingen.
# Geeft true terug als de speler hierdoor is overleden (de run is dan al afgehandeld).
func take_damage(amount: int, _flash: bool = true, _hit_dir: Vector2 = Vector2.ZERO) -> bool:
	# Schild vangt eerst op, de rest gaat van de HP af.
	if stats and not Game.debug_is_invincible:
		# Onderbreek het opladen direct en herstart de 3 seconden klok
		can_regen_shield = false
		if is_instance_valid(shield_regen_timer):
			shield_regen_timer.start()
			
		var incoming_damage: int = amount
		
		if stats.current_shield > 0:
			if stats.current_shield >= incoming_damage:
				stats.current_shield -= incoming_damage
				incoming_damage = 0
				print("-> Schild vangt de klap op! Schild over: ", stats.current_shield)
			else:
				incoming_damage -= stats.current_shield
				stats.current_shield = 0
				print("-> Schild BREEKT! Resterende schade voor HP: ", incoming_damage)
				
		if incoming_damage > 0:
			stats.current_health = max(0, stats.current_health - incoming_damage)
			print("-> HP incasseert schade. HP over: ", stats.current_health)
			
			if is_instance_valid(Game):
				Game.set_meta("transit_health", stats.current_health)
				Game.set_meta("transit_shield", stats.current_shield)
			
		if has_method("update_hud"): 
			call_deferred("update_hud")
			
		# DOODSCHECK
		if stats.current_health <= 0:
			print("PLAYER: Astronaut is overleden. Start run-afhandeling via Global Hub...")
			# De buit van deze run gaat naar de kluis.
			LootResources.bank_run_loot()
			Game.should_load_run = false
			var save_sys = load("res://Systems/SaveSystem.gd").new()

			if save_sys and save_sys.has_method("delete_current_run_save"):
				save_sys.delete_current_run_save()
			
			# RunState afsluiten: wist de dodenlijst en de kamer-momentopnames van deze run.
			RunState.end_run()
				
			if is_instance_valid(LevelManager):
				LevelManager.reset_manager_for_new_run()
				
			get_tree().call_deferred("change_scene_to_file", "res://Systems/main_menu.tscn")
			return true
	return false


# --- SSoT LIVE HERSTEL VOOR CONTINUE ---
func _force_continue_position() -> void:
	var continue_path = "user://" + Game.active_save_slot + "/current_run.json"
	if not FileAccess.file_exists(continue_path): return
	
	var c_file = FileAccess.open(continue_path, FileAccess.READ)
	var c_json = JSON.new()
	if c_json.parse(c_file.get_as_text()) == OK:
		var run_data = c_json.get_data()
		var found_pos = Vector2.ZERO
		var has_x = false
		var has_y = false
		
		# We halen de exacte X en Y coördinaten live van de harde schijf
		if run_data.has("player_x"): 
			found_pos.x = float(run_data["player_x"])
			has_x = true
		if run_data.has("player_y"): 
			found_pos.y = float(run_data["player_y"])
			has_y = true

			
		if has_x and has_y and found_pos != Vector2.ZERO:
			global_position = found_pos
			global_transform.origin = found_pos
			print("PLAYER HARD-LOCK: Positie succesvol hersteld op pixel: ", global_position)
			
		# De run-buit komt uit RunState (run_state.json), niet uit dit bestand.
		
	c_file.close()

# --- SSoT HEALTH TICK: Tikt elke 3 seconden met 33% kans op 1 HP herstel ---
func _on_health_regen_tick() -> void:
	if not stats or stats.current_health <= 0: return
	
	if stats.current_health < stats.max_health and randf() <= 0.33:
		stats.current_health = min(stats.max_health, stats.current_health + 1)
		print("HEALTH REGEN: Geluksrol geslaagd! 1 HP hersteld. Actueel HP: ", stats.current_health)

# --- SSoT GLOBAL SAVE ENGINE: Beveiligt live X/Y coördinaten, de balken én alle 6 de winst-tellers ---
func save_live_run_state_to_disk() -> void:
	if not stats: return
	
	# ERNSTIG: Sla de EXACTE waarden van DIT milliseconde-frame op in de Global Hub metadata!
	# Dit garandeert dat de volgende kamer exact de juiste stand overneemt.
	if is_instance_valid(Game):
		Game.set_meta("transit_health", int(stats.current_health))
		Game.set_meta("transit_shield", int(stats.current_shield))
		Game.set_meta("transit_energy", int(stats.current_energy))
		
	# Schrijf de winst en status ook direct mee in de resource metadata
	stats.set_meta("transit_health", int(stats.current_health))
	stats.set_meta("transit_shield", int(stats.current_shield))
	stats.set_meta("transit_energy", int(stats.current_energy))
	
	var slot_folder = "user://" + Game.active_save_slot + "/"
	ResourceSaver.save(stats, slot_folder + "Player_Data.tres")
	
	# Vanaf hier gaat de rest van jullie bestaande JSON-opslag (coördinaten etc.) ongewijzigd verder...
	var full_path = slot_folder + "current_run.json"
	var run_data = {}


	
	if FileAccess.file_exists(full_path):
		var file = FileAccess.open(full_path, FileAccess.READ)
		var json = JSON.new()
		if json.parse(file.get_as_text()) == OK:
			run_data = json.get_data()
		file.close()
		
	run_data["current_layer"] = LevelManager.current_layer
	run_data["current_room_index"] = LevelManager.current_room_index
	run_data["player_x"] = global_position.x
	run_data["player_y"] = global_position.y
	
	var write_file = FileAccess.open(full_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(run_data, "\t"))
		write_file.close()
		print("PLAYER SYSTEM: Complete run-status én statusbalken waterdicht opgeslagen op schijf!")
