extends Area2D
# BEDIENING: Weapon / Projectile (Luistert live naar de Master-CSV!)

# --- UNIVERSELE DATA BINDER ---
var current_stats: WeaponOutputData

# --- KOGEL VARIATIES (Lokale runtime variabelen uit de SSoT Spreadsheet) ---
var speed: float = 700.0
var damage: int = 10
var weapon_range: float = 600.0
var size_multiplier: float = 1.0

var traveled_distance: float = 0.0


func _ready() -> void:
	add_to_group("projectiles")
	
	# We zoeken de live speler om zijn actuele runtime (F1 of Skill Tree) data te pikken!
	var player = get_tree().current_scene.find_child("Player", true, false)
	
	if player and not player.current_weapon_stats.is_empty():
		var w_csv = player.current_weapon_stats
		
		# De kogel haalt zijn gedrag nu WATERDICHT uit de Google Spreadsheet!
		speed = w_csv.get("speed", 700.0)
		damage = int(w_csv.get("damage", 10))
		weapon_range = w_csv.get("weapon_range", 600.0)
		size_multiplier = w_csv.get("size_multiplier", 1.0)
		
		# Pas de fysieke grootte aan
		scale = Vector2(size_multiplier, size_multiplier)
		
		# Zoek de sprite node flexibel op
		var sprite_node = find_child("*Sprite*", true, false) as Sprite2D
		if sprite_node and current_stats and current_stats.texture:
			sprite_node.texture = current_stats.texture
			
		print("PROJECTIEL SPAWN: Gekoppeld aan CSV. Snelheid is: ", speed)
	else:
		# Veilige back-up waarden
		speed = 700.0
		damage = 10
		weapon_range = 600.0
		scale = Vector2.ONE
		
	# Automatisch opruimen na 3 seconden om traagheid te voorkomen
	await get_tree().create_timer(3.0, false).timeout
	queue_free()


func _physics_process(delta: float) -> void:
	# BEREKEN DE VLIEGROUTE: Vliegt ALTIJD loepzuiver vooruit in de hoek van de Muzzle!
	# Als jullie via de Skill Tree de muzzle een hoek meegeven, reist deze rotatie hier direct mee!
	var move_amount = speed * delta
	position += Vector2.RIGHT.rotated(rotation) * move_amount
	
	# Bereik-controle: ruim de kogel netjes op als zijn range op is
	traveled_distance += move_amount
	if traveled_distance >= weapon_range:
		queue_free()


# --- BOTSINGS DETECTIE (Gekoppeld via de Editor of Node-tab) ---
func _on_body_entered(body: Node2D) -> void:
	# Veiligheid: Schiet nooit jezelf neer!
	if body.is_in_group("Player") or body.name == "Player":
		return
		
	if body.is_in_group("targets") or body.has_method("take_damage"):
		var final_damage = int(damage * Game.debug_damage_multiplier)
		
		if body.has_method("take_damage"):
			var impact_direction = Vector2.RIGHT.rotated(rotation).normalized()
			# We sturen de schade, de flits-bool en de impact-richting mee naar de vijand!
			body.take_damage(final_damage, true, impact_direction)
			print("PROJECTIEL IMPACT: ", body.name, " geklapt! Schade: ", final_damage)
			
		queue_free()
