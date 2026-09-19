extends Control
class_name SkillSlot

# --- DETECTIE EN VERBINDINGEN ---
@export var parent_skill_slot: Control = null

# --- NIEUW: ONTWERP JE UPGRADE IN DE INSPECTOR ---
@export_enum("0lrite (XP)", "Gold", "Keepium", "Element 1", "Element 2", "Element 3") var currency_type: int = 0
@export var cost_per_click: int = 1

# Hoeveel punten verliest deze specifieke skill PER MINUUT in-game?
# Handig voor debuggen: zet dit op 5 of 10 om de balken sneller te zien leeglopen!
@export var points_lost_per_minute: int = 1
