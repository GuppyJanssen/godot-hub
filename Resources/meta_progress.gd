extends Resource
class_name MetaProgress

# --- DE KLUIS: grondstoffen en currencies die je houdt na een run ---
## id uit de SSOT (olrite, metal, biomass ...) -> aantal. Zie LootResources.
@export var resources: Dictionary = {}

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

# --- VOORTGANG VAN DEZE SAVE ---
## Hoe vaak de boss in deze save verslagen is. Bepaalt later hoe groot de wereld wordt
## (base_world_triangles, wins_per_extra_triangle, max_world_triangles). In te stellen in F1 vóór de run.
@export var boss_wins: int = 0


func get_amount(id: String) -> int:
	return int(resources.get(id, 0))


func add_amount(id: String, amount: int) -> void:
	if id == "":
		return
	resources[id] = maxi(0, get_amount(id) + amount)


## Haalt 'amount' van 'id' af als er genoeg is. Geeft false (en verandert niets) als het niet past.
func try_spend(id: String, amount: int) -> bool:
	if amount < 0 or get_amount(id) < amount:
		return false
	resources[id] = get_amount(id) - amount
	return true


# FUTURE-PROOF SLOT: Hier kunnen jullie later makkelijk extra meta-progressie kwijt, zoals:
# @export var unlocked_skins: Array[String] = []
# @export var highscore_minutes: float = 0.0
