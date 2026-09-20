extends Area2D

var currency_type: int = 1 
var amount: int = 1

var velocity: Vector2 = Vector2.ZERO
var loot_friction: float = 150.0 

@onready var color_rect: ColorRect = $ColorRect

func _ready() -> void:
	add_to_group("loot")
	
	# Kleurinrichting (Blijft exact jullie gekozen palet)
	match currency_type:
		1: color_rect.color = Color(0.0, 0.564, 0.275, 1.0)  # Olrite = Groen
		2: color_rect.color = Color(0.556, 0.556, 0.556, 1.0) # Metal = Grijs
		3: color_rect.color = Color(0.634, 0.022, 0.575, 1.0) # Keepium = Paars
		4: color_rect.color = Color(0.1, 0.5, 0.9, 1.0)       # Element 1 = Blauw
		5: color_rect.color = Color(1.0, 0.85, 0.0, 1.0)      # Element 2 = Geel
		6: color_rect.color = Color(0.863, 0.0, 0.0, 1.0)     # Element 3 = Rood


# NIEUW: Deze functie berekent de vloeibare impact-kegel op basis van de kogelinslag!
func set_impact_direction(hit_dir: Vector2) -> void:
	# Als er geen richting is meegegeven, kiezen we als back-up 360 graden willekeur
	if hit_dir == Vector2.ZERO:
		var random_angle = randf_range(0, 2 * PI)
		velocity = Vector2(cos(random_angle), sin(random_angle)) * randf_range(100.0, 250.0)
		return
		
	# BINGO: We pakken de hoek van de kogel en gooien er een kleine willekeurige afwijking overheen (-25 tot +25 graden)
	var spread_angle = randf_range(-deg_to_rad(25), deg_to_rad(25))
	var final_dir = hit_dir.rotated(spread_angle)
	
	# Bepaal de snelheid van de explosie-glij (lekker krachtig)
	var random_speed = randf_range(100.0, 200.0)
	velocity = final_dir * random_speed


func _physics_process(delta: float) -> void:
	if velocity.length() > 0:
		global_position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, loot_friction * delta)


func init_loot(type: int, amt: int) -> void:
	currency_type = type
	amount = amt
