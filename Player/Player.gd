extends CharacterBody2D

class_name Player 

# --- DATA RESOURCES ---
@export var stats: PlayerStats

# De projectiel-scène (voorheen bullet_scene)
@export var weapon_output_scene: PackedScene

# De actieve data-blauwdruk van het wapen (Resource)
@export var active_weapon_data: Resource


# --- NODES ---
@onready var muzzle: Marker2D = $Muzzle_1


# --- RUN VOORTGANG (ROGUELIKE) ---
# Dit houdt de buit van de huidige run bij. Begint elke run netjes op 0.
var run_xp_earned: int = 0
var run_currency_earned: int = 0
var can_fire: bool = true


# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	# Dwing alle menu-knoppen om hun focus direct los te laten bij de start
	get_viewport().gui_release_focus()
	
	# INITIALISATIE: We dwingen de live HP bij de start van de run naar de maximale gezondheid!
	if stats:
		stats.current_health = stats.health
		print("SPELER STATS: Levensbalk gevuld! HP: ", stats.current_health, "/", stats.health)

	if not stats:
		push_error("Fout: player_data.tres is niet gekoppeld!")
		
	# TIJDELIJKE TEST-SIMULATIE: 
	# We starten fictief met wat buit om de wiskunde op de harde schijf te kunnen testen.
	run_xp_earned = 15
	run_currency_earned = 50

	# ROOMSPAWN-POSITIONERING: We vragen de LevelManager waar we moeten starten!
	# We geven de richting mee waar we zojuist naartoe zijn gereisd
	var last_direction = "up" # Standaard startwaarde voor de allereerste kamer
	if LevelManager.has_meta("last_direction"):
		last_direction = LevelManager.get_meta("last_direction")
		
	global_position = LevelManager.get_spawn_position(last_direction)
	print("SPELER SPAWN: Geplaatst op positie: ", global_position)
	
	# --- HIER IS DE DEFINITIEVE REDDENDE ENGEL ---
	# We zetten de snelheid direct hard op 0, zodat de oude vaart je niet door het plafond lanceert!
	velocity = Vector2.ZERO
	print("SPELER REIS: Snelheid geneutraliseerd op het startpunt.")


