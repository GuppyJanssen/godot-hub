extends Area2D
# BEDIENING: Loot Drop (Volledig Gecorrigeerd & SSoT)

var currency_type: int = 1 
var amount: int = 1

var velocity: Vector2 = Vector2.ZERO
var loot_friction: float = 150.0 

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	add_to_group("loot")


func set_impact_direction(hit_dir: Vector2) -> void:
	if hit_dir == Vector2.ZERO:
		var random_angle = randf_range(0, 2 * PI)
		velocity = Vector2(cos(random_angle), sin(random_angle)) * randf_range(100.0, 250.0)
		return
		
	var spread_angle = randf_range(-deg_to_rad(25), deg_to_rad(25))
	var final_dir = hit_dir.rotated(spread_angle)
	var random_speed = randf_range(100.0, 200.0)
	velocity = final_dir * random_speed


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return
	if velocity.length() > 0:
		global_position += velocity * delta
		velocity = velocity.move_toward(Vector2.ZERO, loot_friction * delta)


func init_loot(type: int, amt: int) -> void:
	currency_type = type
	amount = amt
	
	# PREVENTIEVE LOKALE NODELINK GUARD
	var active_rect = color_rect if is_instance_valid(color_rect) else (get_node("ColorRect") if has_node("ColorRect") else null)
	if is_instance_valid(active_rect):
		match currency_type:
			1: active_rect.color = Color(0.0, 0.564, 0.275, 1.0)  # Olrite = Groen
			2: active_rect.color = Color(0.556, 0.556, 0.556, 1.0) # Metal = Grijs
			3: active_rect.color = Color(0.634, 0.022, 0.575, 1.0) # Keepium = Paars
			4: active_rect.color = Color(0.1, 0.5, 0.9, 1.0)       # Element 1 = Blauw
			5: active_rect.color = Color(1.0, 0.85, 0.0, 1.0)      # Element 2 = Geel
			6: active_rect.color = Color(0.863, 0.0, 0.0, 1.0)     # Element 3 = Rood
