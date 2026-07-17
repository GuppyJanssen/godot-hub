extends GameEntity

func _init(entity_data: JSON):
	entity_type = "meteor"
	super._init(entity_data) # call parent to load data
