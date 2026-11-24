extends StaticBody2D
class_name TestDummy
## TestDummy – een schietschijf voor de testkamer.
##
## Laat bij elke treffer de schade en het damage type zien (zwevend getal), en houdt de
## schade per seconde bij over de laatste paar seconden. Gaat nooit kapot.
## De kogel meldt het damage type via on_hit_info(), vlak voor take_damage().

const RADIUS := 40.0
## Over hoeveel seconden de schade per seconde gemiddeld wordt.
const DPS_WINDOW := 3.0

var _last_type: String = ""
var _hits: Array = []   # [tijd, schade]
var _total: int = 0
var _info: Label


func _ready() -> void:
	add_to_group("targets")
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)

	var body: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i in 24:
		points.append(Vector2.RIGHT.rotated(TAU * i / 24.0) * RADIUS)
	body.polygon = points
	body.color = Color(0.85, 0.85, 0.85)
	add_child(body)
	var ring: Polygon2D = Polygon2D.new()
	var inner: PackedVector2Array = PackedVector2Array()
	for i in 24:
		inner.append(Vector2.RIGHT.rotated(TAU * i / 24.0) * RADIUS * 0.45)
	ring.polygon = inner
	ring.color = Color(0.9, 0.2, 0.2)
	add_child(ring)

	_info = Label.new()
	_info.position = Vector2(-120, RADIUS + 8)
	_info.size = Vector2(240, 60)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_info)
	_update_info()


## De kogel vertelt welk damage type hij heeft (vlak voor take_damage).
func on_hit_info(_amount: int, damage_type: String) -> void:
	_last_type = damage_type


func take_damage(amount: int, _flash: bool = true, _hit_dir: Vector2 = Vector2.ZERO) -> void:
	var now: float = Time.get_ticks_msec() / 1000.0
	_hits.append([now, amount])
	_total += amount
	var type_text: String = _last_type if _last_type != "" else "geen type"
	_last_type = ""
	_float_text("%d  (%s)" % [amount, type_text])
	_update_info()


func _process(_delta: float) -> void:
	_update_info()


func _update_info() -> void:
	if not is_instance_valid(_info):
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	while not _hits.is_empty() and now - float(_hits[0][0]) > DPS_WINDOW:
		_hits.pop_front()
	var recent: int = 0
	for hit in _hits:
		recent += int(hit[1])
	_info.text = "Schade/sec: %.1f\nTotaal: %d" % [recent / DPS_WINDOW, _total]


# Een getal dat omhoog zweeft en vervaagt.
func _float_text(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	label.position = Vector2(randf_range(-30, 10), -RADIUS - 24)
	add_child(label)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)
