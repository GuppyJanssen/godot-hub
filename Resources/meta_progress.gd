extends Resource
class_name MetaProgress

# --- PERMANENTE CURRENCIES ---
@export var currency_1: int = 0
@export var currency_2: int = 0
@export var currency_3: int = 0
@export var currency_4: int = 0
@export var currency_5: int = 0
@export var currency_6: int = 0

# --- UNIVERSELE SKILL TREE OPZAKLIJST ---
# Hierin wordt automatisch opgeslagen: {"Upgrade 1": 2, "Upgrade 2": 4, "Upgrade 3": 0, ...}
@export var skills_data: Dictionary = {}




# Hier kunnen jullie in de toekomst heel makkelijk extra dingen aan toevoegen, zoals:
# @export var unlocked_weapons: Array[String] = []
# @export var current_level: int = 1


# --- SKILL TREE PROGRESSIE ---
# We houden per vaardigheid het actuele niveau bij (0 = leeg, 4 = 100% vol)
@export var skill_1_level: int = 0
@export var skill_2_level: int = 0  # Dit is het opvolgende blokje dat pas later verschijnt!
