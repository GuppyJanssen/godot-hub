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


# Voeg deze variabele toe aan de top van je kogelscript:
var traveled_distance: float = 0.0

func _physics_process(delta: float) -> void:
	# Veiligheidscheck: als er geen stats zijn, kunnen we niet bewegen of bereik checken
	if not current_stats:
		return
		
	# 1. BEREKEN DE BEWEGING (We halen speed nu VEILIG uit current_stats!)
	var move_amount = current_stats.speed * delta
	
	# 2. JULLIE EIGEN VLIEGROUTE (Netjes gecombineerd met de move_amount)
	var direction: Vector2 = Vector2.RIGHT.rotated(rotation)
	global_position += direction * move_amount
	
	# 3. WEAPON RANGE CHECK
	traveled_distance += move_amount
	if "weapon_range" in current_stats:
		if traveled_distance >= current_stats.weapon_range:
			# Boem, maximale range bereikt! Kogel lost op in het niets.
			queue_free()


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
			
		# Bereken de richting waarin de kogel reist
		var hit_direction: Vector2 = Vector2.RIGHT.rotated(rotation)
		
		# We geven de richting mee als nieuw, extra argument aan de vijand!
		body.take_damage(final_dmg, false, hit_direction)

		
		# Wis de kogel direct uit de wereld
		queue_free()
