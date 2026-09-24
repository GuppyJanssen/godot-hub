extends CanvasLayer
# BEDIENING: HUD (Live In-Game Interface Regisseur)

@onready var currency_container: VBoxContainer = find_child("CurrencyContainer", true, false) as VBoxContainer
@onready var health_bar: ProgressBar = find_child("HealthBar", true, false) as ProgressBar
@onready var location_label: Label = find_child("LocationLabel", true, false) as Label
@onready var shield_bar: ProgressBar = find_child("ShieldBar", true, false) as ProgressBar
@onready var energy_bar: ProgressBar = find_child("EnergyBar", true, false) as ProgressBar

var player_stats: PlayerStats = null
var currency_labels: Array[Label] = []

func _ready() -> void:
	layer = 50
	
	# --- DE REDDENDE PAUZEMENU FIX ---
	# We vertellen de HUD-laag dat hij muisklikken ijskoud moet negeren en doorlaten!
	# Dit voorkomt dat de HUD het scherm gijzelt en de pauzeknoppen blokkeert.
	if currency_container:
		currency_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_find_active_player_stats()
	
	# AUTOMATISCHE GRONDSTOFFEN HUD OPBOUW
	var currencies = [
		{"name": "Olrite", "color": Color(0.0, 0.564, 0.275, 1.0)},
		{"name": "Metal", "color": Color(0.556, 0.556, 0.556, 1.0)},
		{"name": "Keepium", "color": Color(0.634, 0.022, 0.575, 1.0)},
		{"name": "Element 1", "color": Color(0.1, 0.5, 0.9, 1.0)},
		{"name": "Element 2", "color": Color(1.0, 0.85, 0.0, 1.0)},
		{"name": "Element 3", "color": Color(0.863, 0.0, 0.0, 1.0)}
	]
	
	if currency_container:
		currency_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
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


func _find_active_player_stats() -> void:
	# GECORRIGEERD: We controleren eerst of current_scene wel echt bestaat om de opstartcrash te tackelen!
	if get_tree() and get_tree().current_scene:
		var player = get_tree().current_scene.find_child("Player", true, false)
		if player and "stats" in player and player.stats:
			player_stats = player.stats
			return

	# Als we in het hoofdmenu staan of de speler laadt nog in, pakken we de veilige fallback
	player_stats = load("res://Resources/Player_Data.tres")


func _process(_delta: float) -> void:
	# Als de referentie leeg is of kwijt is door een kamerwissel, zoeken we de speler opnieuw
	if not player_stats or not is_instance_valid(player_stats):
		_find_active_player_stats()
		
	if player_stats:
		if health_bar and is_instance_valid(health_bar):
			health_bar.max_value = player_stats.max_health
			health_bar.value = player_stats.current_health
		if shield_bar and is_instance_valid(shield_bar):
			shield_bar.max_value = player_stats.max_shield
			shield_bar.value = player_stats.current_shield
		if energy_bar and is_instance_valid(energy_bar):
			energy_bar.max_value = player_stats.max_energy
			energy_bar.value = player_stats.current_energy
		
		# --- KOGELVRIJE PORTEMONNEE REFRESH (GEEN PREVIOUSLY FREED CRASHES MEER!) ---
		# GECORRIGEERD: We controleren of het EERSTE label in de array geldig is, in plaats van de array zelf!
		if currency_labels.size() >= 6 and is_instance_valid(currency_labels[0]):
			currency_labels[0].text = "Olrite: " + str(player_stats.currency_olrite)
			currency_labels[1].text = "Metal: " + str(player_stats.currency_gold)
			currency_labels[2].text = "Keepium: " + str(player_stats.currency_keepium)
			currency_labels[3].text = "Element 1: " + str(player_stats.currency_element1)
			currency_labels[4].text = "Element 2: " + str(player_stats.currency_element2)
			currency_labels[5].text = "Element 3: " + str(player_stats.currency_element3)
		
	# LOCATIE TEKST BIJWERKEN (Ook extra beveiligd op geldigheid!)
	if is_instance_valid(LevelManager) and location_label and is_instance_valid(location_label):
		if LevelManager.current_layer == 0:
			location_label.text = "LOCATIE: Zuidpool (Startbasis)"
		elif LevelManager.current_layer == LevelManager.LAYER_WIDTHS.size() - 1:
			location_label.text = "LOCATIE: Noordpool (Eindbaas-Arena)"
		else:
			location_label.text = "LOCATIE: Ring " + str(LevelManager.current_layer) + " - Kamer " + str(LevelManager.current_room_index)
