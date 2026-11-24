extends Area2D
## Eén stukje loot op de grond: een los blokje (vierkant), een klompje (cirkel) of een steen (ster).
##
## WELKE GRONDSTOF: resource_id is een id uit de SSOT (rij met data_type loot: olrite, metal ...).
## Zie LootResources voor naam, kleur en klontergroottes.
##
## HOE HET BEWEEGT:
## 1. Eerst de splatter: het stukje vliegt weg in de richting van de kogel en remt snel af.
## 2. Ligt het bijna stil (en is loot_merge_delay voorbij), dan zoekt het het dichtstbijzijnde stukje
##    van dezelfde grondstof waar het nog NIET tegenaan ligt, en drijft daar langzaam naartoe.
##    Zo groeien kleine groepjes vanzelf aan elkaar in plaats van allemaal naar één punt te gaan.
## 3. Stukjes botsen: ze kunnen niet door elkaar heen, duwen elkaar weg en verliezen daarbij wat vaart.
## 4. Elk stukje draait een beetje om zijn buur heen (links- of rechtsom, per stukje gekozen) en
##    remt af door wrijving. Daardoor modderen ze wat tegen elkaar aan voordat ze stil liggen.
## 5. Samenklonteren pas als er binnen een cirkel (loot_merge_circle) genoeg ligt: samen minstens een
##    klompje (loot_chunk_small) of een steen (loot_chunk_large). De totale hoeveelheid blijft gelijk:
##    6 klompjes van 15 + 7 losse = 97 = één steen.
##
## INSTELLINGEN (SSOT-rij "world"; leeg = de standaard in MERGE_DEFAULTS):
##   loot_merge_delay      seconden na het neerkomen voordat een stukje gaat zoeken
##   loot_merge_speed      hoe hard een stukje naar zijn buur trekt (pixels per seconde²)
##   loot_merge_radius     hoe ver een stukje kijkt voor een buur (pixels)
##   loot_merge_circle     straal van de cirkel waarin genoeg moet liggen om samen te klonteren
##                         tot een klompje. Voor een steen geldt een grotere cirkel (STONE_CIRCLE_FACTOR keer).
##   loot_orbit_strength   hoe hard een stukje om zijn buur heen draait (pixels per seconde²)
##   loot_cluster_friction afremming tijdens het samendrijven (pixels per seconde²). Let op: het
##                         samendrijven gaat met (loot_merge_speed - loot_cluster_friction) vooruit.
##   loot_merge_wait       seconden dat een stukje stil moet liggen voordat het mag samenklonteren
##   loot_merge_duration   seconden dat het samensmelten zelf duurt (de "lavalamp": de stukjes glijden
##                         langzaam in elkaar en het nieuwe stuk groeit daarna rustig tot zijn grootte)
##
## Ontwikkelaarsnotities:
## - Geen physics-lichamen: botsen en trekken worden hier zelf uitgerekend, met een lijst buren die
##   elke NEIGHBOR_REFRESH seconden wordt bijgewerkt (niet elk frame alle loot langs).
## - Wordt de speler dichtbij genoeg, dan wint de magneet van de speler het altijd.

var resource_id: String = "olrite"
var amount: int = 1

var velocity: Vector2 = Vector2.ZERO
var loot_friction: float = 150.0

const MERGE_DEFAULTS := {
	"loot_merge_delay": 1.2,
	"loot_merge_speed": 50.0,
	"loot_merge_radius": 160.0,
	"loot_merge_circle": 40.0,
	"loot_orbit_strength": 6.0,
	"loot_cluster_friction": 45.0,
	"loot_merge_wait": 2.0,
	"loot_merge_duration": 2.5,
}
## De SSOT-rij met de magneet en het oppakken van de speler.
const PLAYER_ROW := "player_base"
const GROW_SECONDS := 0.8          # zo lang groeit een net samengesmolten stuk naar zijn echte grootte
const NEIGHBOR_REFRESH := 0.15     # seconden tussen het opnieuw zoeken van buren
const MERGE_CHECK_SECONDS := 0.25  # hoe vaak een stukje kijkt of er genoeg in zijn cirkel ligt
const SETTLED_SPEED := 25.0        # pas gaan zoeken als de splatter bijna uitgedreven is
const BASE_RADIUS := 6.0           # straal van een los blokje (zonder schaal)
const CHUNK_SCALE := 1.7           # grootte van een klompje
const STONE_SCALE := 2.6           # grootte van een steen
const BOUNCE := 0.35
## Een steen is veel groter dan een klompje, dus de cirkel voor een steen is zoveel keer groter.
const STONE_CIRCLE_FACTOR := 1.75               # hoeveel vaart er overblijft bij een botsing (0 = plof, 1 = stuiter)
const OUTLINE_COLOR := Color(0.0, 0.0, 0.0, 0.9)
const OUTLINE_WIDTH := 1.3

