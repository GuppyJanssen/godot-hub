extends CharacterBody2D
class_name Player

# --- CONFIGURATIE & SCENE LINKS ---
@export var weapon_output_scene: PackedScene = preload("res://Entities/Weapon Output/weapon_output.tscn")

var stats: Resource = null
var can_fire: bool = true

# Live run-portemonnee administratie
var run_currency_olrite: int = 0
var run_currency_metal: int = 0
var run_currency_keepium: int = 0
var run_currency_element1: int = 0
var run_currency_element2: int = 0
var run_currency_element3: int = 0

# Live run-winst tellers (De + tellers in de HUD)
var run_loot_olrite: int = 0
var run_loot_metal: int = 0 
var run_loot_keepium: int = 0
var run_loot_element1: int = 0
var run_loot_element2: int = 0
var run_loot_element3: int = 0

# --- REGENERATIE EN ENERGIE MOTOR ---
var shield_regen_timer: Timer
var health_regen_timer: Timer
var can_regen_shield: bool = false
var shield_accumulator: float = 0.0


var current_weapon_stats: Dictionary = {}


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

	var is_absolute_start = (LevelManager.current_layer == 0 and LevelManager.current_room_index == 0 and not Game.should_load_run)

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
		
		# Laad het basissaldo in uit de database-resource
		run_currency_olrite = stats.currency_olrite
		run_currency_metal = stats.currency_metal if "currency_metal" in stats else (stats.currency_gold if "currency_gold" in stats else 0)
		run_currency_keepium = stats.currency_keepium
		run_currency_element1 = stats.currency_element1
		run_currency_element2 = stats.currency_element2
		run_currency_element3 = stats.currency_element3
		
		# 1. Directe SSoT-sync van het basissaldo met de Meta Progress database voor alle 6 de slots!
		var save_sys = load("res://Systems/SaveSystem.gd").new()
		if save_sys and save_sys.has_method("get_loaded_meta_progress"):
			var meta_data = save_sys.get_loaded_meta_progress()
			if meta_data:
				# Slot 1: Olrite
				run_currency_olrite = meta_data.currency_olrite if "currency_olrite" in meta_data else (meta_data.currency_1 if "currency_1" in meta_data else 0)
				
				# Slot 2: Metal (Met fallbacks voor gold/metal/currency_2)
				run_currency_metal = meta_data.currency_metal if "currency_metal" in meta_data else (meta_data.currency_gold if "currency_gold" in meta_data else (meta_data.currency_2 if "currency_2" in meta_data else 0))
				
				# Slot 3: Keepium
				run_currency_keepium = meta_data.currency_keepium if "currency_keepium" in meta_data else (meta_data.currency_3 if "currency_3" in meta_data else 0)
				
				# Slot 4: Element 1
				run_currency_element1 = meta_data.currency_element1 if "currency_element1" in meta_data else (meta_data.currency_4 if "currency_4" in meta_data else 0)
				
				# Slot 5: Element 2
				run_currency_element2 = meta_data.currency_element2 if "currency_element2" in meta_data else (meta_data.currency_5 if "currency_5" in meta_data else 0)
				
				# Slot 6: Element 3
				run_currency_element3 = meta_data.currency_element3 if "currency_element3" in meta_data else (meta_data.currency_6 if "currency_6" in meta_data else 0)
				
				print("PLAYER ENGINE: Vaste portemonnee succesvol gesynchroniseerd met Meta Progress. Olrite: ", run_currency_olrite)

		
		if is_absolute_start:
			print("PLAYER: Absolute start van een New Run. Reset winst-buffers naar +0")
			run_loot_olrite = 0
			run_loot_metal = 0
			run_loot_keepium = 0
			run_loot_element1 = 0
			run_loot_element2 = 0
			run_loot_element3 = 0
			
			if is_instance_valid(Game):
				Game.set_meta("run_loot_olrite", 0)
				Game.set_meta("run_loot_metal", 0)
				Game.set_meta("run_loot_keepium", 0)
				Game.set_meta("run_loot_element1", 0)
				Game.set_meta("run_loot_element2", 0)
				Game.set_meta("run_loot_element3", 0)
		else:
			# Herstel alle 6 de grondstofbalken vloeibaar bij een kamerwissel via de Global Hub metadata
			if is_instance_valid(Game):
				run_loot_olrite = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
				run_loot_metal = int(Game.get_meta("run_loot_metal")) if Game.has_meta("run_loot_metal") else 0
				run_loot_keepium = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
				run_loot_element1 = int(Game.get_meta("run_loot_element1")) if Game.has_meta("run_loot_element1") else 0
				run_loot_element2 = int(Game.get_meta("run_loot_element2")) if Game.has_meta("run_loot_element2") else 0
				run_loot_element3 = int(Game.get_meta("run_loot_element3")) if Game.has_meta("run_loot_element3") else 0
			
		# Laad de live run-variabelen direct in vanuit de stabiele schijf-resource
		run_currency_olrite = stats.currency_olrite
		run_currency_metal = stats.currency_metal
		run_currency_keepium = stats.currency_keepium
		run_currency_element1 = stats.currency_element1
		run_currency_element2 = stats.currency_element2
		run_currency_element3 = stats.currency_element3

	# 3. TIMING FIX: We wachten tot de LevelManager én het SaveSystem klaar zijn
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	if stats:
		# BINGO: Als de debug-knop de live run_currencies heeft veranderd, 
		# drukken we ze hier direct terug in de stats-resource zodat de transities werken!
		if stats.currency_olrite != run_currency_olrite: stats.currency_olrite = run_currency_olrite
		if stats.currency_metal != run_currency_metal: stats.currency_metal = run_currency_metal
		if stats.currency_keepium != run_currency_keepium: stats.currency_keepium = run_currency_keepium
		if stats.currency_element1 != run_currency_element1: stats.currency_element1 = run_currency_element1
		if stats.currency_element2 != run_currency_element2: stats.currency_element2 = run_currency_element2
		if stats.currency_element3 != run_currency_element3: stats.currency_element3 = run_currency_element3

	# 4. LEIDENDE AS: Wapenstats inladen uit de CSV
	var active_weapon_key = Game.active_weapon_key
	if active_weapon_key in MasterDatabase.weapon_data:
		var csv_row = MasterDatabase.weapon_data[active_weapon_key]
		current_weapon_stats = csv_row["base_stats"].duplicate()
		current_weapon_stats["is_full_auto"] = csv_row.get("is_full_auto", 1.0)
		current_weapon_stats["bullet_per_shot"] = csv_row.get("bullet_per_shot", 1)
		current_weapon_stats["muzzle_count"] = csv_row.get("muzzle_count", 1)
		current_weapon_stats["bullet_spread"] = csv_row.get("bullet_spread", 0.0)
	else:
		current_weapon_stats = {"damage": 10.0, "base_fire_rate": 0.3, "is_full_auto": 1.0, "bullet_per_shot": 1, "muzzle_count": 1, "bullet_spread": 0.0}

	# BINGO: Als we een run hervatten via Continue, roepen we uitgesteld de pixel-forcerder aan!
	if Game.should_load_run:
		call_deferred("_force_continue_position")


	get_tree().call_group("projectiles", "queue_free")


	# --- INITIALISATIE REGENERATIE EN ENERGIE TIMERS ---
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
		if stats.current_shield < stats.max_shield and stats.current_energy > 0:
			shield_accumulator += 10 * delta #tijd per punt regen
			
			if shield_accumulator >= 1.0:
				var points_to_add = int(shield_accumulator)
				shield_accumulator -= points_to_add
				
				var space_left = stats.max_shield - stats.current_shield
				var final_add = min(points_to_add, space_left)
				
				if final_add > 0:
					stats.current_shield += final_add
					
					# WISSELKOERS FIX: We trekken pas 1 energiepunt af zodra er cumulatief 10 schildpunten zijn gevuld!
					if stats.current_shield % 10 == 0:
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

	# 4. CSV-GESTUURDE INPUT-KOPPELING: Schieten via fire_primary
	# We kijken eerst of de CSV of de debug-multiplier zegt dat het wapen Full Auto is
	var weapon_is_auto: bool = current_weapon_stats.get("is_full_auto", 1.0) == 1.0 and Game.debug_is_full_auto
	
	if weapon_is_auto:
		# Automatisch: Zolang je de knop INGEDRUKT houdt, blijft hij vuren
		if Input.is_action_pressed("fire_primary") or Input.is_action_pressed("ui_accept"):
			fire_primary_weapon()
	else:
		# Semi-automatisch: Je moet de knop herhaaldelijk EENMALIG INDRUKKEN (just_pressed) per schot
		if Input.is_action_just_pressed("fire_primary") or Input.is_action_just_pressed("ui_accept"):
			fire_primary_weapon()


	# --- 5. KOGELVRIJE EN LIVE-ACTIEVE WERELDGRENZEN OP DE POLEN ---
	if is_instance_valid(LevelManager):
		var current_layer = LevelManager.current_layer
		var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
		
		# Deze specifieke grenscontroles gelden uitsluitend voor de Zuidpool en Noordpool (Eindbaas)
		if current_layer == 0 or current_layer == max_layer_index:
			var screen_width: float = 1920.0
			var _screen_height: float = 1080.0
			var _player_radius: float = 30.0
			
			# Camera Guard: Houd de camera-limieten wijd open op de Zuidpool voor de wrap
			if current_layer == 0 and has_node("Camera2D"):
				var cam = get_node("Camera2D")
				if is_instance_valid(cam):
					cam.limit_left = -10000
					cam.limit_right = 10000
			
			# SCREEN-WRAPPING (Oost/West): Altijd actief vanaf frame 1 op de polen!
			if global_position.x < -10.0:
				global_position.x = screen_width + 5.0
			elif global_position.x > screen_width + 10.0:
				global_position.x = -5.0
				
	# --- WERELDGRENZEN EN BARRIÈRES PER REGIO ---
	if is_instance_valid(LevelManager):
		var current_layer = LevelManager.current_layer
		var max_layer_index = LevelManager.LAYER_WIDTHS.size() - 1
		
		var screen_width: float = 1920.0
		var screen_height: float = 1080.0
		var player_radius: float = 30.0
		
		# Tel live het aantal vijanden in de actieve kamer
		var enemies = get_tree().get_nodes_in_group("targets").size() + get_tree().get_nodes_in_group("enemies").size()
		var enemies_alive: bool = enemies > 0
		
		# SPECIFIEKE GRENZEN PER POOL (Zuidpool versus Noordpool)
		if current_layer == 0:
			# ZUIDPOOL INRICHTING:			
			# GECORRIGEERD: Staat nu op player_radius (30 pixels) net als de rest van de game!
			# De player staat nu netjes stil vóór de trigger-zone van de transitie.
			var top_limit = player_radius
			if enemies_alive and global_position.y < top_limit:
				global_transform.origin.y = top_limit
				velocity.y = 0
			
			# HARD ZUID-SLOT (Onderkant): De permanente onzichtbare wand
			var bottom_limit = screen_height - player_radius
			if global_position.y > bottom_limit:
				global_transform.origin.y = bottom_limit
				velocity.y = 0
				
		elif current_layer == max_layer_index:
			# NOORDPOOL (EINDBAAS) INRICHTING:
			# Bovenkant (Noord) is de absolute permanente wereldgrens
			var top_limit = player_radius
			if global_position.y < top_limit:
				global_transform.origin.y = top_limit
				velocity.y = 0

				
			# Zijkanten en onderkant stoppen de player ALS er vijanden leven
			if enemies_alive:
				if global_position.x < player_radius:
					global_position.x = player_radius
					velocity.x = 0
				elif global_position.x > screen_width - player_radius:
					global_position.x = screen_width - player_radius
					velocity.x = 0
				if global_position.y > screen_height - player_radius:
					global_position.y = screen_height - player_radius
					velocity.y = 0
					
		# SCENARIO C: DE NORMALE RUIMTE-KAMERS (Ring 1 en hoger)
		else:
			# Als er vijanden leven, zitten alle 4 de zijden onwrikbaar OP SLOT!
			if enemies_alive:
				# West-grens (Links)
				if global_position.x < player_radius:
					global_position.x = player_radius
					velocity.x = 0
				# Oost-grens (Rechts)
				elif global_position.x > screen_width - player_radius:
					global_position.x = screen_width - player_radius
					velocity.x = 0
				# Noord-grens (Boven)
				if global_position.y < player_radius:
					global_position.y = player_radius
					velocity.y = 0
				# Zuid-grens (Beneden)
				elif global_position.y > screen_height - player_radius:
					global_position.y = screen_height - player_radius
					velocity.y = 0


				# NOORDPOOL (EINDBAAS) INRICHTING:
				# Bovenkant (Noord) is de absolute permanente wereldgrens
				var top_limit = player_radius
				if global_position.y < top_limit:
					global_transform.origin.y = top_limit
					velocity.y = 0

	
	# A. GECORRIGEERD: Slaat de live-keuze direct op in de Global Hub voor de transities!
	var new_target = ""
	if Input.is_key_pressed(KEY_1): new_target = "weapon_pistol"
	elif Input.is_key_pressed(KEY_2): new_target = "weapon_shotgun"
	elif Input.is_key_pressed(KEY_3): new_target = "weapon_gatling"
	
	# 1. DE WAPENWISSEL AS (1, 2, 3 INPUTS)
	if new_target != "" and Game.active_weapon_key != new_target:
		if new_target in MasterDatabase.weapon_data:
			# Overschrijf de wereldwijde SSoT sleutel direct!
			Game.active_weapon_key = new_target
			
			var csv_row = MasterDatabase.weapon_data[Game.active_weapon_key]
			current_weapon_stats = csv_row["base_stats"].duplicate()
			current_weapon_stats["is_full_auto"] = csv_row.get("is_full_auto", 1.0)
			current_weapon_stats["bullet_per_shot"] = csv_row.get("bullet_per_shot", 1)
			current_weapon_stats["muzzle_count"] = csv_row.get("muzzle_count", 1)
			current_weapon_stats["bullet_spread"] = csv_row.get("bullet_spread", 0.0)
			
			print("TEST-SWAP: Live gewisseld naar " + Game.active_weapon_key + " | Kogels: " + str(current_weapon_stats["bullet_per_shot"]))

	# =========================================================================
	# 2. GECORRIGEERDE SCHIETMOTOR: Nu met harde herlaad-beveiliging!
	# =========================================================================
	# De herlaad-as is vanaf nu de baas: als de timer loopt, mag er NIET geschoten worden.
	# Dit haalt de dubbele/viervoudige schade onvoorwaardelijk weg bij alle wapens!
	if not can_fire: return
	
	# B. CSV-GESTUURDE VUURMODUS (We gebruiken jullie bestaande globale variabele)
	weapon_is_auto = current_weapon_stats.get("is_full_auto", 1.0) == 1.0
	
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


