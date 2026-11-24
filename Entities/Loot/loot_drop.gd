extends Area2D
# BEDIENING: Loot Drop (100% SSoT-Geconsolideerd voor alle 6 de grondstoffen!)

var currency_type: int = 1 
var amount: int = 1

var velocity: Vector2 = Vector2.ZERO
var loot_friction: float = 150.0 

# --- SAMENKLONTEREN ---
# Losse blokjes van dezelfde grondstof die bij elkaar liggen, drijven na een korte pauze langzaam
# naar elkaar toe en worden samen een klompje (bijvoorbeeld 15 Olrite) of een steen (97 Olrite).
# Wat overblijft, blijft los liggen: 20 blokjes = 1 klompje van 15 + 5 losse.
# Per grondstof in de SSOT (rij olrite, metal ...): loot_chunk_small en loot_chunk_large.
# Leeg = deze grondstof klontert niet. Algemene instellingen op de rij "world" (leeg = standaard):
# loot_merge_delay, loot_merge_speed, loot_merge_radius.
const CURRENCY_ROWS: Array = ["", "olrite", "metal", "keepium", "element_1", "element_2", "element_3"]
const MERGE_DEFAULTS := {"loot_merge_delay": 0.4, "loot_merge_speed": 35.0, "loot_merge_radius": 160.0}
const MERGE_CHECK_SECONDS := 0.2   # hoe vaak een blokje kijkt of er iets samen te voegen valt
const MERGE_CLOSE_ENOUGH := 14.0   # zo dicht bij het midden telt als "aangekomen"
const SETTLED_SPEED := 25.0        # pas samentrekken als de splatter bijna uitgedreven is
const CHUNK_SCALE := 1.7           # grootte van een klompje
const STONE_SCALE := 2.6           # grootte van een steen

var _age: float = 0.0
var _merge_timer: float = 0.0
var merge_target: Vector2 = Vector2.ZERO
var merging: bool = false

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


# Bij het verlaten van de kamer: spring naar de plek waar dit blokje tot stilstand was gekomen
# en bewaar het zonder vaart. Zo beweegt het niet meer als je terugkomt. (Bij "terug naar
# hoofdmenu" wordt dit niet aangeroepen; dan houdt het blokje zijn vaart, zoals het hoort.)
func settle_for_room_exit() -> void:
	var speed: float = velocity.length()
	if speed > 0.0 and loot_friction > 0.0:
		global_position += velocity.normalized() * (speed * speed / (2.0 * loot_friction))
	velocity = Vector2.ZERO
	merging = false


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
		_update_merge(delta)
	else:
		merging = false


func init_loot(type: int, amt: int) -> void:
	currency_type = type
	amount = amt
	# Vorm en grootte: los blokje = vierkantje, klompje = cirkel (groter), steen = 5-puntige ster
	# (nog groter). De botsing groeit mee met de schaal.
	var size_scale: float = 1.0
	var shape_kind: String = "square"
	var sizes: Vector2i = _chunk_sizes()
	if sizes.y > 0 and amount >= sizes.y:
		size_scale = STONE_SCALE
		shape_kind = "star"
	elif sizes.x > 0 and amount >= sizes.x:
		size_scale = CHUNK_SCALE
		shape_kind = "circle"
	scale = Vector2(size_scale, size_scale)
	
	var color: Color = _currency_color()
	var active_rect = color_rect if is_instance_valid(color_rect) else (get_node("ColorRect") if has_node("ColorRect") else null)
	if is_instance_valid(active_rect):
		active_rect.color = color
		active_rect.visible = shape_kind == "square"
	
	# Cirkel en ster zijn een Polygon2D die we hier zelf maken.
	var poly: Polygon2D = get_node_or_null("ShapePolygon") as Polygon2D
	if shape_kind == "square":
		if poly != null:
			poly.visible = false
		return
	if poly == null:
		poly = Polygon2D.new()
		poly.name = "ShapePolygon"
		add_child(poly)
	poly.visible = true
	poly.color = color
	poly.polygon = _star_points(7.0, 3.0) if shape_kind == "star" else _circle_points(6.0)


func _currency_color() -> Color:
	match currency_type:
		1: return Color(0.0, 0.564, 0.275, 1.0)  # Olrite
		2: return Color(0.556, 0.556, 0.556, 1.0) # Metal
		3: return Color(0.634, 0.022, 0.575, 1.0) # Keepium
		4: return Color(0.1, 0.5, 0.9, 1.0)       # Element 1
		5: return Color(1.0, 0.85, 0.0, 1.0)      # Element 2
		6: return Color(0.863, 0.0, 0.0, 1.0)     # Element 3
	return Color.WHITE


static func _circle_points(radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 16:
		points.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * radius)
	return points


# Een 5-puntige ster: om en om een buitenpunt en een binnenpunt, met de punt naar boven.
static func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var radius: float = outer if i % 2 == 0 else inner
		points.append(Vector2.UP.rotated(TAU * i / 10.0) * radius)
	return points


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


