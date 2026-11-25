class_name SpriteFit
## SpriteFit – maakt de botsvormen van een object passend bij zijn sprite.
##
## Zo kloppen de hitboxen altijd met wat je ziet, ook als Maik een nieuwe sprite met een andere maat
## aanlevert: de vorm wordt bij het starten uitgerekend uit de sprite (textuur × schaal × draaiing).
##
## Gebruik (in _ready, vóór het object geschaald wordt met base_size):
##   var radius: float = SpriteFit.fit(self)   # -1 als er geen sprite is (dan blijft alles zoals het was)
##
## Wat er gebeurt:
## - De eerste Sprite2D direct onder het object bepaalt de maat.
## - Elke CollisionShape2D direct onder het object, en onder een Area2D direct onder het object
##   (bijvoorbeeld "HitBox"), krijgt een vorm van die maat, op de plek van de sprite.
##   Rechthoek = de sprite, cirkel = de kleinste kant, capsule = de sprite in de lengte.
## - SHRINK maakt de vorm iets kleiner dan de tekening: lege randen van de PNG tellen niet als raak.
##
## Ontwikkelaarsnotities:
## - Vormen worden NIET in de scene aangepast (die worden gedeeld door alle exemplaren), maar per
##   maat één keer gemaakt en hergebruikt (_cache). Dat scheelt werk bij veel kogels.
## - Transformaties tussen object en vorm (rare schalen/draaiingen uit de editor) worden opgeruimd,
##   zodat de vorm precies de berekende maat heeft.

## Deel van de sprite dat als raakbaar telt (0.85 = 85%).
const SHRINK := 0.85

static var _cache: Dictionary = {}


## Past de botsvormen aan. Geeft de straal terug (gemiddelde halve maat), of -1 zonder sprite.
static func fit(root: Node2D, shrink: float = SHRINK) -> float:
	var sprite: Sprite2D = _first_sprite(root)
	if sprite == null or sprite.texture == null:
		return -1.0
	var visual: Vector2 = _rotated_size(sprite.get_rect().size * sprite.scale.abs(), sprite.rotation) * shrink
	if visual.x <= 0.0 or visual.y <= 0.0:
		return -1.0
	for shape_node in _shape_nodes(root):
		_apply(shape_node, visual, sprite.position)
	return (visual.x + visual.y) / 4.0


static func _first_sprite(root: Node) -> Sprite2D:
	for child in root.get_children():
		if child is Sprite2D:
			return child
	return null


## Alle CollisionShape2D's direct onder het object en onder een Area2D direct onder het object.
static func _shape_nodes(root: Node) -> Array:
	var found: Array = []
	for child in root.get_children():
		if child is CollisionShape2D:
			found.append(child)
		elif child is Area2D:
			var area: Area2D = child
			area.position = Vector2.ZERO
			area.rotation = 0.0
			area.scale = Vector2.ONE
			for grandchild in area.get_children():
				if grandchild is CollisionShape2D:
					found.append(grandchild)
	return found


## De omhullende rechthoek van een gedraaide rechthoek.
static func _rotated_size(size: Vector2, angle: float) -> Vector2:
	var c: float = absf(cos(angle))
	var s: float = absf(sin(angle))
	return Vector2(size.x * c + size.y * s, size.x * s + size.y * c)


static func _apply(node: CollisionShape2D, visual: Vector2, at: Vector2) -> void:
	node.position = at
	node.scale = Vector2.ONE
	node.rotation = 0.0
	var old: Shape2D = node.shape
	var kind: String = "rect"
	if old is CircleShape2D:
		kind = "circle"
	elif old is CapsuleShape2D:
		kind = "capsule"
	var key: String = "%s_%d_%d" % [kind, roundi(visual.x), roundi(visual.y)]
	if not _cache.has(key):
		_cache[key] = _make_shape(kind, visual)
	node.shape = _cache[key]
	# Een capsule ligt standaard rechtop; is de sprite breder dan hoog, dan draaien.
	if kind == "capsule" and visual.x > visual.y:
		node.rotation = PI / 2.0


static func _make_shape(kind: String, visual: Vector2) -> Shape2D:
	match kind:
		"circle":
			var circle := CircleShape2D.new()
			circle.radius = minf(visual.x, visual.y) / 2.0
			return circle
		"capsule":
			var capsule := CapsuleShape2D.new()
			capsule.radius = minf(visual.x, visual.y) / 2.0
			capsule.height = maxf(visual.x, visual.y)
			return capsule
		_:
			var rect := RectangleShape2D.new()
			rect.size = visual
			return rect