var _age: float = 0.0
var _neighbor_timer: float = 0.0
var _merge_timer: float = 0.0
var _neighbors: Array = []          # loot in de buurt (alle grondstoffen, voor botsen)
var _orbit_sign: float = 1.0        # draairichting om de buur: +1 of -1
var _settled: bool = false          # splatter voorbij: nu het samendrijven
var radius: float = BASE_RADIUS     # straal na schalen, voor botsen
var _settled_time: float = 0.0     # hoe lang het stukje al aan het samendrijven is
var _consumed: bool = false
# Samensmelten (lavalamp): alle stukjes van een groep glijden langzaam naar één punt.
var _merging: bool = false
var _merge_from: Vector2 = Vector2.ZERO
var _merge_center: Vector2 = Vector2.ZERO
var _merge_t: float = 0.0
var _merge_leader: Node = null
var _merge_group: Array = []       # alleen bij de leider: wie er meesmelten
var _target_scale: float = 1.0     # de echte grootte; een nieuw stuk groeit hier naartoe         # al opgegaan in een klompje of steen (wordt zo verwijderd)

@onready var color_rect: ColorRect = $ColorRect


func _ready() -> void:
	add_to_group("loot")
	add_to_group("saveable")  # dit stukje wil onthouden worden (zie game_room.gd)
	_orbit_sign = 1.0 if randf() < 0.5 else -1.0
	# Spreid het zoeken over de frames, zodat niet alle stukjes tegelijk rekenen.
	_neighbor_timer = randf() * NEIGHBOR_REFRESH
	_merge_timer = randf() * MERGE_CHECK_SECONDS
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)


# Geeft het stukje zijn vaart mee: een smalle streep in de richting van de kogel.
func launch_splatter(hit_dir: Vector2, settings: Dictionary) -> void:
	velocity = LootSplatter.random_velocity(hit_dir, settings)
	loot_friction = float(settings.get("drag", LootSplatter.DEFAULT_DRAG))
	_settled = false


# --- ONTHOUDEN: de drie functies voor de groep "saveable" ---

# Loot heeft geen vaste naam, dus elk stukje krijgt een eigen nummer.
func get_run_id() -> String:
	return "loot_" + str(get_instance_id())


# Wat dit stukje wil bewaren: soort, aantal, plek en de vaart die het nog had.
func get_run_state() -> Dictionary:
	return {
		"type": resource_id,
		"amount": amount,
		"x": global_position.x,
		"y": global_position.y,
		"vx": velocity.x,
		"vy": velocity.y,
		"friction": loot_friction,
	}


# Bij het verlaten van de kamer: spring naar de plek waar dit stukje tot stilstand was gekomen
# en bewaar het zonder vaart. Zo beweegt het niet meer als je terugkomt.
func settle_for_room_exit() -> void:
	var speed: float = velocity.length()
	if speed > 0.0 and loot_friction > 0.0:
		global_position += velocity.normalized() * (speed * speed / (2.0 * loot_friction))
	velocity = Vector2.ZERO


# Zet de bewaarde gegevens terug. Oude saves bewaarden een nummer (1 = olrite ...).
func apply_run_state(data: Dictionary) -> void:
	var id: String = LootResources.normalize(data.get("type", "olrite"))
	init_loot(id if id != "" else "olrite", int(data.get("amount", 1)))
	global_position = Vector2(float(data.get("x", 0.0)), float(data.get("y", 0.0)))
	velocity = Vector2(float(data.get("vx", 0.0)), float(data.get("vy", 0.0)))
	loot_friction = float(data.get("friction", loot_friction))


