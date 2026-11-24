extends Control
## Skill tree – een vertakkende boom die vanuit het midden alle kanten op groeit.
##
## Hoe het werkt:
## - De stamboom (wie is de parent) is in elke save gelijk; de plek van de takken verschilt per save.
##   Zie SkillTreeLayout. De seed daarvoor (tree_seed) wordt bij de eerste keer openen in de save gezet.
## - Een skill die je nog nooit hebt gekocht is een zwart vakje met "?". Je kunt er wel punten in
##   zetten als zijn parent punten heeft; dan zie je wat het is (hij komt in discovered_skills).
## - De rand van een cirkel heeft de kleur van de soort skill (kolom skill_kind in de SSOT).
## - Linkermuisknop: kopen. Rechtermuisknop slepen: kaart verschuiven. Muiswiel: zoomen. Esc: terug.
##
## Ontwikkelaarsnotities:
## - skills_data in de save houdt de vorm {"level", "currency_type", "loss_per_minute"} (zoals eerst),
##   zodat verval en het pauzemenu gewoon blijven werken.
## - Zolang skill_kind nog niet in de sheet staat, gebruikt de code FALLBACK_KIND hieronder.

const TREE_CENTER := Vector2(960, 540)
const KIND_COLUMN := "skill_kind"
const MAX_LEVEL_COLUMN := "fill_levels_amount"
const DEFAULT_MAX_LEVEL := 100

## Kleur per soort skill (de rand van de cirkel).
const KIND_COLORS := {
	"wapen": Color(0.91, 0.33, 0.23),
	"schip": Color(0.23, 0.61, 0.91),
	"beweging": Color(0.31, 0.82, 0.42),
	"loot": Color(0.91, 0.76, 0.23),
	"tree": Color(0.66, 0.42, 0.91),
	"overig": Color(0.6, 0.6, 0.6),
}
## Tijdelijk: soort per skill zolang de kolom skill_kind in de sheet nog leeg is.
const FALLBACK_KIND := {
	"skill_fire_rate": "wapen", "skill_damage": "wapen", "skill_shot_speed": "wapen",
	"skill_range": "wapen", "skill_idk": "wapen", "skill_burst": "wapen", "skill_pierce": "wapen",
	"skill_bounce": "wapen", "skill_precision": "wapen", "skill_knockback": "wapen",
	"skill_explosion": "wapen",
	"skill_shield": "schip", "skill_shield_regen": "schip", "skill_max_health": "schip",
	"skill_health_regen": "schip", "skill_energy": "schip",
	"skill_speed": "beweging", "skill_handling": "beweging",
	"skill_loot_magnet": "loot", "skill_pickup": "loot",
	"skill_jump": "tree", "skill_vision": "tree", "skill_back_vision": "tree",
}
## Valuta in de volgorde van MetaProgress (0 = currency_1 = olrite).
const CURRENCIES := ["olrite", "metal", "keepium", "element_1", "element_2", "element_3"]

var current_meta: MetaProgress = null
## Hoeveel levels er per klik worden gekocht.
var buy_amount: int = 1

var _parents: Dictionary = {}
var _nodes: Dictionary = {}        # skill_id -> SkillTreeNode
var _lines: Dictionary = {}        # skill_id -> Line2D (van parent naar deze skill)
var _canvas: Node2D = null
var _hovered_id: String = ""

@onready var tree_camera: Camera2D = $TreeCamera
@onready var back_button: Button = find_child("back_to_main_menu", true, false) as Button
@onready var skill_popup: PanelContainer = find_child("SkillPopup", true, false) as PanelContainer
@onready var popup_title: Label = find_child("PopupTitle", true, false) as Label
@onready var popup_description: Label = find_child("PopupDescription", true, false) as Label

# --- CAMERA ---
var min_zoom: float = 0.35
var max_zoom: float = 2.0
var zoom_speed: float = 0.1
var is_dragging: bool = false


func _ready() -> void:
	get_viewport().gui_release_focus()
	current_meta = _load_meta()
	_ensure_tree_seed()
	_mark_bought_as_discovered()

	if is_instance_valid(tree_camera):
		tree_camera.global_position = TREE_CENTER
	if is_instance_valid(back_button) and not back_button.pressed.is_connected(_on_back_to_main_menu_pressed):
		back_button.pressed.connect(_on_back_to_main_menu_pressed)

	_build_tree()
	update_skill_tree_visuals()


