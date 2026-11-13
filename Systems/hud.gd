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
var currency_labels: Array[Label] = []


func _ready() -> void:
	layer = 100
	visible = true
	
	if currency_container:
		currency_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_find_active_player()
	
	var currencies = [
		{"name": "Olrite", "color": Color(0.0, 0.564, 0.275, 1.0)},
		{"name": "Metal", "color": Color(0.556, 0.556, 0.556, 1.0)},
		{"name": "Keepium", "color": Color(0.634, 0.022, 0.575, 1.0)},
		{"name": "Element 1", "color": Color(0.1, 0.5, 0.9, 1.0)},
		{"name": "Element 2", "color": Color(1.0, 0.85, 0.0, 1.0)},
		{"name": "Element 3", "color": Color(0.863, 0.0, 0.0, 1.0)}
	]
	
	if currency_container:
		for child in currency_container.get_children():
			child.queue_free()
	
	for i in range(6):
		var hbox = HBoxContainer.new()
		hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		currency_container.add_child(hbox)
		
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 14)
		icon.color = currencies[i]["color"]
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(icon)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(8, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(spacer)
		
		var lbl = Label.new()
		lbl.text = currencies[i]["name"] + ": 0"
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(lbl)
		
		currency_labels.append(lbl)

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
			
	player_stats = load("res://Resources/Player_Data.tres")


func _process(_delta: float) -> void:
	if not is_instance_valid(active_player_node):
		# GECORRIGEERD: Vraagt de actieve player node op
		_find_active_player()
		
	# --- UNIVERSELE SSoT HUD UPDATER (Werkt in de run EN in de Skill Tree!) ---
	if is_instance_valid(Game):
		
		# REGEL A: Als de speler actief is in een run, tonen we de 'Saldo (+Winst)' HUD
		if is_instance_valid(active_player_node):
			var p = active_player_node
			var w_olrite = str(Game.get_meta("run_loot_olrite")) if Game.has_meta("run_loot_olrite") else "0"
			var w_metal  = str(Game.get_meta("run_loot_metal"))  if Game.has_meta("run_loot_metal")  else "0"
			var w_keep   = str(Game.get_meta("run_loot_keepium")) if Game.has_meta("run_loot_keepium") else "0"
			var w_elem1  = str(Game.get_meta("run_loot_element1")) if Game.has_meta("run_loot_element1") else "0"
			var w_elem2  = str(Game.get_meta("run_loot_element2")) if Game.has_meta("run_loot_element2") else "0"
			var w_elem3  = str(Game.get_meta("run_loot_element3")) if Game.has_meta("run_loot_element3") else "0"
			
			if currency_labels.size() >= 6:
				currency_labels[0].text = "Olrite: " + str(p.run_currency_olrite) + " (+" + w_olrite + ")"
				currency_labels[1].text = "Metal: " + str(p.run_currency_metal) + " (+" + w_metal + ")"
				currency_labels[2].text = "Keepium: " + str(p.run_currency_keepium) + " (+" + w_keep + ")"
				currency_labels[3].text = "Element 1: " + str(p.run_currency_element1) + " (+" + w_elem1 + ")"
				currency_labels[4].text = "Element 2: " + str(p.run_currency_element2) + " (+" + w_elem2 + ")"
				currency_labels[5].text = "Element 3: " + str(p.run_currency_element3) + " (+" + w_elem3 + ")"
				
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
				if LevelManager.current_layer == 0:
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

			# Laad de permanente Meta Progress database in voor de Skill Tree weergave
			var save_sys = load("res://Systems/SaveSystem.gd").new()
			if save_sys and save_sys.has_method("get_loaded_meta_progress"):
				var meta = save_sys.get_loaded_meta_progress()
				if meta and currency_labels.size() >= 6:
					var m_olrite = meta.currency_olrite if "currency_olrite" in meta else (meta.currency_1 if "currency_1" in meta else 0)
					var m_metal  = meta.currency_metal if "currency_metal" in meta else (meta.currency_2 if "currency_2" in meta else 0)
					var m_keep   = meta.currency_keepium if "currency_keepium" in meta else (meta.currency_3 if "currency_3" in meta else 0)
					var m_elem1  = meta.currency_element1 if "currency_element1" in meta else (meta.currency_4 if "currency_4" in meta else 0)
					var m_elem2  = meta.currency_element2 if "currency_element2" in meta else (meta.currency_5 if "currency_5" in meta else 0)
					var m_elem3  = meta.currency_element3 if "currency_element3" in meta else (meta.currency_6 if "currency_6" in meta else 0)
					
					# Schrijf de waarden nu loepzuiver met index-verwijzingen naar de 6 losse regels
					currency_labels[0].text = "Olrite: " + str(m_olrite)
					currency_labels[1].text = "Metal: " + str(m_metal)
					currency_labels[2].text = "Keepium: " + str(m_keep)
					currency_labels[3].text = "Element 1: " + str(m_elem1)
					currency_labels[4].text = "Element 2: " + str(m_elem2)
					currency_labels[5].text = "Element 3: " + str(m_elem3)