# --- SCHIETMOTOR: 100% Uitgelijnd op de SSoT CSV Kolommen ---
func fire_primary_weapon() -> void:
	if not weapon_output_scene or not stats: return
	
	# Controleer energieverbruik voor speciale wapens (alles behalve het startpistool)
	var active_key = str(Game.active_weapon_key).to_lower()
	var is_special_weapon = "pistol" not in active_key and active_key != ""
	
	if is_special_weapon and stats.current_energy <= 0:
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
	
	# De exacte vuurlus: schiet exact 1 kogel voor het pistool (5 dmg) en exact 5 voor de shotgun!
	for i in range(bullets_to_spawn):
		var bullet = weapon_output_scene.instantiate()
		
		var final_spread = 0.0
		if bullets_to_spawn > 1:
			# Verdeelt de kogels netjes in een waaier-kegel op basis van de CSV-hoek
			final_spread = lerp(-spread_rad, spread_rad, float(i) / float(bullets_to_spawn - 1))
			
		bullet.global_position = global_position
		bullet.global_rotation = global_rotation + final_spread
		
		# Geef de exacte schade door aan het projectiel
		if bullet.has_method("init_projectile"):
			bullet.init_projectile(dmg)
		elif "damage" in bullet:
			bullet.damage = dmg
			
		get_tree().current_scene.add_child(bullet)
	
	# --- ENERGIEAFNAME BIJ SCHIETEN ---
	if is_special_weapon:
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
	
	# Activeer de herlaad-pauze conform de database
	await get_tree().create_timer(fire_rate).timeout
	can_fire = true




