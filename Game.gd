extends Node



var entity_data: JSON

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Loading entity data")
	entity_data = load_entity_data()
	get_tree().change_scene_to_file("res://Systems/main_menu.tscn")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func load_entity_data() -> JSON:
	var file = FileAccess.open("./Data/entity_data.json", FileAccess.READ)
	if file == null:
		print("Error: Could not open file")
		return

	var json_string = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var parse_result = json.parse(json_string)

	if parse_result != OK:
		print("JSON Parse Error: ", json.get_error_message(), " at line ", json.get_error_line())
		return
	
	return json
