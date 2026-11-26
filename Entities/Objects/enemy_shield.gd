class_name EnemyShield
extends RefCounted
## EnemyShield – het schild van een vijand of gebouw. Het schild vangt schade op vóór de levens
## en laadt na een wachttijd weer op.
##
## SSOT (type-rij, met _modifier van type en factie, of een eigen vijand-rij):
##   max_shield           maximaal schild. 0 of leeg = geen schild.
##   shield_regen_amount  schild per seconde, na de wachttijd.
##   shield_regen_delay   seconden na een treffer voordat het schild weer laadt.
##
## Gebruik (zie test_body.gd en basic_spawner.gd):
##   shield = EnemyShield.create(self, faction, unit_type, straal)
##   amount = shield.absorb(amount)      # in take_damage, geeft terug wat er doorheen komt
##   shield.update(delta)                # elk frame
##
## Ontwikkelaarsnotitie: het schild is te zien als een blauwe ring (Line2D) die vager wordt
## naarmate het schild leger is. Geen schild = geen ring.

const RING_COLOR := Color(0.35, 0.75, 1.0, 0.9)
const RING_WIDTH := 3.0
const RING_POINTS := 32

var max_value: float = 0.0
var current: float = 0.0
var regen_per_second: float = 0.0
var regen_delay: float = 0.0
var _delay_left: float = 0.0
var _ring: Line2D = null


## Maakt een schild voor deze eenheid. Geeft altijd een schild terug (max 0 = doet niets).
static func create(owner: Node2D, faction: String, unit_type: String, ring_radius: float) -> EnemyShield:
	var shield: EnemyShield = EnemyShield.new()
	shield.max_value = maxf(0.0, EnemyStats.value(faction, unit_type, "max_shield", 0.0))
	shield.current = shield.max_value
	shield.regen_per_second = maxf(0.0, EnemyStats.value(faction, unit_type, "shield_regen_amount", 0.0))
	shield.regen_delay = maxf(0.0, EnemyStats.value(faction, unit_type, "shield_regen_delay", 3.0))
	if shield.max_value > 0.0 and is_instance_valid(owner):
		shield._make_ring(owner, ring_radius)
	return shield


func has_shield() -> bool:
	return max_value > 0.0


## Vangt schade op. Geeft terug hoeveel schade er doorheen komt (voor de levens).
## 'shield_factor': hoe sterk deze treffer tegen schilden is (DamageCalc.shield_factor_for).
## 2 = het schild gaat twee keer zo snel leeg; wat erdoor komt telt weer als gewone schade.
func absorb(amount: float, shield_factor: float = 1.0) -> float:
	if max_value <= 0.0 or amount <= 0.0:
		return amount
	_delay_left = regen_delay
	var factor: float = maxf(0.01, shield_factor)
	var absorbed: float = minf(current, amount * factor)
	current -= absorbed
	_update_ring()
	return amount - absorbed / factor


func update(delta: float) -> void:
	if max_value <= 0.0 or current >= max_value:
		return
	if _delay_left > 0.0:
		_delay_left -= delta
		return
	current = minf(max_value, current + regen_per_second * delta)
	_update_ring()


## Zet een bewaarde stand terug (uit de save), begrensd tot het maximum.
func restore(value: float) -> void:
	current = clampf(value, 0.0, max_value)
	_update_ring()


func _make_ring(owner: Node2D, ring_radius: float) -> void:
	_ring = Line2D.new()
	_ring.name = "ShieldRing"
	_ring.width = RING_WIDTH
	_ring.closed = true
	_ring.default_color = RING_COLOR
	var points: PackedVector2Array = PackedVector2Array()
	for i in RING_POINTS:
		points.append(Vector2.RIGHT.rotated(TAU * i / RING_POINTS) * ring_radius)
	_ring.points = points
	owner.add_child(_ring)
	_update_ring()


func _update_ring() -> void:
	if is_instance_valid(_ring) and max_value > 0.0:
		_ring.modulate.a = current / max_value