# UNIVERSELE HITBOX: Regelt de contact-schade met schild-absorptie en regeneratie-resets
func _on_player_hitbox_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	
	if body.is_in_group("enemies") or body.is_in_group("targets"):
		print("BOTSING: Astronaut en ", body.name, " hebben elkaar geraakt!")
		
		# --- 1. SCHADE AAN DE SPELER MET SCHILD-ABSORPTIE ---
		if stats and not Game.debug_is_invincible:
			# Onderbreek het opladen direct en herstart de 3 seconden klok
			can_regen_shield = false
			if is_instance_valid(shield_regen_timer):
				shield_regen_timer.start()
				
			var incoming_damage: int = 10
			
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
				var save_sys = load("res://Systems/SaveSystem.gd").new()
				if save_sys and save_sys.has_method("get_loaded_meta_progress") and is_instance_valid(Game):
					var meta = save_sys.get_loaded_meta_progress()
					if meta:
						var w_olrite = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
						var w_metal  = int(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else 0
						var w_keep   = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
						
						if "currency_olrite" in meta: meta.currency_olrite += w_olrite
						elif "currency_1" in meta: meta.currency_1 += w_olrite
						if "currency_metal" in meta: meta.currency_metal += w_metal
						elif "currency_2" in meta: meta.currency_2 += w_metal
						if "currency_keepium" in meta: meta.currency_keepium += w_keep
						elif "currency_3" in meta: meta.currency_3 += w_keep
						
						if save_sys.has_method("save_meta_progress"):
							save_sys.save_meta_progress(meta)
							
						if stats:
							stats.currency_olrite += w_olrite
							stats.currency_metal = meta.currency_metal if "currency_metal" in meta else (meta.currency_2 if "currency_2" in meta else stats.currency_metal + w_metal)
							stats.currency_keepium += w_keep
							
							var slot_folder = "user://" + Game.active_save_slot + "/"
							ResourceSaver.save(stats, slot_folder + "Player_Data.tres")

					Game.set_meta("run_loot_olrite", 0)
					Game.set_meta("run_loot_metal", 0)
					Game.set_meta("run_loot_keepium", 0)
					Game.set_meta("run_loot_element1", 0)
					Game.set_meta("run_loot_element2", 0)
					Game.set_meta("run_loot_element3", 0)
					Game.should_load_run = false

				if save_sys and save_sys.has_method("delete_current_run_save"):
					save_sys.delete_current_run_save()
					
				if is_instance_valid(LevelManager):
					LevelManager.reset_manager_for_new_run()
					
				get_tree().call_deferred("change_scene_to_file", "res://Systems/main_menu.tscn")
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
			
		# Herstel de run-loot winst-tellers uit de JSON zodat ze in de HUD blijven staan
		if run_data.has("run_loot_olrite"): Game.set_meta("run_loot_olrite", int(float(run_data["run_loot_olrite"])))
		if run_data.has("run_loot_metal"):  Game.set_meta("run_loot_metal",  int(float(run_data["run_loot_metal"])))
		if run_data.has("run_loot_keepium"): Game.set_meta("run_loot_keepium", int(float(run_data["run_loot_keepium"])))
		if run_data.has("run_loot_element1"): Game.set_meta("run_loot_element1", int(float(run_data["run_loot_element1"])))
		if run_data.has("run_loot_element2"): Game.set_meta("run_loot_element2", int(float(run_data["run_loot_element2"])))
		if run_data.has("run_loot_element3"): Game.set_meta("run_loot_element3", int(float(run_data["run_loot_element3"])))
		
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
		
		Game.set_meta("run_loot_olrite", run_loot_olrite)
		Game.set_meta("run_loot_metal", run_loot_metal)
		Game.set_meta("run_loot_keepium", run_loot_keepium)
		Game.set_meta("run_loot_element1", run_loot_element1)
		Game.set_meta("run_loot_element2", run_loot_element2)
		Game.set_meta("run_loot_element3", run_loot_element3)
	
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
	
	run_data["run_loot_olrite"] = run_loot_olrite
	run_data["run_loot_metal"] = run_loot_metal
	run_data["run_loot_keepium"] = run_loot_keepium
	run_data["run_loot_element1"] = run_loot_element1
	run_data["run_loot_element2"] = run_loot_element2
	run_data["run_loot_element3"] = run_loot_element3
	
	var write_file = FileAccess.open(full_path, FileAccess.WRITE)
	if write_file:
		write_file.store_string(JSON.stringify(run_data, "\t"))
		write_file.close()
		print("PLAYER SYSTEM: Complete run-status én statusbalken waterdicht opgeslagen op schijf!")