# =========================================================================
# --- OPBOUWEN ---
# =========================================================================
func _build_tree() -> void:
	_canvas = Node2D.new()
	_canvas.name = "TreeCanvas"
	add_child(_canvas)
	_canvas.global_position = TREE_CENTER

	var ids: Array = SkillTreeLayout.skill_ids()
	if ids.is_empty():
		push_warning("SKILL TREE: geen skills (data_type upgrade_skill) in de SSOT gevonden.")
		return
	_parents = SkillTreeLayout.build_parents(ids)
	var positions: Dictionary = SkillTreeLayout.build_positions(_parents, current_meta.tree_seed)

	# Eerst de lijnen, zodat ze achter de cirkels liggen.
	var lines_layer := Node2D.new()
	lines_layer.name = "Lines"
	_canvas.add_child(lines_layer)
	for skill_id in _parents:
		var parent_id: String = _parents[skill_id]
		if parent_id == "" or not positions.has(skill_id) or not positions.has(parent_id):
			continue
		var line := Line2D.new()
		line.width = 3.0
		line.antialiased = true
		line.points = _line_points(positions[parent_id], positions[skill_id])
		lines_layer.add_child(line)
		_lines[skill_id] = line

	for skill_id in ids:
		if not positions.has(skill_id):
			continue
		var node := SkillTreeNode.new()
		node.name = skill_id
		node.position = positions[skill_id]
		node.setup(skill_id, Ssot.get_text(skill_id, "ingame_name", skill_id), _kind_color(skill_id))
		_canvas.add_child(node)
		_nodes[skill_id] = node


## Rechte lijn van parent naar kind. Recht, zodat de controle op kruisen in SkillTreeLayout klopt.
func _line_points(from: Vector2, to: Vector2) -> PackedVector2Array:
	return PackedVector2Array([from, to])


func _kind_color(skill_id: String) -> Color:
	var kind: String = Ssot.get_text(skill_id, KIND_COLUMN, "").strip_edges().to_lower()
	if kind == "":
		kind = FALLBACK_KIND.get(skill_id, "overig")
	return KIND_COLORS.get(kind, KIND_COLORS["overig"])


# =========================================================================
# --- ZICHTBAARHEID EN STAAT ---
# =========================================================================
func update_skill_tree_visuals() -> void:
	if not current_meta:
		return
	var vision_range: int = 1
	if _level_of("skill_vision") > 0:
		vision_range += maxi(Ssot.get_int("skill_vision", "tree_view_distance", 1), 0)

	for skill_id in _nodes:
		var node: SkillTreeNode = _nodes[skill_id]
		var parent_id: String = _parents.get(skill_id, "")
		var is_root: bool = parent_id == ""
		var discovered: bool = is_root or _is_discovered(skill_id)
		var visible_now: bool = discovered or _ancestor_discovered_within(skill_id, vision_range)
		var buyable: bool = is_root or _level_of(parent_id) > 0
		node.visible = visible_now
		node.set_state(_level_of(skill_id), _max_level(skill_id), discovered, buyable)

		if _lines.has(skill_id):
			var line: Line2D = _lines[skill_id]
			var parent_visible: bool = _nodes.has(parent_id) and _nodes[parent_id].visible
			line.visible = visible_now and parent_visible
			line.default_color = node.kind_color.darkened(0.2) if discovered else Color(0.35, 0.35, 0.38, 0.8)


## Is een voorouder binnen 'steps' stappen ooit gekocht? Dan zie je deze skill als zwart vakje.
func _ancestor_discovered_within(skill_id: String, steps: int) -> bool:
	var current: String = _parents.get(skill_id, "")
	var step: int = 1
	while current != "" and step <= steps:
		if _parents.get(current, "") == "" or _is_discovered(current):
			return true
		current = _parents.get(current, "")
		step += 1
	return false


func _is_discovered(skill_id: String) -> bool:
	return current_meta.discovered_skills.has(skill_id)


func _level_of(skill_id: String) -> int:
	if skill_id == "" or not current_meta.skills_data.has(skill_id):
		return 0
	var data = current_meta.skills_data[skill_id]
	return int(data["level"]) if data is Dictionary else int(data)


func _max_level(skill_id: String) -> int:
	return Ssot.get_int(skill_id, MAX_LEVEL_COLUMN, DEFAULT_MAX_LEVEL)


# =========================================================================
# --- INVOER: KOPEN, HOVER, CAMERA ---
# =========================================================================
func _process(_delta: float) -> void:
	var under: String = _skill_under_mouse()
	if under != _hovered_id:
		if _nodes.has(_hovered_id):
			_nodes[_hovered_id].set_hovered(false)
		_hovered_id = under
		if _nodes.has(_hovered_id):
			_nodes[_hovered_id].set_hovered(true)
		_update_popup()
	if is_instance_valid(skill_popup) and skill_popup.visible:
		# De popup zit in een CanvasLayer, dus schermcoördinaten (niet die van de camera).
		skill_popup.position = get_viewport().get_mouse_position() + Vector2(25, 25)


