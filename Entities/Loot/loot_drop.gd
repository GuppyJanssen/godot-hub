extends Area2D
# BEDIENING: Loot Drop (100% SSoT-Geconsolideerd voor alle 6 de grondstoffen!)

var currency_type: int = 1 
var amount: int = 1

var velocity: Vector2 = Vector2.ZERO
var loot_friction: float = 150.0 

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	add_to_group("loot")
	add_to_group("saveable")  # dit blokje wil onthouden worden (zie game_room.gd)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


# Geeft het blokje zijn vaart mee: een smalle streep in de richting van de kogel.
func launch_splatter(hit_dir: Vector2, settings: Dictionary) -> void:
	velocity = LootSplatter.random_velocity(hit_dir, settings)
	loot_friction = float(settings.get("drag", LootSplatter.DEFAULT_DRAG))


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# Loot heeft geen vaste naam, dus elk blokje krijgt een eigen nummer.
func get_run_id() -> String:
	return "loot_" + str(get_instance_id())


# Wat dit blokje wil bewaren: soort, aantal, plek en de vaart die het nog had.
func get_run_state() -> Dictionary:
	return {
		"type": currency_type,
		"amount": amount,
		"x": global_position.x,
		"y": global_position.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"friction": loot_friction,
	}


# Zet de bewaarde gegevens terug.
func apply_run_state(data: Dictionary) -> void:
	init_loot(int(data.get("type", 1)), int(data.get("amount", 1)))
	global_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	velocity = Vector2(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)))
	loot_friction = float(data.get("friction", loot_friction))


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null: return
	
	var player = Game.active_player
	var pulling_to_player: bool = false
	
	if is_instance_valid(player):
		var live_magnet_range: float = 150.0
		if player.stats and "loot_magnet_range" in player.stats:
			live_magnet_range = float(player.stats.loot_magnet_range)
			
		var distance_to_player = global_position.distance_to(player.global_position)
		
		if distance_to_player <= live_magnet_range:
			pulling_to_player = true
			var direction_to_player = (player.global_position - global_position).normalized()
			
			var live_magnet_speed: float = 550.0
			if player.stats and "loot_magnet_speed" in player.stats:
				live_magnet_speed = float(player.stats.loot_magnet_speed)
				
			velocity = direction_to_player * live_magnet_speed
			global_position += velocity * delta
			
	if not pulling_to_player:
		if velocity.length() > 0:
			global_position += velocity * delta
			velocity = velocity.move_toward(Vector2.ZERO, loot_friction * delta)


func init_loot(type: int, amt: int) -> void:
	currency_type = type
	amount = amt
	
	var active_rect = color_rect if is_instance_valid(color_rect) else (get_node("ColorRect") if has_node("ColorRect") else null)
	if is_instance_valid(active_rect):
		match currency_type:
			1: active_rect.color = Color(0.0, 0.564, 0.275, 1.0)  # Olrite
			2: active_rect.color = Color(0.556, 0.556, 0.556, 1.0) # Metal
			3: active_rect.color = Color(0.634, 0.022, 0.575, 1.0) # Keepium
			4: active_rect.color = Color(0.1, 0.5, 0.9, 1.0)       # Element 1
			5: active_rect.color = Color(1.0, 0.85, 0.0, 1.0)      # Element 2
			6: active_rect.color = Color(0.863, 0.0, 0.0, 1.0)     # Element 3


func _on_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area): return
	if area.is_in_group("player") or "player" in area.name.to_lower() or area.get_parent().is_in_group("player") or "player" in area.get_parent().name.to_lower():
		var target_player = area.get_parent() if "player" in area.get_parent().name.to_lower() else Game.active_player
		_execute_pickup(target_player)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body): return
	if body.is_in_group("player") or "player" in body.name.to_lower():
		_execute_pickup(body)


# --- GECORRIGEERD: Schrijft de winst direct en kogelvrij weg naar de Global Hub ---
func _execute_pickup(player_node: Node2D) -> void:
	if not is_instance_valid(player_node): return
	
	print("LOOT: Speler raapt ", amount, " eenheden van type ", currency_type, " succesvol op!")
	
	# SSoT LOCK: We slaan de winst-tellers onvoorwaardelijk op in de Autoload Hub metadata.
	# Hierdoor hoeft Player.gd de variabelen zelf niet te bezitten, wat crashes voorkomt!
	if is_instance_valid(Game):
		var current_olrite = int(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else 0
		var current_metal  = int(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else 0
		var current_keep   = int(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else 0
		var current_elem1  = int(Game.get_meta("run_loot_element1")) if Game.has_meta("run_loot_element1") else 0
		var current_elem2  = int(Game.get_meta("run_loot_element2")) if Game.has_meta("run_loot_element2") else 0
		var current_elem3  = int(Game.get_meta("run_loot_element3")) if Game.has_meta("run_loot_element3") else 0
		
		match currency_type:
			1: Game.set_meta("run_loot_olrite", current_olrite + amount)
			2: Game.set_meta("run_loot_metal", current_metal + amount)
			3: Game.set_meta("run_loot_keepium", current_keep + amount)
			4: Game.set_meta("run_loot_element1", current_elem1 + amount)
			5: Game.set_meta("run_loot_element2", current_elem2 + amount)
			6: Game.set_meta("run_loot_element3", current_elem3 + amount)
	
	# RunState telt mee, naast de bestaande telling in Game.
	var names: Array = ["", "olrite", "metal", "keepium", "element1", "element2", "element3"]
	RunState.add_loot(names[currency_type], amount)
	
	# Wis het opgezogen kristal vloeibaar uit de arena
	queue_free()