func _physics_process(delta: float) -> void:
	# VEILIGHEIDSCHECK VOOR BEWEGING
	if not stats:
		return
		
	# A. INITIALISATIE GRENZEN EN LOCKS (Dubbel-beveiligd tegen hoofdletters!)
	var enemies_caps = get_tree().get_nodes_in_group("Enemies")
	var enemies_small = get_tree().get_nodes_in_group("enemies")
	
	# De kamer zit op slot als er in EEN van beide groepen vijanden worden gevonden!
	var room_is_locked: bool = (enemies_caps.size() > 0) or (enemies_small.size() > 0)
	
	# DEBUG CHECK IN JE CONSOLE: Typ dit tijdelijk mee om te zien wat de computer telt!
	# print("DEBUG LOCK: Telt ", enemies_caps.size(), " Caps en ", enemies_small.size(), " Small. Locked = ", room_is_locked)
	
	var min_x = 0.0
	var max_x = 1920.0
	var min_y = 0.0
	var max_y = 1080.0
	
	var is_start_room: bool = (LevelManager.current_layer == 0)
	var is_end_room: bool = (LevelManager.current_layer == LevelManager.LAYER_WIDTHS.size() - 1)


	# 1. INPUT VERZAMELEN (WASD)
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	# --- GHOST-BLOCKING: Schakel de input-richting hard uit als je tegen een actieve muur plakt ---
	if is_start_room or is_end_room or room_is_locked:
		if global_position.x <= min_x + 32 and input_direction.x < 0:
			input_direction.x = 0.0 # Geen extra gas naar links opbouwen
		elif global_position.x >= max_x - 32 and input_direction.x > 0:
			input_direction.x = 0.0 # Geen extra gas naar rechts opbouwen
			
		if global_position.y <= min_y + 32 and input_direction.y < 0 and not is_start_room:
			input_direction.y = 0.0 # Geen extra gas naar boven opbouwen
		elif global_position.y >= max_y - 32 and input_direction.y > 0 and not is_end_room:
			input_direction.y = 0.0 # Geen extra gas naar beneden opbouwen

	# GECORRIGEERD: We gebruiken nu get_calculated_speed() voor de doelsnelheid met de gefilterde input!
	var target_velocity: Vector2 = input_direction * stats.get_calculated_speed()
	
	# 2. MOMENTUM BEREKENEN (Jullie eigen vertrouwde momentum-systeem)
	if input_direction.x != 0:
		velocity.x = move_toward(velocity.x, target_velocity.x, stats.acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, stats.friction * delta)
		
	if input_direction.y != 0:
		velocity.y = move_toward(velocity.y, target_velocity.y, stats.acceleration * delta)
	else:
		velocity.y = move_toward(velocity.y, 0, stats.friction * delta)
	
	# 3. SCHIETEN CHECKEN
	if Input.is_action_just_pressed("fire_primary"):
		fire_primary_weapon()
	
	# 4. BEWEGING EN ROTATIE UITVOEREN
	move_and_slide()
	aim_at_mouse(delta)
	
	# 5. SCHERMTRANSITIES & VIJANDEN-LOCK GRENZEN CONTROLEREN
	if is_start_room:
		# --- ZUIDPOOL LOGICA ---
		# Links, rechts en onderkant zijn ALTIJD een fysieke muur van beton
		if global_position.x < min_x + 32:
			global_position.x = min_x + 32
			velocity.x = 0.0
		elif global_position.x > max_x - 32:
			global_position.x = max_x - 32
			velocity.x = 0.0
			
		if global_position.y > max_y - 32:
			global_position.y = max_y - 32
			velocity.y = 0.0
		
		# De bovenkant controleren op basis van de vijanden-lock!
		if room_is_locked:
			# Er leven nog vijanden: de bovenkant zit potdicht!
			if global_position.y < min_y + 32:
				global_position.y = min_y + 32
				velocity.y = 0.0
		else:
			# Vijanden zijn dood: we zetten de Y-clamp open tot -100 voor de transitie omhoog
			global_position.y = max(global_position.y, -100.0)
			if global_position.y < -40.0:
				LevelManager.handle_room_transition("up", global_position.x)
				
	elif is_end_room:
		# --- NOORDPOOL LOGICA ---
		# Links, rechts en bovenkant zijn ALTIJD een fysieke muur
		if global_position.x < min_x + 32:
			global_position.x = min_x + 32
			velocity.x = 0.0
		elif global_position.x > max_x - 32:
			global_position.x = max_x - 32
			velocity.x = 0.0
			
		if global_position.y < min_y + 32:
			global_position.y = min_y + 32
			velocity.y = 0.0
		
		# De onderkant controleren op basis van de lock
		if room_is_locked:
			if global_position.y > max_y - 32:
				global_position.y = max_y - 32
				velocity.y = 0.0
		else:
			if global_position.y > max_y + 50:
				LevelManager.handle_room_transition("down", global_position.x)
				
	else:
		# --- NORMALE KAMERS (De 9 tussenringen) ---
		if room_is_locked:
			# Alle 4 de kanten zitten hermetisch op slot zolang er vijanden zijn!
			global_position.x = clamp(global_position.x, min_x + 32, max_x - 32)
			global_position.y = clamp(global_position.y, min_y + 32, max_y - 32)
		else:
			# De deuren zijn open: alle 4 de windstreken reageren op transities
			if global_position.x > max_x + 50:
				LevelManager.handle_room_transition("right", global_position.x)
			elif global_position.x < min_x - 50:
				LevelManager.handle_room_transition("left", global_position.x)
			elif global_position.y < min_y - 50:
				LevelManager.handle_room_transition("up", global_position.x)
			elif global_position.y > max_y + 50:
				LevelManager.handle_room_transition("down", global_position.x)


# --- EIGEN FUNCTIES ---

