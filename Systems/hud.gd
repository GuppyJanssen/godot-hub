extends CanvasLayer

@onready var currency_container: VBoxContainer = find_child("CurrencyContainer", true, false) as VBoxContainer
@onready var health_bar: ProgressBar = find_child("HealthBar", true, false) as ProgressBar
@onready var location_label: Label = find_child("LocationLabel", true, false) as Label
@onready var shield_bar: ProgressBar = find_child("ShieldBar", true, false) as ProgressBar
@onready var energy_bar: ProgressBar = find_child("EnergyBar", true, false) as ProgressBar

var player_stats: PlayerStats = null
var currency_labels: Array[Label] = []

func _ready() -> void:
	layer = 50
	player_stats = load("res://Resources/Player_Data.tres")
	
	# AUTOMATISCHE GRONDSTOFFEN HUD OPBOUW
	var currencies = [
		{"name": "Olrite", "color": Color(0.0, 0.564, 0.275, 1.0)},
		{"name": "Metal", "color": Color(0.556, 0.556, 0.556, 1.0)},
		{"name": "Keepium", "color": Color(0.634, 0.022, 0.575, 1.0)},
		{"name": "Element 1", "color": Color(0.1, 0.5, 0.9, 1.0)},
		{"name": "Element 2", "color": Color(1.0, 0.85, 0.0, 1.0)},
		{"name": "Element 3", "color": Color(0.863, 0.0, 0.0, 1.0)}
	]
	
	for i in range(6):
		var hbox = HBoxContainer.new()
		currency_container.add_child(hbox)
		
		var icon = ColorRect.new()
		icon.custom_minimum_size = Vector2(16, 14) # Iets breder gemaakt voor het grotere font
		icon.color = currencies[i]["color"]
		hbox.add_child(icon)
		
		var spacer = Control.new()
		spacer.custom_minimum_size = Vector2(8, 0)
		hbox.add_child(spacer)
		
		var lbl = Label.new()
		lbl.text = currencies[i]["name"] + ": 0"
		
		# --- GLOEDNIEUW: MAAK HET LETTERTYPE VAN DE CURRENCIES GROTER ---
		lbl.add_theme_font_size_override("font_size", 20) # Verhoog naar 20 (of 22) voor perfecte leesbaarheid!
		
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		hbox.add_child(lbl)
		
		currency_labels.append(lbl)


func _process(_delta: float) -> void:
	if player_stats:
		if health_bar:
			health_bar.max_value = player_stats.max_health
			health_bar.value = player_stats.current_health
		if shield_bar:
			shield_bar.max_value = player_stats.max_shield
			shield_bar.value = player_stats.current_shield
		if energy_bar:
			energy_bar.max_value = player_stats.max_energy
			energy_bar.value = player_stats.current_energy
		
		# Portemonnee refresh loopt mathematisch perfect mee
		currency_labels[0].text = "Olrite: " + str(player_stats.currency_olrite)
		currency_labels[1].text = "Metal: " + str(player_stats.currency_gold)
		currency_labels[2].text = "Keepium: " + str(player_stats.currency_keepium)
		currency_labels[3].text = "Element 1: " + str(player_stats.currency_element1)
		currency_labels[4].text = "Element 2: " + str(player_stats.currency_element2)
		currency_labels[5].text = "Element 3: " + str(player_stats.currency_element3)
		
	if is_instance_valid(LevelManager):
		if LevelManager.current_layer == 0:
			location_label.text = "LOCATIE: Zuidpool (Startbasis)"
		elif LevelManager.current_layer == LevelManager.LAYER_WIDTHS.size() - 1:
			location_label.text = "LOCATIE: Noordpool (Eindbaas-Arena)"
		else:
			location_label.text = "LOCATIE: Ring " + str(LevelManager.current_layer) + " - Kamer " + str(LevelManager.current_room_index)
