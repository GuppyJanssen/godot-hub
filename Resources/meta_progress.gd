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


# FUTURE-PROOF SLOT: Hier kunnen jullie later makkelijk extra meta-progressie kwijt, zoals:
# @export var unlocked_skins: Array[String] = []
# @export var highscore_minutes: float = 0.0
