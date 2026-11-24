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

const SCREEN_WIDTH := 1920.0
const SCREEN_HEIGHT := 1080.0


static func apply(body: CharacterBody2D, radius: float, enemies_alive: bool) -> void:
	var layer: int = LevelManager.current_layer
	var last_layer: int = LevelManager.LAYER_WIDTHS.size() - 1
	var pos: Vector2 = body.global_position
	var vel: Vector2 = body.velocity
	var is_player: bool = body == Game.active_player

	if LevelManager.in_test_room:
		pos.x = clampf(pos.x, radius, SCREEN_WIDTH - radius)
		if pos.y > SCREEN_HEIGHT - radius:
			pos.y = SCREEN_HEIGHT - radius
			vel.y = 0.0
		body.global_position = pos
		body.velocity = vel
		return

	# God Mode: de speler wordt nergens tegengehouden.
	# Alleen het rondlopen op de polen blijft, en boven de noordpool is niets meer.
	if is_player and Game.debug_is_invincible:
		if layer == 0 or layer == last_layer:
			if pos.x < -10.0:
				pos.x = SCREEN_WIDTH + 5.0
			elif pos.x > SCREEN_WIDTH + 10.0:
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
			pos.x = SCREEN_WIDTH + 5.0
		elif pos.x > SCREEN_WIDTH + 10.0:
			pos.x = -5.0

	if layer == 0:
		if enemies_alive and pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		if pos.y > SCREEN_HEIGHT - radius:
			pos.y = SCREEN_HEIGHT - radius
			vel.y = 0.0
	elif layer == last_layer:
		if pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		if enemies_alive:
			if pos.x < radius:
				pos.x = radius
				vel.x = 0.0
			elif pos.x > SCREEN_WIDTH - radius:
				pos.x = SCREEN_WIDTH - radius
				vel.x = 0.0
			if pos.y > SCREEN_HEIGHT - radius:
				pos.y = SCREEN_HEIGHT - radius
				vel.y = 0.0
	elif enemies_alive:
		if pos.x < radius:
			pos.x = radius
			vel.x = 0.0
		elif pos.x > SCREEN_WIDTH - radius:
			pos.x = SCREEN_WIDTH - radius
			vel.x = 0.0
		if pos.y < radius:
			pos.y = radius
			vel.y = 0.0
		elif pos.y > SCREEN_HEIGHT - radius:
			pos.y = SCREEN_HEIGHT - radius
			vel.y = 0.0

	body.global_position = pos
	body.velocity = vel
