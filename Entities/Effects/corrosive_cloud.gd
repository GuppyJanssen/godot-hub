class_name CorrosiveCloud
extends Node2D
## CorrosiveCloud – het wolkje dat een spore (organic kamikaze) achterlaat na zijn ontploffing.
##
## - Blijft 'duration' seconden hangen en raakt ALLES wat erin zit: de speler, vijanden van elke
##   factie en gebouwen. Damage type corrosive (= acid), dus resistances tellen mee via DamageCalc
##   (organic heeft er een resistance tegen, mech is er zwak voor).
## - Schade per seconde = damage_per_second, uitgedeeld in tikken van TICK seconden.
## - Vervaagt zichtbaar naar het einde toe.
##
## SSOT (de rij van de ontploffende vijand, via EnemyStats):
##   explosion_cloud_duration   seconden (0 of leeg = geen wolkje)
##   explosion_cloud_radius     straal (leeg = base_explosion_radius)
##   base_corrosive_damage      schade per seconde
##
## Ontwikkelaarsnotities:
## - Geen physics-vorm: per tik een afstandscheck over de groepen targets en enemies en de speler.
##   Een tik is een halve seconde, dus ook met een paar wolkjes tegelijk is dat goedkoop.
## - Schade wordt per doel opgespaard (_carry) zodat 2,5 schade per tik niet steeds naar 3 afrondt.
## - Pauze: process_mode erft, dus het wolkje staat stil tijdens de pauze.

const TICK := 0.5
const COLOR := Color(0.55, 0.9, 0.25)
const MAX_ALPHA := 0.35

var duration: float = 12.0
var radius: float = 130.0
var damage_per_second: float = 5.0
var damage_type: String = "acid"

var _age: float = 0.0
var _tick_left: float = 0.0
var _carry: Dictionary = {}   # instance id -> opgespaarde schade onder 1


## Maakt een wolkje op 'at'. Doet niets als duur, straal of schade 0 is.
static func spawn(parent: Node, at: Vector2, cloud_duration: float, cloud_radius: float, dps: float) -> CorrosiveCloud:
	if parent == null or cloud_duration <= 0.0 or cloud_radius <= 0.0 or dps <= 0.0:
		return null
	var cloud := CorrosiveCloud.new()
	cloud.duration = cloud_duration
	cloud.radius = cloud_radius
	cloud.damage_per_second = dps
	cloud.z_index = -10   # onder de schepen, boven de achtergrond
	parent.add_child(cloud)
	cloud.global_position = at
	return cloud


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left = TICK
		_hurt_everything()
	queue_redraw()


func _hurt_everything() -> void:
	var victims: Dictionary = {}
	for node in get_tree().get_nodes_in_group("targets") + get_tree().get_nodes_in_group("enemies"):
		if node is Node2D and node.has_method("take_damage") and not victims.has(node):
			victims[node] = true
	var player: Node = Game.active_player
	if is_instance_valid(player) and player.has_method("take_damage"):
		victims[player] = true
	for victim in victims:
		if not is_instance_valid(victim) or victim.is_queued_for_deletion():
			continue
		if (victim as Node2D).global_position.distance_to(global_position) > radius:
			continue
		var key: int = victim.get_instance_id()
		var raw: float = damage_per_second * TICK * DamageCalc.factor(damage_type, victim) + float(_carry.get(key, 0.0))
		var whole: int = floori(raw)
		_carry[key] = raw - whole
		if whole > 0:
			victim.take_damage(whole, false, Vector2.ZERO)


func _draw() -> void:
	# Vervagen: de laatste derde van de tijd gaat de dekking naar 0.
	var left: float = 1.0 - _age / maxf(duration, 0.01)
	var alpha: float = MAX_ALPHA * clampf(left * 3.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius, Color(COLOR, alpha * 0.6))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, Color(COLOR, alpha), 2.0)
