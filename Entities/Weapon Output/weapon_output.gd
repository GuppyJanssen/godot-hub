extends Area2D

# --- DYNAMIC DATA INTERFACE ---
# GECORRIGEERD: We veranderen het type naar Resource zodat Godot gegarandeerd stopt met crashen!
@export var current_stats: Resource


# --- INGEBOUWDE GODOT FUNCTIES ---

func _ready() -> void:
	# Veiligheidscheck: als er per ongeluk GEEN stats zijn meegegeven, wissen we de kogel direct.
	if not current_stats:
		push_error("Fout: Kogel is gespawned zonder BulletStats resource!")
		queue_free()
		return
		
	# IN GAME VARIATIES LIVE TOEPASSEN:
	
	# 1. Grootte aanpassen (Size)
	scale = Vector2.ONE * current_stats.size_multiplier
	
	# 2. Sprite/Art live inladen
	if current_stats.texture:
		$Sprite.texture = current_stats.texture
		
	# --- AUTOMATISCH OPRUIMEN (HIERHEEN VERHUISD) ---
	# NIEUW: We maken de timer aan en vertellen hem dat hij NIET mag doorlopen tijdens pauze (false)
	await get_tree().create_timer(3.0, false).timeout

	# ...en wissen de kogel daarna uit het geheugen, zodat de game niet traag wordt.
	queue_free()


# _physics_process draait elke frame. Hier regelen we de vliegroute.
func _physics_process(delta: float) -> void:
	if not current_stats:
		return
		
	# 3. Kogel trajectory / vliegroute
	var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	
	# We verplaatsen de kogel over het scherm met de snelheid uit de meegegeven Resource
	global_position += direction * current_stats.speed * delta

# --- COLLISIE LOGICA (BOTSINGEN) ---

# Dit signaal start automatisch zodra de kogel een ander fysiek object (zoals een blokje) raakt!
# NIEUW: Schakelaar om te voorkomen dat de kogel meerdere keren per frame schade doet!
var has_hit: bool = false

func _on_body_entered(body: Node2D) -> void:
	if not current_stats or has_hit: return
	
	# REPARATIE FRIENDLY FIRE: Als het geraakte object de speler zelf is, negeren we de botsing volledig!
	if body.name == "Player" or body.is_in_group("player"):
		return
		
	# --- Vanaf hier blijft jullie bestaande schade-code exact zo staan ---
	if body.has_method("take_damage"):
		has_hit = true

		var collision_shape = find_child("CollisionShape2D", true, false)
		if collision_shape:
			collision_shape.set_deferred("disabled", true) # Veilig uitschakelen in de physics-loop
		
		# Vraag de intelligent berekende schade op uit de resource (10 of 50 met cheat)
		var final_dmg: int = 10
		if current_stats.has_method("get_calculated_damage"):
			final_dmg = current_stats.get_calculated_damage()
		elif "damage" in current_stats:
			final_dmg = roundi(current_stats.damage * Game.debug_damage_multiplier)
			
		# De kogel deelt nu EENMALIG de klap uit aan de vijand!
		body.take_damage(final_dmg)
		
		# Wis de kogel direct uit de wereld
		queue_free()