func _skill_under_mouse() -> String:
	var mouse: Vector2 = get_global_mouse_position()
	for skill_id in _nodes:
		var node: SkillTreeNode = _nodes[skill_id]
		if node.visible and node.contains_point(mouse):
			return skill_id
	return ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var skill_id: String = _skill_under_mouse()
		if skill_id != "":
			_try_buy(skill_id)
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		_on_back_to_main_menu_pressed()
		return
	if not is_instance_valid(tree_camera):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		is_dragging = event.pressed
	if event is InputEventMouseMotion and is_dragging:
		tree_camera.global_position -= event.relative / tree_camera.zoom.x
	if event is InputEventMouseButton and event.is_pressed():
		var current_zoom: float = tree_camera.zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			current_zoom = clampf(current_zoom + zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			current_zoom = clampf(current_zoom - zoom_speed, min_zoom, max_zoom)
		tree_camera.zoom = Vector2(current_zoom, current_zoom)


func _try_buy(skill_id: String) -> void:
	var node: SkillTreeNode = _nodes.get(skill_id)
	if node == null or not node.buyable:
		print("SKILL TREE: ", skill_id, " is nog niet te koop (de parent heeft nog geen punten).")
		return
	var current_level: int = _level_of(skill_id)
	var max_level: int = _max_level(skill_id)
	var qty: int = mini(buy_amount, max_level - current_level)
	if qty <= 0:
		return
	var cost: Vector2i = _cost(skill_id)   # x = valuta-index, y = prijs per level
	var total: int = cost.y * qty
	var field: String = "currency_" + str(cost.x + 1)
	if int(current_meta.get(field)) < total:
		print("SKILL TREE: onvoldoende ", CURRENCIES[cost.x], " voor ", skill_id, " (kosten: ", total, ")")
		return
	current_meta.set(field, int(current_meta.get(field)) - total)

	var data: Dictionary = {"level": 0, "currency_type": cost.x, "loss_per_minute": _loss_per_minute(skill_id)}
	var old = current_meta.skills_data.get(skill_id)
	if old is Dictionary:
		data = old.duplicate()
	data["level"] = current_level + qty
	data["currency_type"] = cost.x
	data["loss_per_minute"] = _loss_per_minute(skill_id)
	current_meta.skills_data[skill_id] = data
	if not current_meta.discovered_skills.has(skill_id):
		current_meta.discovered_skills.append(skill_id)
		print("SKILL TREE: ontdekt: ", skill_id)

	_save_meta()
	update_skill_tree_visuals()
	_update_popup()


## Prijs uit de SSOT-kolom fill_costs_per_point ("olrite:5"). Standaard 5 olrite.
func _cost(skill_id: String) -> Vector2i:
	var currency: int = 0
	var price: int = 5
	var text: String = Ssot.get_text(skill_id, "fill_costs_per_point", "")
	if ":" in text:
		var parts: PackedStringArray = text.split(":")
		var index: int = CURRENCIES.find(parts[0].strip_edges().to_lower())
		if index >= 0:
			currency = index
		price = int(parts[1].strip_edges().to_float())
	elif text.is_valid_float():
		price = int(text.to_float())
	return Vector2i(currency, maxi(price, 0))


func _loss_per_minute(skill_id: String) -> int:
	return int(Ssot.get_number(skill_id, "base_decay_per_minute",
			Ssot.get_number("player_base", "base_decay_per_minute", 1.0)))


func _update_popup() -> void:
	if not is_instance_valid(skill_popup):
		return
	if not _nodes.has(_hovered_id):
		skill_popup.visible = false
		return
	var node: SkillTreeNode = _nodes[_hovered_id]
	var cost: Vector2i = _cost(_hovered_id)
	var cost_text: String = "Kosten: %d %s per level" % [cost.y, CURRENCIES[cost.x]]
	var title: String
	var info: String
	if node.discovered:
		title = "%s (%d/%d)" % [node.display_name, node.level, node.max_level]
		info = Ssot.get_text(_hovered_id, "skill_pop_up_info", Ssot.get_text(_hovered_id, "description", ""))
	else:
		title = "Onbekende skill"
		info = "Zet er een punt in om te ontdekken wat dit is."
	if not node.buyable:
		info += "\nNog niet te koop: zet eerst punten in de skill waar deze aan vastzit."
	if is_instance_valid(popup_title):
		popup_title.text = title
	if is_instance_valid(popup_description):
		popup_description.text = info + "\n" + cost_text
	skill_popup.visible = true


# =========================================================================
# --- OPSLAAN ---
# =========================================================================
func _load_meta() -> MetaProgress:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var meta: MetaProgress = save_system.get_loaded_meta_progress() as MetaProgress
	save_system.free()
	return meta if meta else MetaProgress.new()


func _save_meta() -> void:
	var save_system = load("res://Systems/SaveSystem.gd").new()
	save_system.save_meta_progress(current_meta)
	save_system.free()


## Nieuwe save (of een oude save van voor deze boom): kies één keer een seed en sla die meteen op,
## zodat de boom bij elke keer openen hetzelfde blijft.
func _ensure_tree_seed() -> void:
	if current_meta.tree_seed != 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	current_meta.tree_seed = rng.randi_range(1, 2147483646)
	_save_meta()


## Skills met punten uit een oudere save tellen als ontdekt.
func _mark_bought_as_discovered() -> void:
	for skill_id in current_meta.skills_data:
		if _level_of(skill_id) > 0 and not current_meta.discovered_skills.has(skill_id):
			current_meta.discovered_skills.append(skill_id)


func _on_back_to_main_menu_pressed() -> void:
	_save_meta()
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")
