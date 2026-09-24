extends CharacterBody2D
class_name Player

# --- CONFIGURATIE & SCENE LINKS ---
@export var weapon_output_scene: PackedScene = preload("res://Entities/Weapon Output/weapon_output.tscn")

var stats: Resource = null
var can_fire: bool = true

# Live run-portemonnee administratie
var run_currency_olrite: int = 0
var run_currency_gold: int = 0
var run_currency_keepium: int = 0
var run_currency_element1: int = 0
var run_currency_element2: int = 0
var run_currency_element3: int = 0

var current_weapon_stats: Dictionary = {}


func _ready() -> void:
	# 1. AUTOLOAD LINK: Registreer deze actieve speler direct in de globale cockpit
	if is_instance_valid(Game):
		Game.active_player = self
		print("PLAYER: Succesvol gekoppeld aan de Game Global Hub.")
		
	# 2. INLADEN RESOURCE DATA
	stats = load("res://Resources/Player_Data.tres")
	
	if stats:
		stats.current_health = stats.max_health
		stats.loot_magnet_applied = false
		
		if stats.currency_olrite > 0:
			run_currency_olrite = stats.currency_olrite
			run_currency_gold = stats.currency_gold
			run_currency_keepium = stats.currency_keepium
			run_currency_element1 = stats.currency_element1
			run_currency_element2 = stats.currency_element2
			run_currency_element3 = stats.currency_element3
		else:
			if is_instance_valid(LevelManager) and LevelManager.current_layer == 0 and not Game.should_load_run:
				stats.currency_olrite = 0
				stats.currency_gold = 0
				stats.currency_keepium = 0
				stats.currency_element1 = 0
				stats.currency_element2 = 0
				stats.currency_element3 = 0
				
		run_currency_olrite = stats.currency_olrite
		run_currency_gold = stats.currency_gold
		run_currency_keepium = stats.currency_keepium
		run_currency_element1 = stats.currency_element1
		run_currency_element2 = stats.currency_element2
		run_currency_element3 = stats.currency_element3
		
	# 3. WAPEN INITIALISATIE UIT DATABASE
	if "weapon_gatling" in MasterDatabase.weapon_data:
		var csv_row = MasterDatabase.weapon_data["weapon_gatling"]
		current_weapon_stats = csv_row["base_stats"].duplicate()
	else:
		current_weapon_stats = {"base_fire_rate": 0.3, "is_full_auto": 0.0}
		
	get_tree().call_group("projectiles", "queue_free")
	
	# --- 4. UNIVERSELE HUD REFRESH ---
	await get_tree().process_frame
	await get_tree().process_frame
	
	var active_scene = get_tree().current_scene
	if active_scene and is_instance_valid(active_scene):
		var all_labels = active_scene.find_children("*", "Label", true, false)
		for lbl in all_labels:
			if "1" in lbl.name or "olrite" in lbl.name.to_lower():
				lbl.text = "Olrite: " + str(run_currency_olrite)
				print("HUD FIX: Live Olrite-cijfers geforceerd op label node: ", lbl.name)


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

	# 4. INPUT-KOPPELING: Schieten via fire_primary of ui_accept
	if Input.is_action_pressed("fire_primary") or Input.is_action_pressed("ui_accept"):
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




# KOGELVRIJE SCHIET-AS (Hersteld naar de werkende globale offset-rotatie!)
func fire_primary_weapon() -> void:
	if not can_fire or not is_inside_tree() or get_tree() == null: return
	
	var active_scene = get_tree().current_scene
	if not active_scene or not is_instance_valid(active_scene): return
	
	can_fire = false
	
	var muzzles_parent = find_child("Muzzles", true, false)
	var active_muzzles: Array = []
	if muzzles_parent:
		for m in muzzles_parent.get_children():
			if is_instance_valid(m): active_muzzles.append(m)

	if active_muzzles.is_empty():
		var bullet_instance = weapon_output_scene.instantiate()
		bullet_instance.global_position = global_position
		bullet_instance.global_rotation = global_rotation
		active_scene.add_child(bullet_instance)
	else:
		for m_node in active_muzzles:
			if is_instance_valid(m_node):
				var bullet_instance = weapon_output_scene.instantiate()
				
				# DE WERKENDER FIX: Bereken de positie direct vanaf de Player global_position,
				# en roteer de lokale offset van de marker mee. Dit elimineert (0,0) laadfouten volledig!
				var local_offset = m_node.position
				var rotated_offset = local_offset.rotated(global_rotation)
				
				bullet_instance.global_position = global_position + rotated_offset
				bullet_instance.global_rotation = global_rotation + m_node.rotation
				active_scene.add_child(bullet_instance)
			
	await get_tree().create_timer(current_weapon_stats.get("base_fire_rate", 0.3)).timeout
	can_fire = true
