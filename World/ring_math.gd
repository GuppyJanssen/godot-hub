class_name RingMath
## RingMath – rekenwerk voor de bol van ringen.
##
## Geen autoload nodig.
##
## Lost de bug op dat je bij omhoog of omlaag altijd in kamer 0 uitkomt:
##   # was:  current_room_index = 0
##   # wordt:
##   current_room_index = RingMath.map_room_index(current_room_index, breedte_oude_ring, breedte_nieuwe_ring)
##
## De breedtes komen uit LevelManager.LAYER_WIDTHS (1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1).


## Welke kamer ligt in de andere ring recht boven of onder deze kamer?
## Van 12 naar 24 kamers wordt kamer 5 kamer 10. Van 24 naar 12 worden kamer 10 en 11 allebei kamer 5.
static func map_room_index(room_index: int, from_width: int, to_width: int) -> int:
	if from_width <= 0 or to_width <= 0:
		return 0
	if from_width == to_width:
		return wrap_index(room_index, to_width)
	var mapped: int = int(floor(float(room_index) * float(to_width) / float(from_width)))
	return clampi(mapped, 0, to_width - 1)


## Links en rechts lopen rond: na de laatste kamer komt weer kamer 0.
static func wrap_index(room_index: int, width: int) -> int:
	if width <= 0:
		return 0
	return posmod(room_index, width)


## De kamer links van deze kamer, in dezelfde ring.
static func left_of(room_index: int, width: int) -> int:
	return wrap_index(room_index - 1, width)


## De kamer rechts van deze kamer, in dezelfde ring.
static func right_of(room_index: int, width: int) -> int:
	return wrap_index(room_index + 1, width)


## Waar staat deze kamer op de cirkel, in graden (0 tot 360)? Voor de factie-oorlog.
static func room_angle_degrees(room_index: int, width: int) -> float:
	if width <= 0:
		return 0.0
	return (float(wrap_index(room_index, width)) + 0.5) * 360.0 / float(width)


## Hoeveel backtrack-punten heb je verdiend?
## Eén punt per 'rooms_per_backtrack' gehaalde kamers, tot 'max_points'. 'used' is wat al is uitgegeven.
static func backtrack_points(cleared_rooms: int, rooms_per_backtrack: int, max_points: int, used: int) -> int:
	if rooms_per_backtrack <= 0:
		return 0
	var earned: int = mini(cleared_rooms / rooms_per_backtrack, max_points)
	return maxi(0, earned - used)


## Hoeveel driehoeken heeft de wereld bij dit aantal bossoverwinningen? (SSOT world:
## base_world_triangles, wins_per_extra_triangle, max_world_triangles.)
static func world_triangle_count(base: int, wins: int, wins_per_extra: int, max_count: int) -> int:
	if wins_per_extra <= 0:
		return clampi(base, 1, max_count)
	return clampi(base + wins / wins_per_extra, 1, max_count)


## Hoeveel ringen heeft de wereld bij dit aantal overwinningen?
static func world_ring_count(base_rings: int, wins: int, wins_per_extra_ring: int, max_rings: int) -> int:
	if wins_per_extra_ring <= 0:
		return mini(base_rings, max_rings)
	return mini(base_rings + wins / wins_per_extra_ring, max_rings)
