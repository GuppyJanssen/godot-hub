extends CharacterBody2D

class_name Player 

# --- DATA RESOURCES ---
@export var stats: PlayerStats

# De projectiel-scène (voorheen bullet_scene)
@export var weapon_output_scene: PackedScene

# De actieve data-blauwdruk van het wapen (Resource)
@export var active_weapon_data: WeaponOutputStats


# --- NODES ---
@onready var muzzle: Marker2D = $Muzzle_1


# --- RUN VOORTGANG (ROGUELIKE) ---
# Dit houdt de buit van de huidige run bij. Begint elke run netjes op 0.
var run_xp_earned: int = 0
var run_currency_earned: int = 0


# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	# Dwing alle menu-knoppen om hun focus direct los te laten bij de start
	get_viewport().gui_release_focus()
	
	if not stats:
		push_error("Fout: player_data.tres is niet gekoppeld!")
		
	# TIJDELIJKE TEST-SIMULATIE: 
	# We starten fictief met wat buit om de wiskunde op de harde schijf te kunnen testen.
	run_xp_earned = 15
	run_currency_earned = 50


func _physics_process(delta: float) -> void:
	# VEILIGHEIDSCHECK VOOR BEWEGING
	if not stats:
		return
		
	# 1. INPUT VERZAMELEN (WASD)
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var target_velocity: Vector2 = input_direction * stats.speed
	
	# 2. MOMENTUM BEREKENEN (ONTKOPPELDE ASSEN)
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
		fire_weapon()
	
	# 4. BEWEGING EN ROTATIE UITVOEREN
	move_and_slide()
	aim_at_mouse(delta)


# --- EIGEN FUNCTIES ---

func aim_at_mouse(delta: float) -> void:
	var target_angle: float = global_position.angle_to_point(get_global_mouse_position())
	global_rotation = lerp_angle(global_rotation, target_angle, stats.rotation_speed * delta)


# Functie voor het afvuren van de Weapon Output
func fire_weapon() -> void:
	if not weapon_output_scene:
		push_error("Fout: Geen weapon_output_scene gekoppeld aan de Player node!")
		return
	if not active_weapon_data:
		push_error("Fout: Geen active_weapon_data gekoppeld aan de Player node!")
		return
		
	var new_projectile = weapon_output_scene.instantiate()
	new_projectile.current_stats = active_weapon_data
	get_tree().current_scene.add_child(new_projectile)
	
	new_projectile.global_position = muzzle.global_position
	new_projectile.global_rotation = global_rotation


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
