extends CharacterBody2D

class_name Player 

# --- DATA RESOURCES ---
@export var stats: PlayerStats

# NIEUW: Hier slepen we dadelijk de basale 'bullet.tscn' scène in.
@export var bullet_scene: PackedScene

# NIEUW: De actieve kogel-data (het paspoort) die de speler op dit moment gebruikt.
# Dit kan later via menu's of power-ups live worden vervangen door andere .tres bestanden!
@export var active_bullet_data: BulletStats

# --- NODES ---
# We zoeken de Muzzle marker zodra de game start
@onready var muzzle: Marker2D = $Muzzle_1


# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	if not stats:
		push_error("Fout: player_data.tres is niet gekoppeld!")


func _physics_process(delta: float) -> void:
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
	
	# 3. SCHIETEN CHECKEN (NIEUW)
	#is_action_just_pressed() registreert exact één klik, hoe lang je de muisknop ook ingedrukt houdt.
	if Input.is_action_just_pressed("fire_primary"):
		shoot_bullet()
	
	# 4. BEWEGING EN ROTATIE UITVOEREN
	move_and_slide()
	aim_at_mouse(delta)


# --- EIGEN FUNCTIES ---

func aim_at_mouse(delta: float) -> void:
	var target_angle: float = global_position.angle_to_point(get_global_mouse_position())
	global_rotation = lerp_angle(global_rotation, target_angle, stats.rotation_speed * delta)


func shoot_bullet() -> void:
	# Veiligheidschecks om crashes te voorkomen bij ontbrekende links
	if not bullet_scene:
		push_error("Fout: Geen bullet_scene (bullet.tscn) gekoppeld aan de Player node!")
		return
	if not active_bullet_data:
		push_error("Fout: Geen active_bullet_data (Bullet_Data.tres) gekoppeld aan de Player node!")
		return
		
	# 1. KOGEL INITIALISEREN
	# Maak de actieve kopie van de kogel aan in het geheugen van de computer.
	var new_bullet = bullet_scene.instantiate()
	
	# DATA-DRIVEN PASPOORT INJECTIE:
	# We geven de kogel JULLIE specifieke 'Bullet_Data.tres' mee VÓÓRDAT hij in de wereld wordt gezet.
	new_bullet.current_stats = active_bullet_data
	
	# 2. IN DE WERELD PLAATSEN
	# get_tree().current_scene pakt automatisch jullie actieve Spawn_Area wereldscène erbij.
	get_tree().current_scene.add_child(new_bullet)
	
	# 3. POSITIE EN ROTATIE DOORGEVEN
	# Zet de kogel op de positie van het geweer (de Muzzle)
	new_bullet.global_position = muzzle.global_position
	# Geef de kogel de exacte kijkrichting van de speler mee, zodat hij de juiste kant op schiet!
	new_bullet.global_rotation = global_rotation