func _physics_process(delta: float) -> void:
	if not is_inside_tree() or get_tree() == null:
		return
	_age += delta

	# De magneet van de speler wint altijd. Afstanden en snelheid komen uit de SSOT-rij
	# player_base (base_pickup_radius, base_magnet_radius, base_magnet_speed), met de skills erbij.
	# Vroeger zocht dit naar velden die niet bestonden, dus golden altijd 150 / 550.
	var player = Game.active_player
	if is_instance_valid(player):
		var distance: float = global_position.distance_to(player.global_position)
		if distance <= StatCalc.player_value(PLAYER_ROW, "pickup_radius", 30.0):
			_execute_pickup(player)
			return
		if distance <= StatCalc.player_value(PLAYER_ROW, "magnet_radius", 150.0):
			var magnet_speed: float = StatCalc.player_value(PLAYER_ROW, "magnet_speed", 550.0)
			velocity = (player.global_position - global_position).normalized() * magnet_speed
			global_position += velocity * delta
			return

	# Net samengesmolten: rustig groeien tot de echte grootte.
	if scale.x < _target_scale:
		var grown: float = minf(_target_scale, scale.x + _target_scale * delta / GROW_SECONDS)
		scale = Vector2(grown, grown)

	if _merging:
		_update_melt(delta)
		return

	_neighbor_timer -= delta
	if _neighbor_timer <= 0.0:
		_neighbor_timer = NEIGHBOR_REFRESH
		_refresh_neighbors()

	if not _settled:
		# Splatter: alleen uitdrijven met de (sterke) splatter-afremming.
		velocity = velocity.move_toward(Vector2.ZERO, loot_friction * delta)
		if velocity.length() <= SETTLED_SPEED and _age >= _setting("loot_merge_delay"):
			_settled = true
	else:
		_settled_time += delta
		_pull_towards_neighbor(delta)
		velocity = velocity.move_toward(Vector2.ZERO, _setting("loot_cluster_friction") * delta)

	global_position += velocity * delta
	_resolve_collisions()

	if _settled:
		_merge_timer -= delta
		if _merge_timer <= 0.0:
			_merge_timer = MERGE_CHECK_SECONDS
			_try_merge()


# --- VORM EN KLEUR ---

func init_loot(id: String, amt: int) -> void:
	resource_id = id
	amount = amt
	# Los blokje = vierkant, klompje = cirkel (groter), steen = 5-puntige ster (nog groter).
	var size_scale: float = 1.0
	var shape_kind: String = "square"
	var sizes: Vector2i = LootResources.chunk_sizes(resource_id)
	if sizes.y > 0 and amount >= sizes.y:
		size_scale = STONE_SCALE
		shape_kind = "star"
	elif sizes.x > 0 and amount >= sizes.x:
		size_scale = CHUNK_SCALE
		shape_kind = "circle"
	scale = Vector2(size_scale, size_scale)
	_target_scale = size_scale
	radius = BASE_RADIUS * size_scale

	# De ColorRect uit de scene wordt niet meer gebruikt: alle vormen zijn een Polygon2D met rand.
	var rect = color_rect if is_instance_valid(color_rect) else get_node_or_null("ColorRect")
	if is_instance_valid(rect):
		rect.visible = false

	var points: PackedVector2Array
	match shape_kind:
		"star":
			points = _star_points(7.0, 3.0)
		"circle":
			points = _circle_points(6.0)
		_:
			points = PackedVector2Array([Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6)])

	var poly: Polygon2D = get_node_or_null("ShapePolygon") as Polygon2D
	if poly == null:
		poly = Polygon2D.new()
		poly.name = "ShapePolygon"
		add_child(poly)
	poly.polygon = points
	poly.color = LootResources.color(resource_id)

	# Donkere rand, zodat je ziet welke vorm er ligt. De rand schaalt mee met het stukje,
	# dus de breedte wordt gedeeld door de schaal (anders is de rand van een ster veel dikker).
	var outline: Line2D = get_node_or_null("Outline") as Line2D
	if outline == null:
		outline = Line2D.new()
		outline.name = "Outline"
		outline.closed = true
		outline.joint_mode = Line2D.LINE_JOINT_ROUND
		outline.antialiased = true
		add_child(outline)
	outline.points = points
	outline.default_color = OUTLINE_COLOR
	outline.width = OUTLINE_WIDTH / size_scale


