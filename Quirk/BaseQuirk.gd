extends Node

@abstract class BaseQuirk:
	var trigger: Trigger
	var effect
	
	func _init() -> void:
		pass

@abstract class Trigger:
	func _init() -> void:
		pass
		
	func trigger() -> void:
		pass

@abstract class Effect:
	func _init() -> void:
		pass
	
	func check_condition() -> bool:
		return false
