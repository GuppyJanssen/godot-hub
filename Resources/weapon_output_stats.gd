extends Resource
class_name WeaponOutputStats # Registreert dit type bestand binnen heel Godot

# --- KOGEL VARIATIES ---
@export var speed: float = 700.0         # Snelheid in pixels per seconde
@export var size_multiplier: float = 1.0  # Schaal van de kogel (1.0 = normaal, 2.0 = dubbel zo groot)
@export var damage: int = 10              # Hoeveel schade deze specifieke kogel doet
@export var firerate: int = 1
@export var texture: Texture2D            # De sprite/afbeelding (bepaalt het uiterlijk per variatie)

# --- UITGEBREIDE VARIATIES (VOOR LATER) ---
# Hier kunnen jullie later moeiteloos dingen toevoegen zoals:
# @export var pierce_count: int = 1     # Hoe vaak de kogel door vijanden heen mag gaan
# @export var behavior_type: String = "straight" # Bijv. "straight", "sine_wave", "homing", "boomerang"