func aim_at_mouse(delta: float) -> void:
	var target_angle: float = global_position.angle_to_point(get_global_mouse_position())
	global_rotation = lerp_angle(global_rotation, target_angle, stats.rotation_speed * delta)


# Functie voor het afvuren van de Weapon Output
func fire_primary_weapon() -> void:
	# DE BLOKKADE: Als can_fire op false staat, BREEKT de functie direct af.
	# Dit stopt de dubbele kogel-spawn in ditzelfde frame onmiddellijk!
	if not can_fire:
		return
		
	if not weapon_output_scene or not active_weapon_data:
		push_error("Fout: Geen weapon_output_scene of active_weapon_data gekoppeld!")
		return
		
	# Zet de schakelaar DIRECT op false, vÓÓrdat we de kogel aanmaken!
	can_fire = false
	
	# 1. Maak EEN kogel-instantie aan
	var bullet_instance = weapon_output_scene.instantiate()
	bullet_instance.current_stats = active_weapon_data
	
	# 2. Positie en rotatie toepassen
	bullet_instance.global_position = muzzle.global_position
	bullet_instance.rotation = rotation
	get_tree().current_scene.add_child(bullet_instance)
	
	# 3. Cooldown opvragen uit de resource
	var cooldown_time: float = 0.3
	if active_weapon_data.has_method("get_calculated_fire_rate"):
		cooldown_time = active_weapon_data.get_calculated_fire_rate()
		
	# Start de cooldown timer
	await get_tree().create_timer(cooldown_time, false).timeout
	
	# Zet de poort weer open voor het VOLGENDE schot
	can_fire = true

# --- GEZONDHEID EN SCHADE SYSTEMEN ---

func take_damage(amount: int) -> void:
	if not stats: return
	
	# 1. DEBUG CHEAT CHECK: Als de F1-onsterfelijkheid aanstaat, negeren we de klap volledig!
	if Game.debug_is_invincible:
		print("DEBUG: Klap genegeerd! Player is momenteel onsterfelijk.")
		return
		
	# 2. HP VERLAGEN: Trek de schade af van de live resource variabele
	stats.current_health = max(0, stats.current_health - amount)
	print("SPELER GERAAKT! HP over: ", stats.current_health, "/", stats.health)
	
	# (Optioneel: Als jullie een rood flits-effect op de speler hebben, kun je dat hier aanroepen)
	
	# 3. GAME OVER CHECK: Wat gebeurt er als de speler sterft?
	if stats.current_health <= 0:
		_on_player_death()

func _on_player_death() -> void:
	print("DE DOOD INGEHAALD: De speler is gesneuveld!")
	
	# We resetten de debug multipliers voor de veiligheid bij een nieuwe run
	Game.debug_speed_multiplier = 1.0
	Game.debug_damage_multiplier = 1.0
	Game.debug_is_invincible = false
	
	# OPTIE: Stuur de speler direct terug naar het hoofdmenu (of herstart de scène)
	# Pas dit pad gerust aan naar jullie exacte hoofdmenu scène locatie!
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")


# --- ROGUELIKE RUN SAVE EN LOAD LOGICA ---

# Vertaalt de huidige stand van de speler naar een Dictionary voor de harde schijf (Exit Game)
func save_data() -> Dictionary:
	var player_save_dict: Dictionary = {
		"current_health": stats.current_health if stats else 100,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"velocity_x": velocity.x,
		"velocity_y": velocity.y
	}
	return player_save_dict


# Laadt de stand uit de Dictionary weer terug in de speler (Continue)
func load_data(saved_dict: Dictionary) -> void:
	if saved_dict.has("current_health") and stats:
		stats.current_health = saved_dict["current_health"]
		
	if saved_dict.has("position_x") and saved_dict.has("position_y"):
		global_position.x = saved_dict["position_x"]
		global_position.y = saved_dict["position_y"]
		
	if saved_dict.has("velocity_x") and saved_dict.has("velocity_y"):
		velocity.x = saved_dict["velocity_x"]
		velocity.y = saved_dict["velocity_y"]
		
	print("Speler-data succesvol ingeladen naar positie: ", global_position, " met momentum: ", velocity)
