class_name LootSplatter
## LootSplatter – laat loot als een spat uit een gedode vijand vliegen.
##
## Geen autoload nodig.
##
## Het effect: een uitgesmeerde streep in de richting van de kogel, zoals een waterballon
## met voorwaarts momentum. Dat komt door: een smalle kegel, een groot verschil in snelheid
## tussen de stukjes, snel afremmen en een kleine vlek waar het begint.
##
## De loot-magneet blijft gewoon werken: dit script duwt de loot alleen weg.
##
## Gebruik, op de plek waar de vijand zijn loot laat vallen:
##   var settings: Dictionary = LootSplatter.settings_for("enemy_grunt")
##   for i in aantal:
##       var loot: Node2D = loot_scene.instantiate()
##       get_parent().add_child(loot)          # eerst in de scene zetten
##       LootSplatter.launch(loot, global_position, richting_van_de_kogel, settings)
##
## Afstellen gebeurt in de SSOT, per vijand-rij. Lege cel = de standaard hieronder.

## Standaardwaarden om mee te testen.
const DEFAULT_SPREAD_DEGREES := 55.0   # brede kegel (±55°)
const DEFAULT_MIN_SPEED := 90.0        # de traagste stukjes: vallen dicht bij de vijand
const DEFAULT_MAX_SPEED := 480.0       # de snelste stukjes: het eind van de streep
const DEFAULT_DRAG := 260.0            # afremming per seconde: hoe snel het "splat"
const DEFAULT_START_OFFSET := 4.0      # grootte van de vlek waar het begint (± px)

## Kolomnamen in de SSOT. base_loot_splatter is de maximale snelheid,
## loot_splatter_modifier komt daar als percentage bovenop (via StatCalc).
const STAT_MAX_SPEED := "loot_splatter"
const COL_SPREAD := "loot_splatter_spread"
const COL_MIN_SPEED := "loot_splatter_min_speed"
const COL_DRAG := "loot_splatter_drag"
const COL_START_OFFSET := "loot_splatter_start_offset"


## Haalt de instellingen voor één vijand uit de SSOT.
static func settings_for(enemy_id: String) -> Dictionary:
	return {
		"spread_degrees": Ssot.get_number(enemy_id, COL_SPREAD, DEFAULT_SPREAD_DEGREES),
		"min_speed": Ssot.get_number(enemy_id, COL_MIN_SPEED, DEFAULT_MIN_SPEED),
		"max_speed": StatCalc.value(enemy_id, STAT_MAX_SPEED, DEFAULT_MAX_SPEED),
		"drag": Ssot.get_number(enemy_id, COL_DRAG, DEFAULT_DRAG),
		"start_offset": Ssot.get_number(enemy_id, COL_START_OFFSET, DEFAULT_START_OFFSET),
	}


## De standaardinstellingen, voor als je (nog) niets uit de SSOT haalt.
static func default_settings() -> Dictionary:
	return {
		"spread_degrees": DEFAULT_SPREAD_DEGREES,
		"min_speed": DEFAULT_MIN_SPEED,
		"max_speed": DEFAULT_MAX_SPEED,
		"drag": DEFAULT_DRAG,
		"start_offset": DEFAULT_START_OFFSET,
	}


## Rekent de startsnelheid van één stukje loot uit.
## 'direction' is de richting waarin de kogel vloog. Is die onbekend (Vector2.ZERO),
## dan spat het stukje een willekeurige kant op.
static func random_velocity(direction: Vector2, settings: Dictionary) -> Vector2:
	var spread: float = deg_to_rad(float(settings.get("spread_degrees", DEFAULT_SPREAD_DEGREES)))
	var min_speed: float = float(settings.get("min_speed", DEFAULT_MIN_SPEED))
	var max_speed: float = float(settings.get("max_speed", DEFAULT_MAX_SPEED))

	var angle: float
	if direction.length_squared() < 0.0001:
		angle = randf_range(0.0, TAU)
	else:
		angle = direction.angle() + randf_range(-spread, spread)

	var speed: float = randf_range(min_speed, maxf(min_speed, max_speed))
	return Vector2.from_angle(angle) * speed


## Zet één stukje loot op zijn plek en geeft het zijn vaart.
## Roep dit aan NADAT de loot met add_child in de scene staat.
static func launch(loot: Node2D, origin: Vector2, direction: Vector2, settings: Dictionary = {}) -> void:
	if not loot.is_inside_tree():
		push_warning("LootSplatter: zet de loot eerst met add_child in de scene.")
		return
	if settings.is_empty():
		settings = default_settings()

	var offset: float = float(settings.get("start_offset", DEFAULT_START_OFFSET))
	loot.global_position = origin + Vector2(randf_range(-offset, offset), randf_range(-offset, offset))

	var velocity: Vector2 = random_velocity(direction, settings)
	var drag: float = float(settings.get("drag", DEFAULT_DRAG))

	if loot is RigidBody2D:
		# Een RigidBody2D beweegt zelf: geef hem alleen de vaart mee.
		var body: RigidBody2D = loot
		body.linear_velocity = velocity
		return

	# Alle andere soorten loot (Area2D, Node2D...) krijgen een hulpje dat ze voortduwt.
	var motion: SplatterMotion = SplatterMotion.new()
	loot.add_child(motion)
	motion.start(velocity, drag)
