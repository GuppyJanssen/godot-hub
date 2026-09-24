extends CanvasLayer
# BEDIENING: HUD (Live In-Game Interface Regisseur)

@onready var currency_container: VBoxContainer = find_child("CurrencyContainer", true, false) as VBoxContainer
@onready var location_label: Label = find_child("LocationLabel", true, false) as Label

# TextureProgressBar koppeling voor de batterij-icoontjes
@onready var health_bar: TextureProgressBar = find_child("HealthBar", true, false) as TextureProgressBar
@onready var shield_bar: TextureProgressBar = find_child("ShieldBar", true, false) as TextureProgressBar
@onready var energy_bar: TextureProgressBar = find_child("EnergyBar", true, false) as TextureProgressBar

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
		_find_active_player()
		
	# 1. STATUS BALKEN REFRESH (Direct live gekoppeld aan de actieve speler-resource)
	if is_instance_valid(active_player_node) and active_player_node.stats:
		var p_stats = active_player_node.stats
		
		if health_bar and is_instance_valid(health_bar):
			health_bar.max_value = p_stats.max_health
			health_bar.value = p_stats.current_health
			
		if shield_bar and is_instance_valid(shield_bar):
			shield_bar.max_value = p_stats.max_shield
			shield_bar.value = p_stats.current_shield
			
		if energy_bar and is_instance_valid(energy_bar):
			energy_bar.max_value = p_stats.max_energy
			energy_bar.value = p_stats.current_energy
		
	# 2. BINGO: Live text-updates via de unieke, gescheiden array-indexen!
	if is_instance_valid(active_player_node) and currency_labels.size() >= 6:
		if is_instance_valid(currency_labels[0]): currency_labels[0].text = "Olrite: " + str(active_player_node.run_currency_olrite)
		if is_instance_valid(currency_labels[1]): currency_labels[1].text = "Metal: " + str(active_player_node.run_currency_gold)
		if is_instance_valid(currency_labels[2]): currency_labels[2].text = "Keepium: " + str(active_player_node.run_currency_keepium)
		if is_instance_valid(currency_labels[3]): currency_labels[3].text = "Element 1: " + str(active_player_node.run_currency_element1)
		if is_instance_valid(currency_labels[4]): currency_labels[4].text = "Element 2: " + str(active_player_node.run_currency_element2)
		if is_instance_valid(currency_labels[5]): currency_labels[5].text = "Element 3: " + str(active_player_node.run_currency_element3)
		
	# 3. LOCATIE TEKST BIJWERKEN
	if is_instance_valid(LevelManager) and location_label and is_instance_valid(location_label):
		if LevelManager.current_layer == 0:
			location_label.text = "LOCATIE: Zuidpool (Startbasis)"
		elif LevelManager.current_layer == LevelManager.LAYER_WIDTHS.size() - 1:
			location_label.text = "LOCATIE: Noordpool (Eindbaas-Arena)"
		else:
			location_label.text = "LOCATIE: Ring " + str(LevelManager.current_layer) + " - Kamer " + str(LevelManager.current_room_index)
