class_name LootResources
## LootResources – de lijst met grondstoffen en currencies, uit de SSOT.
##
## Elke rij in de SSOT met data_type "loot" is een grondstof (olrite, metal, biomass, cryo ...).
## Een nieuwe grondstof is dus alleen een nieuwe rij; de code hoeft niet aangepast te worden.
## Kolommen die deze lijst gebruikt:
##   ingame_name         naam in de HUD en de skill tree
##   resource_kind       "grondstof" (ligt als blokje, klontert) of "currency" (Keepium, tokens)
##   rarity_tier         1 t/m 10 (alleen ter info, nog niet gebruikt in de code)
##   resource_color      kleur als hex, bijvoorbeeld #00904A. Leeg = de kleur uit DEFAULT_COLORS.
##   loot_chunk_small    zoveel stuks worden samen een klompje (cirkel). Leeg = klontert niet.
##   loot_chunk_large    zoveel stuks worden samen een steen (ster). Leeg = geen steen.
##
## Waar de aantallen staan:
##   - de kluis (blijft na de run): MetaProgress.resources, id -> aantal
##   - de buit van deze run (de "+"-tellers): RunState.loot, id -> aantal
## Aan het eind van een run (dood, opgeven, nieuwe run) gaat de buit naar de kluis: bank_run_loot().
##
## Ontwikkelaarsnotitie: oude saves gebruikten nummers (1 = olrite ... 6 = element 3) en de namen
## element_1/element1. normalize() zet die om naar de nieuwe id's.

const LOOT_TYPE := "loot"
## Zonder SSOT-rijen: deze drie.
const FALLBACK_IDS: Array = ["olrite", "metal", "keepium"]
## Volgorde van de oude vaste lijst (currency_1 ... currency_6 en loot-nummer 1 ... 6).
const LEGACY_ORDER: Array = ["olrite", "metal", "keepium", "biomass", "circuitry", "crystal"]
## Oude namen die nu anders heten.
const LEGACY_NAMES := {
	"element_1": "biomass", "element1": "biomass",
	"element_2": "circuitry", "element2": "circuitry",
	"element_3": "crystal", "element3": "crystal",
}
## Kleuren zolang resource_color in de SSOT leeg is.
const DEFAULT_COLORS := {
	"olrite": Color(0.0, 0.564, 0.275),
	"metal": Color(0.556, 0.556, 0.556),
	"keepium": Color(0.634, 0.022, 0.575),
	"biomass": Color(0.45, 0.75, 0.2),
	"circuitry": Color(0.1, 0.5, 0.9),
	"crystal": Color(1.0, 0.85, 0.0),
	"cryo": Color(0.6, 0.9, 1.0),
	"arc_coil": Color(0.55, 0.45, 1.0),
	"thermion": Color(1.0, 0.45, 0.1),
	"isotope": Color(0.7, 1.0, 0.3),
	"neutronium_core": Color(0.35, 0.3, 0.5),
	"void_shard": Color(0.5, 0.1, 0.6),
}


## Alle grondstoffen in de volgorde van de SSOT.
static func ids() -> Array:
	var result: Array = Ssot.get_ids(LOOT_TYPE)
	return result if not result.is_empty() else FALLBACK_IDS.duplicate()


static func exists(id: String) -> bool:
	return ids().has(id)


## Zet een oude naam of een oud nummer om naar een id ("element_1" -> "biomass", 2 -> "metal").
## Onbekend: "" (en een waarschuwing).
static func normalize(value: Variant) -> String:
	if value is int or value is float:
		var index: int = int(value) - 1
		if index >= 0 and index < LEGACY_ORDER.size():
			return LEGACY_ORDER[index]
		return ""
	var text: String = str(value).strip_edges().to_lower().replace(" ", "_")
	text = LEGACY_NAMES.get(text, text)
	if text.is_valid_int():
		return normalize(text.to_int())
	return text


static func display_name(id: String) -> String:
	return Ssot.get_text(id, "ingame_name", id.capitalize())


static func color(id: String) -> Color:
	var hex: String = Ssot.get_text(id, "resource_color", "").strip_edges()
	if hex != "" and Color.html_is_valid(hex):
		return Color.html(hex)
	if DEFAULT_COLORS.has(id):
		return DEFAULT_COLORS[id]
	# Onbekende grondstof: een vaste kleur op basis van de naam.
	return Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.6, 0.9)


static func is_currency(id: String) -> bool:
	return Ssot.get_text(id, "resource_kind", "").strip_edges().to_lower() == "currency"


## x = klompje (cirkel), y = steen (ster). 0 = niet.
static func chunk_sizes(id: String) -> Vector2i:
	return Vector2i(Ssot.get_int(id, "loot_chunk_small", 0), Ssot.get_int(id, "loot_chunk_large", 0))


## Zet de buit van deze run in de kluis en slaat de kluis op. RunState.loot blijft staan;
## RunState.end_run() of start_new_run() wist die daarna.
static func bank_run_loot() -> void:
	if RunState.loot.is_empty():
		return
	var save_system = load("res://Systems/SaveSystem.gd").new()
	var meta: MetaProgress = save_system.get_loaded_meta_progress() as MetaProgress
	if meta != null:
		for id in RunState.loot:
			meta.add_amount(str(id), int(RunState.loot[id]))
		save_system.save_meta_progress(meta)
		print("KLUIS: run-buit gestort: ", RunState.loot)
