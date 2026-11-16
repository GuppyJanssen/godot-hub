class_name SplatterMotion
extends Node
## SplatterMotion – duwt zijn ouder (een stukje loot) een kant op en remt snel af.
##
## Dit hulpje wordt door LootSplatter.launch() vanzelf aan de loot gehangen
## en ruimt zichzelf op zodra de loot stilligt. Je hoeft het nergens zelf neer te zetten.
##
## Het telt de beweging OP bij wat de loot zelf al doet. De loot-magneet blijft dus werken.

var velocity: Vector2 = Vector2.ZERO
var drag: float = 600.0


func start(start_velocity: Vector2, drag_per_second: float) -> void:
	velocity = start_velocity
	drag = drag_per_second


func _physics_process(delta: float) -> void:
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		queue_free()
		return

	parent.global_position += velocity * delta
	velocity = velocity.move_toward(Vector2.ZERO, drag * delta)

	if velocity == Vector2.ZERO:
		queue_free()
