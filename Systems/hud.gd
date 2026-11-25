extends CanvasLayer
# BEDIENING: HUD (Live In-Game Interface Regisseur)

@onready var currency_container: VBoxContainer = find_child("CurrencyContainer", true, false) as VBoxContainer
@onready var location_label: Label = find_child("LocationLabel", true, false) as Label

# GECORRIGEERD: Omgezet naar reguliere ProgressBar conform de echte scéneboom van de editor!
@onready var health_bar: ProgressBar = find_child("HealthBar", true, false) as ProgressBar
@onready var shield_bar: ProgressBar = find_child("ShieldBar", true, false) as ProgressBar
@onready var energy_bar: ProgressBar = find_child("EnergyBar", true, false) as ProgressBar
@onready var status_container: Control = find_child("StatusContainer", true, false) as Control


var active_player_node: CharacterBody2D = null
var player_stats: PlayerStats = null
## Eén regel per grondstof uit de SSOT (LootResources): id -> {"row": HBoxContainer, "label": Label}.
var _resource_rows: Dictionary = {}
## De kluis, opnieuw ingelezen elke VAULT_REFRESH_SECONDS (niet elk frame van schijf lezen).
var _vault: MetaProgress = null
var _vault_timer: float = 0.0
const VAULT_REFRESH_SECONDS := 0.5
## Afstand van de grondstoflijst tot de rechterbovenhoek van het scherm (pixels).
const CURRENCY_MARGIN := Vector2(40.0, 40.0)

# Eén SaveSystem dat hergebruikt wordt (voor de saldo-weergave in de skill tree).
var _save_sys: SaveSystem = null


func _ready() -> void:
	layer = 100
	visible = true
	
	if currency_container:
		currency_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Rechtsboven vastzetten en naar LINKS laten groeien, zodat lange regels niet buiten beeld vallen
		# (stond eerst op een vaste x van 1700 en groeide naar rechts).
		currency_container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		currency_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		currency_container.offset_right = -CURRENCY_MARGIN.x
		currency_container.offset_left = -CURRENCY_MARGIN.x
		currency_container.offset_top = CURRENCY_MARGIN.y
	
	_find_active_player()
	
	_build_resource_rows()
	_vault_timer = 0.0

	# --- ANTI-FLITS BEVEILIGING VOOR MENU'S EN SKILL TREE ---
	# Als we opstarten en er is GEEN actieve speler, verbergen we de boel direct in ready()
	# Dit voorkomt dat de container 1 frame op het scherm flitst tijdens scénewissels!
	if not is_instance_valid(active_player_node):
		if is_instance_valid(status_container): status_container.visible = false
		if is_instance_valid(location_label): location_label.visible = false

	# --- SKILL TREE INTERFACE BEVEILIGING ---
	# Als we in de Skill Tree staan (er is geen player), dwingen we de HUD-containers
	# om muisklikken te negeren, zodat zoomen, slepen en knoppen weer werken!
	if not is_instance_valid(active_player_node):
		# We dwingen de achterliggende CurrencyContainer om kliks onvoorwaardelijk door te laten
		var curr_container = find_child("CurrencyContainer", true, false)
		if is_instance_valid(curr_container) and curr_container is Control:
			curr_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
			
		# SSoT VEILIGHEID: Mocht er een overkoepelend achtergrondpaneel in jullie HUD-scène zitten,
		# dan dwingen we die hier via een brede scan ook direct op ignore
		for child in get_children():
			if child is Control:
				child.mouse_filter = Control.MOUSE_FILTER_IGNORE



func _find_active_player() -> void:
	if get_tree() and get_tree().current_scene:
		var player = get_tree().current_scene.find_child("Player", true, false) as CharacterBody2D
		if is_instance_valid(player):
			active_player_node = player
			if "stats" in player and player.stats:
				player_stats = player.stats
			return
			
	player_stats = null