static func _circle_points(r: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 16:
		points.append(Vector2.RIGHT.rotated(TAU * i / 16.0) * r)
	return points


# Een 5-puntige ster: om en om een buitenpunt en een binnenpunt, met de punt naar boven.
static func _star_points(outer: float, inner: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var r: float = outer if i % 2 == 0 else inner
		points.append(Vector2.UP.rotated(TAU * i / 10.0) * r)
	return points


# --- OPPAKKEN ---

func _on_area_entered(area: Area2D) -> void:
	if not is_instance_valid(area):
		return
	# Alleen de echte speler (groep "player"), niet alles met "player" in de naam.
	if area.is_in_group("player"):
		_execute_pickup(Game.active_player)


func _on_body_entered(body: Node2D) -> void:
	if not is_instance_valid(body):
		return
	if body.is_in_group("player"):
		_execute_pickup(body)


# De buit van deze run staat in RunState.loot (zie LootResources).
func _execute_pickup(player_node: Node2D) -> void:
	if not is_instance_valid(player_node) or is_queued_for_deletion():
		return
	RunState.add_loot(resource_id, amount)
	queue_free()


# --- SAMENDRIJVEN, BOTSEN EN SAMENKLONTEREN ---

static func _setting(setting_name: String) -> float:
	return Ssot.get_number("world", setting_name, float(MERGE_DEFAULTS[setting_name]))


## Mag dit stukje al samenklonteren? (loot_merge_wait seconden na het neerkomen.)
func ready_to_merge() -> bool:
	return can_merge() and _settled_time >= _setting("loot_merge_wait")


## Doet dit stukje mee met samendrijven en samenklonteren?
func can_merge() -> bool:
	return _settled and not _consumed and not _merging and is_inside_tree() and not is_queued_for_deletion()


# Alle loot binnen loot_merge_radius. Die lijst gebruiken we voor botsen en voor de dichtste buur.
func _refresh_neighbors() -> void:
	_neighbors.clear()
	var search: float = _setting("loot_merge_radius")
	for node in get_tree().get_nodes_in_group("loot"):
		if node == self or not (node is Area2D) or not node.has_method("can_merge"):
			continue
		if node.global_position.distance_to(global_position) <= search:
			_neighbors.append(node)


# Trek naar het dichtstbijzijnde stukje van dezelfde grondstof waar dit stukje nog niet tegenaan ligt,
# en draai er een beetje omheen.
func _pull_towards_neighbor(delta: float) -> void:
	if LootResources.chunk_sizes(resource_id) == Vector2i.ZERO:
		return  # deze grondstof klontert niet
	var target: Node2D = null
	var best: float = INF
	for other in _neighbors:
		if not is_instance_valid(other) or not other.can_merge() or other.resource_id != resource_id:
			continue
		var distance: float = other.global_position.distance_to(global_position)
		var touching: float = (radius + other.radius) * 1.15
		if distance > touching and distance < best:
			best = distance
			target = other
	if target == null:
		return
	var direction: Vector2 = (target.global_position - global_position).normalized()
	velocity += direction * _setting("loot_merge_speed") * delta
	velocity += direction.orthogonal() * _orbit_sign * _setting("loot_orbit_strength") * delta


# Stukjes kunnen niet door elkaar: duw ze uit elkaar en haal wat vaart weg (een zachte botsing).
# Elk stukje duwt alleen zichzelf de helft weg; de ander doet in zijn eigen beurt de andere helft.
func _resolve_collisions() -> void:
	for other in _neighbors:
		if not is_instance_valid(other) or other.is_queued_for_deletion() or other._merging:
			continue
		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()
		var min_distance: float = radius + other.radius
		if distance >= min_distance:
			continue
		var normal: Vector2 = offset / distance if distance > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
		global_position += normal * (min_distance - distance) * 0.5
		# Alleen de vaart richting de ander wordt (grotendeels) weggenomen: dat voelt als stoten.
		var into: float = velocity.dot(-normal)
		if into > 0.0:
			velocity += normal * into * (1.0 + BOUNCE) * 0.5


# Ligt er rond dit stukje genoeg van deze grondstof voor een steen (binnen de grote cirkel) of een
# klompje (binnen loot_merge_circle)? Dan worden de dichtstbijzijnde stukjes samengevoegd, tot er
# genoeg is. Elk stukje mag dit doen; stukjes die al opgaan in een samenvoeging worden overgeslagen.
func _try_merge() -> void:
	if not ready_to_merge():
		return
	var sizes: Vector2i = LootResources.chunk_sizes(resource_id)
	if sizes.x <= 0 and sizes.y <= 0:
		return
	var circle: float = _setting("loot_merge_circle")
	# Kandidaten: dit stukje en dezelfde grondstof in de buurt, dichtstbij eerst.
	var candidates: Array = [self]
	for other in _neighbors:
		if is_instance_valid(other) and other.ready_to_merge() and other.resource_id == resource_id:
			candidates.append(other)
	candidates.sort_custom(func(a, b): return a.global_position.distance_squared_to(global_position) < b.global_position.distance_squared_to(global_position))

	# Eerst een steen proberen, dan een klompje.
	for step in [[sizes.y, circle * STONE_CIRCLE_FACTOR], [sizes.x, circle]]:
		var target: int = step[0]
		var reach: float = step[1]
		if target <= 0:
			continue
		var group: Array = []
		var total: int = 0
		for piece in candidates:
			if piece.global_position.distance_to(global_position) > reach:
				break
			# Een stuk dat al zo groot is als het doel doet niet mee (anders "voegt" een steen zichzelf samen).
			if piece.amount >= target:
				continue
			group.append(piece)
			total += piece.amount
			if total >= target:
				break
		if total < target or group.size() < 2:
			continue
		var stones: int = floori(float(total) / sizes.y) if sizes.y > 0 else 0
		var rest: int = total - stones * sizes.y
		var chunks: int = floori(float(rest) / sizes.x) if sizes.x > 0 else 0
		var singles: int = rest - chunks * sizes.x
		if stones + chunks + singles >= group.size():
			continue
		var center: Vector2 = Vector2.ZERO
		for piece in group:
			center += piece.global_position
		center /= group.size()
		_start_melt(group, center)
		return


# Begint het samensmelten: alle stukjes glijden in loot_merge_duration seconden naar 'center'.
# Dit stukje is de leider en zet ze aan het eind om in het nieuwe stuk.
func _start_melt(group: Array, center: Vector2) -> void:
	_merge_group = group
	for piece in group:
		piece._merging = true
		piece._merge_from = piece.global_position
		piece._merge_center = center
		piece._merge_t = 0.0
		piece._merge_leader = self
		piece.velocity = Vector2.ZERO


# Eén stap van het samensmelten. Rustig op gang, rustig aankomen (smoothstep), zoals een lavalamp.
func _update_melt(delta: float) -> void:
	var duration: float = maxf(0.05, _setting("loot_merge_duration"))
	_merge_t += delta
	global_position = _merge_from.lerp(_merge_center, smoothstep(0.0, 1.0, _merge_t / duration))
	if _merge_leader == self:
		if _merge_t >= duration:
			_finish_melt()
	elif _merge_t > duration + 1.0:
		# De leider is weg (bijvoorbeeld opgepakt): gewoon weer los verder.
		_merging = false
		_merge_leader = null


# Klaar met smelten: tel wat er nog is (iets kan onderweg opgepakt zijn) en maak het nieuwe stuk.
func _finish_melt() -> void:
	var sizes: Vector2i = LootResources.chunk_sizes(resource_id)
	var group: Array = []
	var total: int = 0
	for piece in _merge_group:
		if is_instance_valid(piece) and not piece.is_queued_for_deletion() and piece._merging and piece._merge_leader == self:
			group.append(piece)
			total += piece.amount
	_merge_group = []
	var stones: int = floori(float(total) / sizes.y) if sizes.y > 0 else 0
	var rest: int = total - stones * sizes.y
	var chunks: int = floori(float(rest) / sizes.x) if sizes.x > 0 else 0
	var singles: int = rest - chunks * sizes.x
	if group.size() < 2 or stones + chunks + singles >= group.size():
		for piece in group:
			piece._merging = false
			piece._merge_leader = null
		return
	_recompose(group, _merge_center, stones, chunks, singles, sizes)


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
		piece._consumed = true
		piece.queue_free()
	for piece_amount in pieces:
		var loot: Node = scene.instantiate()
		loot.init_loot(resource_id, piece_amount)
		# Grote stukken in het midden, losse blokjes er een beetje omheen. De botsing duwt ze daarna
		# vanzelf netjes uit elkaar.
		var spread: float = 3.0 if piece_amount > 1 else 14.0
		loot.global_position = center + Vector2(randf_range(-spread, spread), randf_range(-spread, spread))
		loot._settled = true
		loot._age = _setting("loot_merge_delay")
		loot._settled_time = 0.0
		# Begint klein en groeit rustig tot zijn echte grootte (zie GROW_SECONDS).
		loot.scale = Vector2(loot._target_scale, loot._target_scale) * 0.55
		parent.call_deferred("add_child", loot)
	print("LOOT: ", group.size(), " stukjes ", resource_id, " samengevoegd tot ", stones, " steen, ", chunks, " klompje(s) en ", singles, " los.")
