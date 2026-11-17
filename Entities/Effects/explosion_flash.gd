extends Node2D
## ExplosionFlash – een kort lichtflitsje voor een ontploffing: een cirkel die uitdijt en vervaagt.
## Wordt door een kamikaze-vijand zelf aangemaakt; je hoeft dit nergens neer te zetten.

## Hoe groot de ontploffing is (pixels). De kamikaze-vijand vult dit in.
var radius: float = 120.0

const DURATION := 0.3

var _time: float = 0.0


func _ready() -> void:
	z_index = 50


func _process(delta: float) -> void:
	_time += delta
	if _time >= DURATION:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k: float = _time / DURATION
	var r: float = radius * (0.4 + 0.6 * k)
	draw_circle(Vector2.ZERO, r, Color(1.0, 0.75, 0.3, 0.55 * (1.0 - k)))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.6, 1.0 - k), 3.0)
