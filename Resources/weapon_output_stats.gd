extends Resource
class_name WeaponOutputData

@export_category("Wapen Identificatie")
# Dit ID typt het team in de Inspector en moet EXACT matchen met de 'entry_id' uit de CSV!
@export var weapon_id: String = "weapon_gatling"

@export_category("Visueel")
@export var texture: Texture2D # De sprite/afbeelding per wapen-variatie
