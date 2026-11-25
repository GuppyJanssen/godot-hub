class_name RoomBounds
## RoomBounds – de bewegingsruimte in een kamer, voor de speler EN de vijanden.
##
## Geen autoload nodig. Eén plek voor de regels, zodat speler en vijanden altijd dezelfde ruimte hebben:
##   - Zuidpool (ring 0): onderkant is altijd dicht (onzichtbare wand). Bovenkant is dicht zolang er
##     vijanden leven. Links en rechts loop je rond (van de ene rand naar de andere).
##   - Noordpool (laatste ring): bovenkant is altijd dicht. Links en rechts loop je rond, maar zolang er
##     vijanden leven zijn de zijkanten en de onderkant dicht.
##   - Gewone ringen: zolang er vijanden leven zijn alle vier de kanten dicht.
##   - Testkamer (onder de startkamer): links, rechts en onder dicht, boven open (terug naar de zuidpool).
##   - God Mode: de speler vliegt overal doorheen, ook door de onderkant van de zuidpool (naar de testkamer).
##
## Gebruik (na move_and_slide):
##   RoomBounds.apply(self, 30.0, enemies_alive)
## Een vijand roept dit aan met enemies_alive = true (hij leeft zelf, dus de kamer is nooit leeg).

## De oude, vaste kamergrootte. Nog de standaard als de SSOT leeg is, en de "oude" weergave in F1.
const BASE_SIZE := Vector2(1920.0, 1080.0)
## Grenzen voor world_room_width/height (beschermt tegen een typfout in de sheet).
const MIN_SIZE := Vector2(960.0, 540.0)
const MAX_SIZE := Vector2(7680.0, 4320.0)


## Grootte van een kamer in pixels: SSOT-rij world, kolommen world_room_width en world_room_height.
## Alles wat met kamerranden, het midden of plekken in de kamer rekent, gebruikt dit.
static func size() -> Vector2:
	return Vector2(
		clampf(Ssot.get_number("world", "world_room_width", BASE_SIZE.x), MIN_SIZE.x, MAX_SIZE.x),
		clampf(Ssot.get_number("world", "world_room_height", BASE_SIZE.y), MIN_SIZE.y, MAX_SIZE.y))


static func center() -> Vector2:
	return size() / 2.0


## Hoeveel groter (of kleiner) de kamer is dan de oude 1920 × 1080, per as.
static func scale_from_base() -> Vector2:
	return size() / BASE_SIZE


static func apply(body: CharacterBody2D, radius: float, enemies_alive: bool) -> void:
	var layer: int = LevelManager.current_layer
	var last_layer: int = LevelManager.LAYER_WIDTHS.size() - 1
	var pos: Vector2 = body.global_position
	var vel: Vector2 = body.velocity
	var is_player: bool = body == Game.active_player
	var room: Vector2 = size()
	var room_w: float = room.x
	var room_h: float = room.y

	if LevelManager.in_test_room:
		pos.x = clampf(pos.x, radius, room_w - radius)
		if pos.y > room_h - radius:
			pos.y = room_h - radius
			vel.y = 0.0
		body.global_position = pos
		body.velocity = vel
		return

	# God Mode: de speler wordt nergens tegengehouden.
	# Alleen het rondlopen op de polen blijft, en boven de noordpool is niets meer.
	if is_player and Game.debug_is_invincible:
		if layer == 0 or layer == last_layer:
			if pos.x < -10.0:
				pos.x = room_w + 5.0
			elif pos.x > room_w + 10.0:
				pos.x = -5.0
		if layer == last_layer and pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		body.global_position = pos
		body.velocity = vel
		return

	if layer == 0 or layer == last_layer:
		# Polen: rondlopen van links naar rechts.
		if pos.x < -10.0:
			pos.x = room_w + 5.0
		elif pos.x > room_w + 10.0:
			pos.x = -5.0

	if layer == 0:
		if enemies_alive and pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		if pos.y > room_h - radius:
			pos.y = room_h - radius
			vel.y = 0.0
	elif layer == last_layer:
		if pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		if enemies_alive:
			if pos.x < radius:
				pos.x = radius
				vel.x = 0.0
			elif pos.x > room_w - radius:
				pos.x = room_w - radius
				vel.x = 0.0
			if pos.y > room_h - radius:
				pos.y = room_h - radius
				vel.y = 0.0
	elif enemies_alive:
		if pos.x < radius:
			pos.x = radius
			vel.x = 0.0
		elif pos.x > room_w - radius:
			pos.x = room_w - radius
			vel.x = 0.0
		if pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		elif pos.y > room_h - radius:
			pos.y = room_h - radius
			vel.y = 0.0

	body.global_position = pos
	body.velocity = vel