# --- SAMENKLONTEREN ---

# Klompje- en steengrootte voor deze grondstof (0 = niet).
func _chunk_sizes() -> Vector2i:
	if currency_type < 1 or currency_type >= CURRENCY_ROWS.size():
		return Vector2i.ZERO
	var row: String = CURRENCY_ROWS[currency_type]
	return Vector2i(Ssot.get_int(row, "loot_chunk_small", 0), Ssot.get_int(row, "loot_chunk_large", 0))


static func _merge_setting(setting_name: String) -> float:
	return Ssot.get_number("world", setting_name, float(MERGE_DEFAULTS[setting_name]))


# Mag dit blokje meedoen met samenklonteren? (Pauze voorbij en de splatter bijna uitgedreven.)
func can_merge() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and _age >= _merge_setting("loot_merge_delay") and velocity.length() <= SETTLED_SPEED


func _update_merge(delta: float) -> void:
	_age += delta
	# Langzaam naar het midden van de groep drijven (het "ruimte"-gevoel).
	if merging:
		global_position = global_position.move_toward(merge_target, _merge_setting("loot_merge_speed") * delta)
	_merge_timer -= delta
	if _merge_timer > 0.0:
		return
	_merge_timer = MERGE_CHECK_SECONDS
	if not can_merge():
		return
	var sizes: Vector2i = _chunk_sizes()
	if sizes.x <= 0 and sizes.y <= 0:
		return

	# De groep: alle blokjes van dezelfde grondstof die via elkaar verbonden zijn (elk blokje ligt
	# binnen de straal van minstens één ander blokje in de groep). Zo telt een hele hoop mee, ook
	# als die breder is dan de straal. Alleen het blokje met het laagste nummer in de groep
	# (de "aanvoerder") regelt het samenvoegen, zodat het één keer gebeurt.
	var radius: float = _merge_setting("loot_merge_radius")
	var candidates: Array = []
	for node in get_tree().get_nodes_in_group("loot"):
		if node == self or not node.has_method("can_merge"):
			continue
		if node.currency_type != currency_type or not node.can_merge():
			continue
		candidates.append(node)
	var group: Array = [self]
	var index: int = 0
	while index < group.size():
		var current: Node2D = group[index]
		index += 1
		for k in range(candidates.size() - 1, -1, -1):
			var other: Node2D = candidates[k]
			if other.global_position.distance_to(current.global_position) <= radius:
				if other.get_instance_id() < get_instance_id():
					return  # een ander blokje in deze groep is de aanvoerder
				group.append(other)
				candidates.remove_at(k)

	var total: int = 0
	var center: Vector2 = Vector2.ZERO
	for piece in group:
		total += piece.amount
		center += piece.global_position
	center /= group.size()

	# Hoe ziet de groep er na het samenvoegen uit? Zoveel mogelijk stenen, dan klompjes, de rest los.
	var stones: int = floori(float(total) / sizes.y) if sizes.y > 0 else 0
	var rest: int = total - stones * sizes.y
	var chunks: int = floori(float(rest) / sizes.x) if sizes.x > 0 else 0
	var singles: int = rest - chunks * sizes.x
	if stones + chunks == 0 or group.size() <= stones + chunks + singles:
		for piece in group:
			piece.merging = false
		return  # niets samen te voegen, of al zo samengevoegd als het kan

	# Iedereen drijft naar het midden. Zijn ze er allemaal, dan wordt de groep omgezet.
	var arrived: bool = true
	for piece in group:
		piece.merge_target = center
		piece.merging = true
		if piece.global_position.distance_to(center) > MERGE_CLOSE_ENOUGH:
			arrived = false
	if arrived:
		_recompose(group, center, stones, chunks, singles, sizes)


# Vervangt de groep door stenen, klompjes en losse blokjes op dezelfde plek.
func _recompose(group: Array, center: Vector2, stones: int, chunks: int, singles: int, sizes: Vector2i) -> void:
	var scene: PackedScene = load(scene_file_path)
	var parent: Node = get_parent()
	if scene == null or parent == null:
		return
	var pieces: Array = []
	for i in stones:
		pieces.append(sizes.y)
	for i in chunks:
		pieces.append(sizes.x)
	for i in singles:
		pieces.append(1)
	for piece in group:
		piece.queue_free()
	for piece_amount in pieces:
		var loot: Node = scene.instantiate()
		loot.init_loot(currency_type, piece_amount)
		# Grote stukken in het midden, losse blokjes er een beetje omheen.
		var spread: float = 4.0 if piece_amount > 1 else 18.0
		loot.global_position = center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		parent.call_deferred("add_child", loot)
	print("LOOT: ", group.size(), " stukjes samengevoegd tot ", stones, " steen, ", chunks, " klompje(s) en ", singles, " los.")
