extends Camera2D
class_name GameCamera
## GameCamera – de camera tijdens een run.
##
## Wat hij doet:
## - Het schip staat altijd in het midden van het beeld (Daan, 26 nov: vooruitkijken was geen fijn
##   spelen, experiment gestopt; de oude versie staat in git, commit e0aa78e).
## - Komt nooit buiten de kamer (limit_* = de kamerranden). Aan de rand schuift het schip uit het midden.
##
## SSOT, rij world (leeg = de standaard hieronder):
##   camera_zoom       1 = ware grootte, 2 = twee keer ingezoomd (je ziet een kwart).
##
## Ontwikkelaarsnotities:
## - top_level: de camera draait niet mee met het schip; hij zet zijn eigen positie.
## - Werkt samen met RoomBounds.size() (world_room_width/height), zodat de kamer groter kan.

const SETTINGS_ROW := "world"
const DEFAULTS := {
	"camera_zoom": 1.0,
}


func _ready() -> void:
	top_level = true
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	apply_settings()
	make_current()
	_snap_to_target()


## Leest zoom en kamergrenzen opnieuw (bijvoorbeeld na een wissel in het F1-menu).
func apply_settings() -> void:
	var z: float = current_zoom()
	zoom = Vector2(z, z)
	var room: Vector2 = RoomBounds.size()
	limit_left = 0
	limit_top = 0
	limit_right = int(room.x)
	limit_bottom = int(room.y)


func _physics_process(_delta: float) -> void:
	snap()


func _snap_to_target() -> void:
	snap()


## Zet de camera meteen op het schip, zonder afvlakken (na een kamerwissel of teleport), zodat de
## achtergrond niet "verschiet" doordat de camera vanaf het midden van de kamer komt aanglijden.
func snap() -> void:
	var player: Node2D = get_parent() as Node2D
	if is_instance_valid(player):
		global_position = player.global_position
	reset_smoothing()


## De zoom van de camera (camera_zoom uit de SSOT).
## F1 "Zoomtest": zo ver uitgezoomd dat de hele kamer in beeld is. De kamer en alles erin blijven
## even groot; alleen de camera kijkt van verder weg.
static func current_zoom() -> float:
	var normal: float = clampf(_setting("camera_zoom"), 0.05, 4.0)
	if not Game.debug_zoom_overview:
		return clampf(normal, 0.25, 4.0)
	var view: Vector2 = Vector2(1920.0, 1080.0)
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		view = tree.root.get_visible_rect().size
	var room: Vector2 = RoomBounds.size()
	return minf(normal, minf(view.x / room.x, view.y / room.y))


## Tekst en lijnen in de wereld (naambordjes, vizier) blijven even groot op het scherm,
## hoe ver de camera ook is uitgezoomd: vermenigvuldig hun maat hiermee.
static func ui_scale() -> float:
	return 1.0 / current_zoom()


## Een Label in de wereld leesbaar houden bij elke zoom: schalen rond zijn midden.
static func fit_world_label(label: Label) -> void:
	if label == null:
		return
	label.pivot_offset = label.size / 2.0
	label.scale = Vector2.ONE * ui_scale()


static func _setting(setting_name: String) -> float:
	return Ssot.get_number(SETTINGS_ROW, setting_name, float(DEFAULTS[setting_name]))
