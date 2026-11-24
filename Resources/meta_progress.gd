extends Resource
class_name MetaProgress

# --- PERMANENTE BANKREKENING (De 6 echte sci-fi grondstoffen) ---
@export var currency_1: int = 0 # Olrite
@export var currency_2: int = 0 # Metal
@export var currency_3: int = 0 # Keepium
@export var currency_4: int = 0 # Element 1
@export var currency_5: int = 0 # Element 2
@export var currency_6: int = 0 # Element 3

# --- UNIVERSELE DATA-DRIVEN UPGRADELIJST ---
# BINGO: Hierin slaan we ALLES dynamic op!
# Structuur op de harde schijf wordt: {"skill_id_uit_csv": actueel_level_getal}
# Dit is oneindig uitbreidbaar via de Google Spreadsheet zonder dit script ooit aan te passen!
@export var skills_data: Dictionary = {}

# --- SKILL TREE PER SAVE ---
## Bepaalt waar de takken van de skill tree staan. Wordt één keer gekozen (bij de eerste keer
## openen van de skill tree in deze save) en verandert daarna niet meer. 0 = nog niet gekozen.
@export var tree_seed: int = 0
## Skills die ooit gekocht zijn in deze save. Die zie je in de boom; de rest is een zwart vakje.
## Blijft staan, ook als de skill door verval weer op 0 komt.
@export var discovered_skills: Array = []


# FUTURE-PROOF SLOT: Hier kunnen jullie later makkelijk extra meta-progressie kwijt, zoals:
# @export var unlocked_skins: Array[String] = []
# @export var highscore_minutes: float = 0.0
