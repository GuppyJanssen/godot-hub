extends Resource
class_name MetaProgress

# --- PERMANENTE VOORTGANG (ROGUELIKE META) ---
# Deze twee variabelen slaan jullie totale progressie over alle runs heen op
@export var total_xp: int = 0
@export var currency_1: int = 0  # Bijv. XP
@export var currency_2: int = 0  # Bijv. Run-Goud
@export var currency_3: int = 0  # Bijv. Boss Tokens

# Hier kunnen jullie in de toekomst heel makkelijk extra dingen aan toevoegen, zoals:
# @export var unlocked_weapons: Array[String] = []
# @export var current_level: int = 1


# --- SKILL TREE PROGRESSIE ---
# We houden per vaardigheid het actuele niveau bij (0 = leeg, 4 = 100% vol)
@export var skill_1_level: int = 0
@export var skill_2_level: int = 0  # Dit is het opvolgende blokje dat pas later verschijnt!
