extends Area2D
# BEDIENING: Kogel/Projectiel (Volledig F1 Dashboard-Bewust!)

@export var speed: float = 700.0
@export var damage: int = 10


func _ready() -> void:
	add_to_group("projectiles")
	
	var size_mult = Game.debug_bullet_size_multiplier if Game.debug_bullet_size_multiplier else 1.0
	var speed_mult = Game.debug_bullet_speed_multiplier if Game.debug_bullet_speed_multiplier else 1.0
	
	scale = Vector2(size_mult, size_mult)
	speed *= speed_mult
	
	if Game.debug_damage_multiplier:
		damage *= int(Game.debug_damage_multiplier)


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null or get_tree().paused: return
	
	# GECORRIGEERD: Gebruikt de betrouwbare transform-richting van Godot 4.7
	# Dit voorkomt dat de kogel bij een verkeerde rotatie-matrix naar (0,0) schiet!
	global_position += transform.x * speed * delta


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if body.is_in_group("targets") or body.is_in_group("Enemies") or body.is_in_group("enemies"):
		if body.has_method("take_damage"):
			body.take_damage(damage)
		queue_free()