func _process(_delta: float) -> void:
	if not is_instance_valid(active_player_node):
		# GECORRIGEERD: Vraagt de actieve player node op
		_find_active_player()
		
	# --- UNIVERSELE SSoT HUD UPDATER (Werkt in de run EN in de Skill Tree!) ---
	if is_instance_valid(Game):
		
		# REGEL A: Als de speler actief is in een run, tonen we de 'Saldo (+Winst)' HUD
		if is_instance_valid(active_player_node):
			_update_resource_rows(_delta, true)

			# Activeer de complete status-as en locatie tijdens de run
			if is_instance_valid(status_container): status_container.visible = true
			if is_instance_valid(location_label): location_label.visible = true

			# 1. LIVE HUD STATUS BALKEN UPDATEREN
			if active_player_node.stats:
				var p_stats = active_player_node.stats
				if is_instance_valid(health_bar):
					health_bar.max_value = p_stats.max_health
					health_bar.value = p_stats.current_health
				if is_instance_valid(shield_bar):
					shield_bar.max_value = p_stats.max_shield
					shield_bar.value = p_stats.current_shield
				if is_instance_valid(energy_bar):
					energy_bar.max_value = p_stats.max_energy
					energy_bar.value = p_stats.current_energy
					
			# 2. LOCATIE LABEL BIJWERKEN
			if is_instance_valid(LevelManager) and is_instance_valid(location_label):
				if LevelManager.in_test_room:
					location_label.text = "LOCATIE: Testkamer (terug: omhoog vliegen)"
				elif LevelManager.current_layer == 0:
					location_label.text = "LOCATIE: Zuidpool (Startbasis)"
				elif LevelManager.current_layer == LevelManager.LAYER_WIDTHS.size() - 1:
					location_label.text = "LOCATIE: Noordpool (Eindbaas-Arena)"
				else:
					location_label.text = "LOCATIE: Ring " + str(LevelManager.current_layer) + " - Kamer " + str(LevelManager.current_room_index)
			
		# REGEL B: Als er GEEN speler is, betekent dit dat we in de SKILL TREE staan!
		else:
			# Verberg de complete StatusContainer (inclusief het hartje, schildje en de bliksem) in één klap!
			if is_instance_valid(status_container): status_container.visible = false
			if is_instance_valid(location_label): location_label.visible = false

			_update_resource_rows(_delta, false)


# Maakt een regel (kleurblokje + tekst) voor elke grondstof in de SSOT.
func _build_resource_rows() -> void:
	_resource_rows.clear()
	if not currency_container:
		return
	for child in currency_container.get_children():
		child.queue_free()
	for id in LootResources.ids():
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.alignment = BoxContainer.ALIGNMENT_BEGIN  # links uitlijnen (blok zelf staat rechtsboven)
		hbox.visible = false
		currency_container.add_child(hbox)

		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 14)
		icon.color = LootResources.color(str(id))
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)

		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(8, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)

		var lbl = Label.new()
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
		_resource_rows[str(id)] = {"row": hbox, "label": lbl}


# Werkt de grondstofregels bij: "Naam: kluis (+buit deze run)". In de skill tree alleen de kluis.
# Grondstoffen waar je 0 van hebt (en +0 deze run) worden niet getoond.
func _update_resource_rows(delta: float, in_run: bool) -> void:
	_vault_timer -= delta
	if _vault == null or _vault_timer <= 0.0:
		_vault_timer = VAULT_REFRESH_SECONDS
		if _save_sys == null:
			_save_sys = load("res://Systems/SaveSystem.gd").new()
		_vault = _save_sys.get_loaded_meta_progress() as MetaProgress
	for id in _resource_rows:
		var owned: int = _vault.get_amount(id) if _vault != null else 0
		var gained: int = RunState.get_loot(id) if in_run else 0
		var entry: Dictionary = _resource_rows[id]
		entry["row"].visible = owned > 0 or gained > 0
		var text: String = "%s: %d" % [LootResources.display_name(id), owned]
		if in_run:
			text += " (+%d)" % gained
		entry["label"].text = text


# Het SaveSystem is een RefCounted en ruimt zichzelf op.
func _exit_tree() -> void:
	_save_sys = null
