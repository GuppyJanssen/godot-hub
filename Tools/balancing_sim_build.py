"""Bouwt de balancing-simulatie als .xlsx (formules), uit de SSOT-CSV."""
import csv, sys
from openpyxl import Workbook
from openpyxl.utils import get_column_letter as L
from openpyxl.styles import Font, PatternFill, Alignment
from openpyxl.worksheet.formula import ArrayFormula

SRC = sys.argv[1]
OUT = sys.argv[2]
rows = list(csv.reader(open(SRC, encoding='utf-8')))
H = rows[0]

def num(v):
    try:
        return float(v) if '.' in v or 'e' in v.lower() else int(v)
    except ValueError:
        return v

UNIT_TYPES = ['player_base_stats', 'unit_type', 'faction', 'enemy_override']
unit_rows = [x for t in UNIT_TYPES for x in rows if len(x) > 2 and x[2] == t]
weapon_rows = [x for x in rows if len(x) > 2 and x[2] == 'weapon_base']

def used_cols(rs, must):
    cols = [k for k in range(len(H)) if k < 3 or any(x[k] for x in rs) or H[k] in must]
    return cols

UNIT_MUST = ['max_health', 'max_health_modifier', 'base_health_regen', 'health_regen_modifier', 'max_shield',
             'shield_regen_amount', 'shield_regen_delay', 'base_speed', 'speed_modifier', 'base_damage',
             'base_damage_type', 'damage_type_modifier', 'uses_weapon', 'weapon_fire_interval_factor',
             'weapon_pool', 'base_explosion_damage', 'base_explosion_radius', 'behavior_agro',
             'behavior_kamikaze_trigger']
WEAPON_MUST = ['base_damage', 'base_damage_type', 'base_fire_rate', 'fire_rate_modifier', 'base_fire_range',
               'fire_range_modifier', 'base_burst_count', 'burst_count_modifier', 'base_muzzle_count',
               'muzzle_count_modifier', 'base_explosion_damage']

wb = Workbook()
HEAD_FILL = PatternFill('solid', fgColor='F3F3F3')
BOLD = Font(bold=True)
TITLE = Font(bold=True, size=13)

def header(ws, row, col, names):
    for i, n in enumerate(names):
        c = ws.cell(row=row, column=col + i, value=n)
        c.fill = HEAD_FILL
        c.font = BOLD

def sort_cols(cols):
    # entry_id eerst (kolom A), dan de rest in SSOT-volgorde.
    eid = H.index('entry_id')
    return [eid] + [k for k in cols if k != eid]

# ---------- 1. Units (SSOT) ----------
ws = wb.active
ws.title = 'Units'
ucols = sort_cols(used_cols(unit_rows, UNIT_MUST))
header(ws, 1, 1, [H[k] for k in ucols])
for i, x in enumerate(unit_rows):
    for j, k in enumerate(ucols):
        v = x[k] if k < len(x) else ''
        if v != '':
            ws.cell(row=2 + i, column=1 + j, value=num(v))
UNIT_LAST_COL = L(len(ucols) + 40)   # ruimte voor geplakte kolommen
U_RANGE = f"Units!$A$1:${UNIT_LAST_COL}$400"
U_IDS = "Units!$A$1:$A$400"
U_HEAD = f"Units!$A$1:${UNIT_LAST_COL}$1"
ws.freeze_panes = 'B2'

# ---------- 2. Wapens (SSOT) ----------
ww = wb.create_sheet('Wapens')
wcols = sort_cols(used_cols(weapon_rows, WEAPON_MUST))
names = [H[k] for k in wcols]
header(ww, 1, 1, names + ['gebruikt_door'])
pool_col = L(ucols.index(H.index('weapon_pool')) + 1)
name_col = L(ucols.index(H.index('ingame_name')) + 1)
for i, x in enumerate(weapon_rows):
    r = 2 + i
    for j, k in enumerate(wcols):
        v = x[k] if k < len(x) else ''
        if v != '':
            ww.cell(row=r, column=1 + j, value=num(v))
    cell = f"{L(len(names) + 1)}{r}"
    ww[cell] = ArrayFormula(cell, f'=_xlfn.TEXTJOIN(", ",TRUE,IF(ISNUMBER(SEARCH("/"&A{r}&"/","/"&Units!${pool_col}$2:${pool_col}$400&"/")),Units!${name_col}$2:${name_col}$400,""))')
W_LAST = L(len(names) + 40)
W_RANGE = f"Wapens!$A$1:${W_LAST}$300"
W_IDS = "Wapens!$A$1:$A$300"
W_HEAD = f"Wapens!$A$1:${W_LAST}$1"
ww.freeze_panes = 'B2'

def U(row_expr, col):
    """Cel uit Units op rij-id en kolomnaam (tekst of getal)."""
    return f'INDEX({U_RANGE},MATCH({row_expr},{U_IDS},0),MATCH("{col}",{U_HEAD},0))'

def UN(row_expr, col, default=0):
    return f'IFERROR(N({U(row_expr, col)}),{default})'

def UHAS(row_expr, col):
    return f'IFERROR(LEN({U(row_expr, col)}&"")>0,FALSE)'

def UT(row_expr, col):
    return f'IFERROR({U(row_expr, col)}&"","")'

def W(id_expr, col, default=0):
    return f'IFERROR(N(INDEX({W_RANGE},MATCH({id_expr},{W_IDS},0),MATCH("{col}",{W_HEAD},0))),{default})'

def WT(id_expr, col):
    return f'IFERROR(INDEX({W_RANGE},MATCH({id_expr},{W_IDS},0),MATCH("{col}",{W_HEAD},0))&"","")'

def WSTAT(id_expr, stat, default=0):
    """base_<stat> x (1 + <stat>_modifier), zoals StatCalc.value."""
    return f'({W(id_expr, "base_" + stat, default)}*(1+{W(id_expr, stat + "_modifier", 0)}))'

def NORM(t):
    """Eén naam per damage type: leeg/physical = kinetic, corrosive = acid."""
    return f'SUBSTITUTE(SUBSTITUTE(IF(TRIM(LOWER({t}))="","kinetic",TRIM(LOWER({t}))),"physical","kinetic"),"corrosive","acid")'

def RESIST(dtype, text):
    """Factor uit 'type:factor/type:factor' (damage_type_modifier). Niet genoemd = 1."""
    key = f'({dtype}&":")'
    pos = f'SEARCH({key},"/"&{text})'
    # zoek met een / ervoor zodat "acid" niet in "xacid" valt
    key2 = f'("/"&{dtype}&":")'
    pos2 = f'SEARCH({key2},"/"&SUBSTITUTE({text}," ",""))'
    start = f'({pos2}+LEN({key2}))'
    src = f'("/"&SUBSTITUTE({text}," ","")&"/")'
    return f'IFERROR(VALUE(MID({src},{start},FIND("/",{src},{start})-{start})),1)'

# ---------- Teams (invoer + aannames) ----------
wt = wb.create_sheet('Teams')
wt['A1'] = 'Aannames en instellingen (pas gerust aan)'
wt['A1'].font = TITLE
assumptions = [
    ('Doelwitkeuze', 'dichtstbij, zwakkere dichtbij', 'dichtstbij, zwakkere dichtbij = het dichtstbijzijnde doel, maar komt er een zwakkere binnen de wisselafstand, dan die. Verder: dichtstbijzijnde / zwakste / eerste (het eerste levende doel in de lijst).'),
    ('Tijdstap (s)', 0.1, 'Hoe fijn het gevecht wordt doorgerekend. Het tabblad Gevecht heeft 200 stappen: met 0,1 s is dat 20 seconden, met 0,2 s 40 seconden.'),
    ('Maximale duur (s)', 20, 'Daarna stopt de simulatie (maximaal 200 × tijdstap).'),
    ('Startafstand tussen de teams (px)', 800, 'Team A begint op 0, team B op deze afstand. Iedereen vliegt naar zijn doel tot het binnen bereik is.'),
    ('Aanraakschade: seconden tussen treffers', 1.0, 'Units zonder wapen (uses_weapon leeg) doen base_damage per aanraking.'),
    ('Aanraakbereik (px)', 60, 'Afstand waarop aanraakschade telt.'),
    ('Vuurtempo-factor vijanden als leeg', 2.0, 'weapon_fire_interval_factor: vijanden schieten zoveel keer trager dan de speler met hetzelfde wapen (EnemyGun).'),
    ('Wapen van de speler (standaard)', 'weapon_pistol', 'Voor de speler in de matrix en in een team als je daar geen wapen kiest.'),
    ('Wapen van een vijand', 'eerste uit weapon_pool', 'In het spel kiest een commando willekeurig uit de pool; hier het eerste (weinig toeval). Per teamplek kun je een ander wapen kiezen.'),
    ('Raken', 'alles raakt', 'Geen missers, geen spreiding, kogels zijn er meteen (geen vliegtijd).'),
    ('Ontploffingen', 'één doel', 'base_explosion_damage telt bij de schade per schot op, maar raakt alleen het doelwit (geen gebiedsschade).'),
    ('Kamikaze', 'eenmalig', 'Vijand met behavior_agro "kamikaze": ontploft één keer (base_explosion_damage) binnen behavior_kamikaze_trigger en is dan dood.'),
    ('Groepen', 'gedeelde levens', 'Elke teamplek is een groep: de levens van de groep worden samen opgeteld en units vallen één voor één af (eerst vol op één unit). Schild en schildherstel tellen per levende unit.'),
    ('Skills en items', 'niet meegeteld', 'Alleen de waarden uit de SSOT (StatCalc.value), zonder skills van de speler.'),
    ('Wisselafstand (px)', 150, 'Bij "dichtstbij, zwakkere dichtbij": een doel dat hooguit zoveel verder weg is dan het dichtstbijzijnde telt ook mee; daarvan het zwakste (minste levens).'),
    ('Communicatievertraging (s)', '=IFERROR(N(INDEX(Units!$A:$ZZ,MATCH("world",Units!$A:$A,0),MATCH("alarm_communication_delay",Units!$1:$1,0))),2)', 'Uit de SSOT (alarm_communication_delay). Een unit wordt actief als hij zelf een vijand ziet (behavior_scan_radius), geraakt wordt, of een teamgenoot al zo lang actief is. Uitzondering: alarm_instant_from (bijv. organic grunt van heavy en toren) = meteen.'),
    ('Speler', 'altijd actief', 'De speler hoeft niets te zien of te horen.'),
    ('Spore-wolkje', 'niet meegeteld', 'Het corrosive wolkje na een kamikaze zit nog niet in de simulatie.'),
]
wt['A2'] = 'Instelling'; wt['B2'] = 'Waarde'; wt['C2'] = 'Uitleg'
for c in ('A2', 'B2', 'C2'):
    wt[c].font = BOLD; wt[c].fill = HEAD_FILL
for i, (a, b, c) in enumerate(assumptions):
    wt.cell(row=3 + i, column=1, value=a)
    wt.cell(row=3 + i, column=2, value=b)
    wt.cell(row=3 + i, column=3, value=c)
SWITCH_RANGE = "Teams!$B$17"; COMM_DELAY = "Teams!$B$18"
RULE = "Teams!$B$3"; DT = "Teams!$B$4"; TMAX = "Teams!$B$5"; DIST = "Teams!$B$6"
CONTACT_INT = "Teams!$B$7"; CONTACT_RANGE = "Teams!$B$8"; ENEMY_FACTOR = "Teams!$B$9"; PLAYER_WEAPON = "Teams!$B$10"

TEAM_ROW = 3 + len(assumptions) + 2
wt.cell(row=TEAM_ROW, column=1, value='Teams').font = TITLE
header(wt, TEAM_ROW + 1, 1, ['Plek', 'Unit', 'Aantal', 'Wapen (leeg = standaard)'])
SLOTS = ['A1', 'A2', 'A3', 'B1', 'B2', 'B3']
defaults = {'A1': ('Speler', 1, ''), 'A2': ('', 0, ''), 'A3': ('', 0, ''),
            'B1': ('Organic light', 3, ''), 'B2': ('Mech medium', 1, ''), 'B3': ('', 0, '')}
slot_row = {}
for i, s in enumerate(SLOTS):
    r = TEAM_ROW + 2 + i
    slot_row[s] = r
    u, n, w = defaults[s]
    wt.cell(row=r, column=1, value=s)
    wt.cell(row=r, column=2, value=u or None)
    wt.cell(row=r, column=3, value=n)
    wt.cell(row=r, column=4, value=w or None)
wt.column_dimensions['A'].width = 38
wt.column_dimensions['B'].width = 24
wt.column_dimensions['C'].width = 110

# ---------- WarEra (berekend uit Units + Wapens) ----------
wsj = wb.create_sheet('WarEra')
# Maximaal 14 facties (de keuzelijst in Teams heeft plek voor 99 units; past ook binnen de grootte van een Sheet).
factions = [x for x in rows if len(x) > 2 and x[2] == 'faction'][:14]
types = [x for x in rows if len(x) > 2 and x[2] == 'unit_type']
SJ_COLS = ['naam', 'factie', 'unit_type', 'type_row', 'enemy_row', 'max_health', 'max_shield',
           'shield_regen_amount', 'shield_regen_delay', 'health_regen', 'speed', 'base_damage',
           'uses_weapon', 'weapon', 'kamikaze', 'damage_type_modifier', 'attack_damage', 'attack_interval',
           'attack_range', 'attack_damage_type', 'health_plus_shield', 'dps', 'behavior_scan_radius', 'alarm_instant_from']
header(wsj, 1, 1, SJ_COLS)
C = {n: L(i + 1) for i, n in enumerate(SJ_COLS)}
entries = [('Speler', 'player', 'player')]
for f in factions:
    for t in types:
        tname = t[1].replace('unit_', '')
        entries.append((f"{f[0]} {tname}", f[1], tname))

def stat_enemy(r, base, mod, fallback=0):
    """EnemyStats.value: eigen vijand-rij, anders type-basis x (1 + type_mod + factie_mod)."""
    own, typ, fac = f'$E{r}', f'$D{r}', f'$B{r}'
    own_has = f'OR({UHAS(own, base)})'
    return (f'IF($B{r}="player",{UN(chr(34)+"player_base"+chr(34), base, fallback)}*(1+{UN(chr(34)+"player_base"+chr(34), mod)}),'
            f'IF({own_has},{UN(own, base, fallback)}*(1+{UN(own, mod)}),'
            f'IF({UHAS(typ, base)},{UN(typ, base, fallback)}*(1+{UN(typ, mod)}+{UN(fac, mod)}),{fallback})))')

def text_enemy(r, col, fallback=''):
    own, typ, fac = f'$E{r}', f'$D{r}', f'$B{r}'
    q = chr(34)
    return (f'IF($B{r}="player",{UT(q+"player_base"+q, col)},'
            f'IF({UHAS(own, col)},{UT(own, col)},IF({UHAS(fac, col)},{UT(fac, col)},IF({UHAS(typ, col)},{UT(typ, col)},"{fallback}"))))')

def weapon_attack(r, w_expr, factor_expr):
    dmg = f'(({WSTAT(w_expr, "damage")})+{W(w_expr, "base_explosion_damage")})*MAX(1,ROUND({WSTAT(w_expr, "burst_count", 1)},0))*MAX(1,ROUND({WSTAT(w_expr, "muzzle_count", 1)},0))'
    interval = f'MAX(0.05,{WSTAT(w_expr, "fire_rate", 0.5)})*{factor_expr}'
    rng = f'{WSTAT(w_expr, "fire_range", 300)}'
    dtype = NORM(WT(w_expr, "base_damage_type"))
    return dmg, interval, rng, dtype

for i, (name, fac, tname) in enumerate(entries):
    r = 2 + i
    wsj[f'A{r}'] = name
    wsj[f'B{r}'] = fac
    wsj[f'C{r}'] = tname
    if fac == 'player':
        wsj[f'D{r}'] = 'player_base'
        wsj[f'E{r}'] = 'player_base'
    else:
        wsj[f'D{r}'] = f'="unit_"&C{r}'
        key = f'LOWER(SUBSTITUTE({UT("B"+str(r), "ingame_name")}," ",""))'
        wsj[f'E{r}'] = f'=IF(ISNUMBER(MATCH("enemy_"&{key}&"_"&C{r},{U_IDS},0)),"enemy_"&{key}&"_"&C{r},"enemy_"&SUBSTITUTE(B{r},"faction_","")&"_"&C{r})'
    wsj[f'F{r}'] = '=' + stat_enemy(r, 'max_health', 'max_health_modifier', 1)
    wsj[f'G{r}'] = '=' + stat_enemy(r, 'max_shield', 'max_shield_modifier', 0)
    wsj[f'H{r}'] = '=' + stat_enemy(r, 'shield_regen_amount', 'shield_regen_amount_modifier', 0)
    wsj[f'I{r}'] = '=' + stat_enemy(r, 'shield_regen_delay', 'shield_regen_delay_modifier', 3)
    wsj[f'J{r}'] = '=' + stat_enemy(r, 'base_health_regen', 'health_regen_modifier', 0)
    wsj[f'K{r}'] = '=' + stat_enemy(r, 'base_speed', 'speed_modifier', 0)
    wsj[f'L{r}'] = '=' + stat_enemy(r, 'base_damage', 'damage_modifier', 0)
    if fac == 'player':
        wsj[f'M{r}'] = 1
        wsj[f'N{r}'] = f'={PLAYER_WEAPON}'
        wsj[f'O{r}'] = 0
    else:
        wsj[f'M{r}'] = '=IF(' + stat_enemy(r, 'uses_weapon', 'uses_weapon_modifier', 0) + '>0,1,0)'
        pool = text_enemy(r, 'weapon_pool')
        wsj[f'N{r}'] = f'=IF(M{r}=1,IFERROR(LEFT({pool},FIND("/",{pool}&"/")-1),""),"")'
        wsj[f'O{r}'] = f'=IF(LOWER({text_enemy(r, "behavior_agro")})="kamikaze",1,0)'
    wsj[f'P{r}'] = '=' + text_enemy(r, 'damage_type_modifier')
    factor = '1' if fac == 'player' else f'IF({UHAS("$E"+str(r), "weapon_fire_interval_factor")},{UN("$E"+str(r), "weapon_fire_interval_factor")},IF({UHAS("$D"+str(r), "weapon_fire_interval_factor")},{UN("$D"+str(r), "weapon_fire_interval_factor")},{ENEMY_FACTOR}))'
    dmg, interval, rng, dtype = weapon_attack(r, f'$N{r}', factor)
    kami_dmg = stat_enemy(r, 'base_explosion_damage', 'explosion_damage_modifier', 0)
    kami_rng = stat_enemy(r, 'behavior_kamikaze_trigger', 'behavior_kamikaze_trigger_modifier', 40)
    contact_type = NORM(text_enemy(r, 'base_damage_type', 'kinetic'))
    wsj[f'Q{r}'] = f'=IF(O{r}=1,{kami_dmg},IF(AND(M{r}=1,N{r}<>""),{dmg},L{r}))'
    wsj[f'R{r}'] = f'=IF(O{r}=1,{DT},IF(AND(M{r}=1,N{r}<>""),{interval},{CONTACT_INT}))'
    wsj[f'S{r}'] = f'=IF(O{r}=1,{kami_rng},IF(AND(M{r}=1,N{r}<>""),{rng},{CONTACT_RANGE}))'
    wsj[f'T{r}'] = f'=IF(AND(O{r}=0,M{r}=1,N{r}<>""),{dtype},{contact_type})'
    wsj[f'U{r}'] = f'=F{r}+G{r}'
    wsj[f'V{r}'] = f'=IF(O{r}=1,0,IF(R{r}>0,Q{r}/R{r},0))'
    wsj[f'W{r}'] = 99999 if fac == 'player' else '=' + stat_enemy(r, 'behavior_scan_radius', 'behavior_scan_radius_modifier', 0)
    wsj[f'X{r}'] = '' if fac == 'player' else '=' + text_enemy(r, 'alarm_instant_from')
SJ_N = len(entries) + 1
wsj.freeze_panes = 'B2'
wsj.column_dimensions['A'].width = 22

def SJ(name_expr, col):
    return f'INDEX(WarEra!${C[col]}$2:${C[col]}${SJ_N},MATCH({name_expr},WarEra!$A$2:$A${SJ_N},0))'

# ---------- Gevecht ----------
wg = wb.create_sheet('Gevecht')
wg['A1'] = 'Deelnemers (uit Teams en WarEra)'
wg['A1'].font = TITLE
P_COLS = ['slot', 'team', 'naam', 'unit_count', 'max_health', 'max_shield', 'shield_regen_amount',
          'shield_regen_delay', 'health_regen', 'speed', 'attack_damage', 'attack_interval', 'attack_range',
          'attack_damage_type', 'kamikaze', 'damage_type_modifier', 'start_position', 'direction',
          'factor_vs_1', 'factor_vs_2', 'factor_vs_3', 'unit_type', 'is_player', 'behavior_scan_radius', 'alarm_instant_from']
header(wg, 2, 1, P_COLS)
P = {n: L(i + 1) for i, n in enumerate(P_COLS)}
prow = {}
for i, s in enumerate(SLOTS):
    r = 3 + i
    prow[s] = r
    tr = slot_row[s]
    nm = f'Teams!$B${tr}'
    wsel = f'Teams!$D${tr}'
    wg[f'A{r}'] = s
    wg[f'B{r}'] = s[0]
    wg[f'C{r}'] = f'=IF({nm}="","",{nm})'
    wg[f'D{r}'] = f'=IF(C{r}="",0,MAX(0,ROUND(N(Teams!$C${tr}),0)))'
    ok = f'IF(D{r}=0,0,'
    wg[f'E{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "max_health")})'
    wg[f'F{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "max_shield")})'
    wg[f'G{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "shield_regen_amount")})'
    wg[f'H{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "shield_regen_delay")})'
    wg[f'I{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "health_regen")})'
    wg[f'J{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "speed")})'
    is_player = f'{SJ("C"+str(r), "factie")}="player"'
    factor = f'IF({is_player},1,IFERROR({SJ("C"+str(r), "attack_interval")}/MAX(0.05,{WSTAT(SJ("C"+str(r), "weapon"), "fire_rate", 0.5)}),{ENEMY_FACTOR}))'
    dmg, interval, rng, dtype = weapon_attack(r, wsel, factor)
    custom = f'AND({wsel}<>"",{SJ("C"+str(r), "kamikaze")}=0)'
    wg[f'K{r}'] = f'=IF(D{r}=0,0,IF({custom},{dmg},{SJ("C"+str(r), "attack_damage")}))'
    wg[f'L{r}'] = f'=IF(D{r}=0,9999,IF({custom},{interval},{SJ("C"+str(r), "attack_interval")}))'
    wg[f'M{r}'] = f'=IF(D{r}=0,0,IF({custom},{rng},{SJ("C"+str(r), "attack_range")}))'
    wg[f'N{r}'] = f'=IF(D{r}=0,"",IF({custom},{dtype},{SJ("C"+str(r), "attack_damage_type")}))'
    wg[f'O{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "kamikaze")})'
    wg[f'P{r}'] = f'=IF(D{r}=0,"",{SJ("C"+str(r), "damage_type_modifier")})'
    wg[f'Q{r}'] = f'=IF(B{r}="A",0,{DIST})'
    wg[f'R{r}'] = f'=IF(B{r}="A",1,-1)'
    wg[f'V{r}'] = f'=IF(D{r}=0,"",{SJ("C"+str(r), "unit_type")})'
    wg[f'W{r}'] = f'=IF(D{r}=0,0,IF({SJ("C"+str(r), "factie")}="player",1,0))'
    wg[f'X{r}'] = f'=IF(D{r}=0,0,{SJ("C"+str(r), "behavior_scan_radius")})'
    wg[f'Y{r}'] = f'=IF(D{r}=0,"",{SJ("C"+str(r), "alarm_instant_from")}&"")'
opp = {s: ([x for x in SLOTS if x[0] != s[0]]) for s in SLOTS}
for s in SLOTS:
    r = prow[s]
    for k, o in enumerate(opp[s]):
        col = L(P_COLS.index('factor_vs_1') + 1 + k)
        wg[f'{col}{r}'] = f'={RESIST(f"$N${r}", f"$P${prow[o]}")}'

# Log
LOG_HEAD_ROW = 11
wg[f'A{LOG_HEAD_ROW - 1}'] = 'Verloop per tijdstap (elke rij is één tijdstap)'
wg[f'A{LOG_HEAD_ROW - 1}'].font = TITLE
FIELDS = ['position', 'alive', 'health', 'shield', 'cooldown', 'active', 'active_time', 'nearest_distance', 'target', 'fires', 'damage_dealt', 'damage_taken', 'time_since_hit']
log_cols = ['time', 'team_A_alive', 'team_B_alive', 'shots']
for s in SLOTS:
    log_cols += [f'{s}_{f}' for f in FIELDS]
header(wg, LOG_HEAD_ROW, 1, log_cols)
G = {n: L(i + 1) for i, n in enumerate(log_cols)}
FIRST = LOG_HEAD_ROW + 1
STEPS = 200
LAST = FIRST + STEPS

def pr(s, name):  # parameter
    return f'${P[name]}${prow[s]}'

for r in range(FIRST, LAST + 1):
    first = r == FIRST
    p = r - 1
    wg[f'{G["time"]}{r}'] = 0 if first else f'={G["time"]}{p}+{DT}'
    wg[f'{G["team_A_alive"]}{r}'] = '=' + '+'.join(f'{G[s + "_alive"]}{r}' for s in SLOTS if s[0] == 'A')
    wg[f'{G["team_B_alive"]}{r}'] = '=' + '+'.join(f'{G[s + "_alive"]}{r}' for s in SLOTS if s[0] == 'B')
    parts = []
    for s in SLOTS:
        parts.append(f'IF({G[s + "_fires"]}{r}=1,"{s}>"&CHOOSE({G[s + "_target"]}{r},"{opp[s][0]}","{opp[s][1]}","{opp[s][2]}")&" ("&ROUND({G[s + "_damage_dealt"]}{r},1)&")","")')
    wg[f'{G["shots"]}{r}'] = '=TRIM(' + '&" "&'.join(parts) + ')'
    for s in SLOTS:
        c = lambda f: f'{G[s + "_" + f]}{r}'
        cp = lambda f, slot=s: f'{G[slot + "_" + f]}{p}'
        if first:
            wg[c('position')] = f'={pr(s, "start_position")}'
            wg[c('alive')] = f'={pr(s, "unit_count")}'
            wg[c('health')] = f'={pr(s, "unit_count")}*{pr(s, "max_health")}'
            wg[c('shield')] = f'={pr(s, "unit_count")}*{pr(s, "max_shield")}'
            for f in ('cooldown', 'target', 'fires', 'damage_dealt', 'damage_taken'):
                wg[c(f)] = 0
            wg[c('time_since_hit')] = 999
            wg[c('active')] = f'={pr(s, "is_player")}'
            wg[c('active_time')] = 0
            wg[c('nearest_distance')] = 0
            continue
        # levend: uit de levens van vorige stap
        wg[c('alive')] = f'=IF({cp("health")}<=0,0,ROUNDUP({cp("health")}/MAX(1,{pr(s, "max_health")}),0))'
        near = ','.join(f'IF({G[o + "_alive"]}{r}>0,ABS({cp("position")}-{cp("position", o)}),1E9)' for o in opp[s])
        wg[c('nearest_distance')] = f'=MIN({near})'
        mates = [x for x in SLOTS if x[0] == s[0] and x != s]
        heard = []
        for m in mates:
            heard.append(f'{cp("active_time", m)}>={COMM_DELAY}')
            heard.append(f'AND({cp("active", m)}=1,{pr(m, "unit_count")}>0,ISNUMBER(SEARCH("/"&{pr(m, "unit_type")}&"/","/"&{pr(s, "alarm_instant_from")}&"/")))')
        wg[c('active')] = (f'=IF({c("alive")}=0,{cp("active")},IF(OR({pr(s, "is_player")}=1,{cp("active")}=1,'
                           f'{c("nearest_distance")}<={pr(s, "behavior_scan_radius")},{cp("damage_taken")}>0,{",".join(heard)}),1,0))')
        wg[c('active_time')] = f'=IF({c("active")}=1,IF({cp("active")}=1,{cp("active_time")}+{DT},0),0)'
        # doelwit
        keys = []
        for k, o in enumerate(opp[s]):
            d = f'ABS({cp("position")}-{cp("position", o)})'
            key = (f'IF({G[o + "_alive"]}{r}>0,CHOOSE(MATCH({RULE},{{"dichtstbij, zwakkere dichtbij","dichtstbijzijnde","zwakste","eerste"}},0),'
                   f'IF({d}<={c("nearest_distance")}+{SWITCH_RANGE},{cp("health", o)}+{d}/1E6,1E9),'
                   f'{d},{cp("health", o)},{k + 1}),1E9)')
            keys.append(key)
        m = f'MIN({",".join(keys)})'
        wg[c('target')] = (f'=IF(OR({c("alive")}=0,{c("active")}=0,{pr(s, "attack_damage")}<=0),0,IF({m}>=1E9,0,'
                           f'IF({keys[0]}={m},1,IF({keys[1]}={m},2,3))))')
        dist = f'ABS({cp("position")}-CHOOSE({c("target")},{cp("position", opp[s][0])},{cp("position", opp[s][1])},{cp("position", opp[s][2])}))'
        wg[c('position')] = (f'=IF({c("target")}=0,{cp("position")},IF({dist}>{pr(s, "attack_range")},'
                             f'{cp("position")}+{pr(s, "direction")}*MIN({pr(s, "speed")}*{DT},{dist}-{pr(s, "attack_range")}),{cp("position")}))')
        wg[c('fires')] = f'=IF({c("target")}=0,0,IF(AND({dist}<={pr(s, "attack_range")},{cp("cooldown")}<=0.0001),1,0))'
        wg[c('cooldown')] = f'=IF({c("fires")}=1,{pr(s, "attack_interval")},MAX(0,{cp("cooldown")}-{DT}))'
        fac = f'CHOOSE({c("target")},{pr(s, "factor_vs_1")},{pr(s, "factor_vs_2")},{pr(s, "factor_vs_3")})'
        wg[c('damage_dealt')] = f'=IF({c("fires")}=1,IF({pr(s, "kamikaze")}=1,1,{c("alive")})*{pr(s, "attack_damage")}*{fac},0)'
        # ontvangen: van elke tegenstander die mij als doel heeft
        my_index = [x for x in SLOTS if x[0] == s[0]].index(s) + 1
        incoming = '+'.join(f'IF({G[o + "_target"]}{r}={my_index},{G[o + "_damage_dealt"]}{r},0)' for o in opp[s])
        wg[c('damage_taken')] = f'={incoming}'
        absorbed = f'MIN({cp("shield")},{c("damage_taken")})'
        through = f'({c("damage_taken")}-{absorbed})'
        wg[c('health')] = (f'=IF(AND({pr(s, "kamikaze")}=1,{c("fires")}=1),MAX(0,{cp("health")}-{pr(s, "max_health")}-{through}),MAX(0,MIN({c("alive")}*{pr(s, "max_health")},'
                           f'{cp("health")}-{through}+IF({cp("health")}>0,{c("alive")}*{pr(s, "health_regen")}*{DT},0))))')
        regen = f'IF(AND({c("damage_taken")}=0,{cp("time_since_hit")}+{DT}>={pr(s, "shield_regen_delay")}),{c("alive")}*{pr(s, "shield_regen_amount")}*{DT},0)'
        wg[c('shield')] = f'=IF({c("health")}<=0,0,MIN({c("alive")}*{pr(s, "max_shield")},{cp("shield")}-{absorbed}+{regen}))'
        wg[c('time_since_hit')] = f'=IF({c("damage_taken")}>0,0,{cp("time_since_hit")}+{DT})'
wg.freeze_panes = f'B{FIRST}'

# ---------- Resultaat ----------
wr = wb.create_sheet('Resultaat')
wr['A1'] = 'Resultaat'
wr['A1'].font = TITLE
tcol = f'Gevecht!${G["time"]}${FIRST}:${G["time"]}${LAST}'
acol = f'Gevecht!${G["team_A_alive"]}${FIRST}:${G["team_A_alive"]}${LAST}'
bcol = f'Gevecht!${G["team_B_alive"]}${FIRST}:${G["team_B_alive"]}${LAST}'
max_steps = f'MIN({STEPS},ROUND({TMAX}/{DT},0))'
end_idx = f'MIN(IFERROR(MATCH(0,{acol},0),1E9),IFERROR(MATCH(0,{bcol},0),1E9),{max_steps}+1)'
wr['A3'] = 'end_step'; wr['B3'] = f'={end_idx}'
wr['A4'] = 'duration'; wr['B4'] = f'=INDEX({tcol},B3)'
wr['A5'] = 'team_A_alive'; wr['B5'] = f'=INDEX({acol},B3)'
wr['A6'] = 'team_B_alive'; wr['B6'] = f'=INDEX({bcol},B3)'
wr['A7'] = 'winner'; wr['B7'] = '=IF(AND(B5>0,B6=0),"Team A",IF(AND(B6>0,B5=0),"Team B",IF(AND(B5=0,B6=0),"Allebei dood","Geen winnaar (tijd op)")))'
for rr in range(3, 8):
    wr[f'A{rr}'].font = BOLD
header(wr, 9, 1, ['slot', 'naam', 'unit_count', 'alive_left', 'health_left', 'shield_left', 'damage_dealt', 'dps', 'damage_taken'])
for i, s in enumerate(SLOTS):
    r = 10 + i
    col = lambda f: f'Gevecht!${G[s + "_" + f]}${FIRST}:${G[s + "_" + f]}${LAST}'
    wr[f'A{r}'] = s
    wr[f'B{r}'] = f'=Gevecht!$C${prow[s]}'
    wr[f'C{r}'] = f'=Gevecht!$D${prow[s]}'
    wr[f'D{r}'] = f'=INDEX({col("alive")},$B$3)'
    wr[f'E{r}'] = f'=INDEX({col("health")},$B$3)'
    wr[f'F{r}'] = f'=INDEX({col("shield")},$B$3)'
    wr[f'G{r}'] = f'=SUMIFS({col("damage_dealt")},{tcol},"<="&$B$4)'
    wr[f'H{r}'] = f'=IF($B$4>0,G{r}/$B$4,0)'
    wr[f'I{r}'] = f'=SUMIFS({col("damage_taken")},{tcol},"<="&$B$4)'
wr['A17'] = 'Vergelijken met Godot: laat Godot een CSV schrijven met dezelfde kolomnamen (slot, naam, unit_count, alive_left, health_left, shield_left, damage_dealt, dps, damage_taken, plus duration en winner) en plak die naast deze tabel.'
wr.column_dimensions['A'].width = 16
wr.column_dimensions['B'].width = 22

# ---------- Matrix ----------
wm = wb.create_sheet('Matrix')
wm['A1'] = 'Elke unit 1-tegen-1 tegen elke andere: hoeveel keer sneller de RIJ de KOLOM doodmaakt dan andersom (>1 = rij wint, <1 = rij verliest, 0 = rij kan niet doden, 99 = kolom kan de rij niet doden). Rekent met de aannames uit Teams, zonder schildherstel.'
MATRIX_UNITS = ['Speler'] + [f"{f} {t}" for f in ('Organic', 'Mech', 'Energy', 'Cyborg') for t in ('light', 'medium', 'heavy', 'tower')]
NM = len(MATRIX_UNITS)
ROW0 = 3
COL0 = 2
wm.cell(row=2, column=1, value='rij \\ kolom').font = BOLD
for i, n in enumerate(MATRIX_UNITS):
    wm.cell(row=ROW0 + i, column=1, value=n).font = BOLD
    cc = L(COL0 + i)
    wm[f'{cc}2'] = f'=$A${ROW0 + i}'
    wm[f'{cc}2'].font = BOLD
# hulpwaarden per unit (rechts van de matrix, verborgen)
HCOL0 = COL0 + NM + 2
helpers = ['speed', 'attack_damage', 'attack_interval', 'attack_range', 'attack_damage_type', 'health_plus_shield', 'damage_type_modifier', 'kamikaze']
for k, hname in enumerate(helpers):
    wm.cell(row=2, column=HCOL0 + k, value=hname).font = BOLD
for i in range(NM):
    r = ROW0 + i
    for k, hname in enumerate(helpers):
        wm.cell(row=r, column=HCOL0 + k, value=f'=IFERROR({SJ("$A" + str(r), hname)},"")')
HC = {h: L(HCOL0 + k) for k, h in enumerate(helpers)}

def ttk(a, b):
    """Tijd waarin unit a (helperrij a) unit b doodmaakt, 1-tegen-1. 1E9 = nooit."""
    g = lambda h, row: f'${HC[h]}${row}'
    sa, sb, ra, rb = g('speed', a), g('speed', b), g('attack_range', a), g('attack_range', b)
    d = DIST
    approach = (f'IF({d}<={ra},0,IF({ra}>={rb},IF({sa}+{sb}>0,({d}-{ra})/({sa}+{sb}),1E9),'
                f'IF({sa}>0,IF({d}>{rb},IF({sa}+{sb}>0,({d}-{rb})/({sa}+{sb}),1E9),0)+(MIN({d},{rb})-{ra})/{sa},1E9)))')
    fac = RESIST(g('attack_damage_type', a), g('damage_type_modifier', b))
    per = f'({g("attack_damage", a)}*{fac})'
    shots = f'ROUNDUP({g("health_plus_shield", b)}/{per},0)'
    return (f'IF({per}<=0,1E9,IF({g("kamikaze", a)}=1,IF({per}>={g("health_plus_shield", b)},{approach},1E9),'
            f'{approach}+({shots}-1)*{g("attack_interval", a)}))')

TT0 = ROW0 + NM + 3
wm.cell(row=TT0 - 1, column=1, value='Tijd (s) waarin de RIJ de KOLOM doodmaakt (1E9 = nooit)').font = TITLE
for i in range(NM):
    wm.cell(row=TT0 + i, column=1, value=f'=$A${ROW0 + i}')
    for j in range(NM):
        a, b = ROW0 + i, ROW0 + j
        wm.cell(row=TT0 + i, column=COL0 + j, value=f'=IF(OR($A${a}="",$A${b}=""),"",{ttk(a, b)})')
for i in range(NM):
    for j in range(NM):
        t_ab = f'{L(COL0 + j)}{TT0 + i}'
        t_ba = f'{L(COL0 + i)}{TT0 + j}'
        wm.cell(row=ROW0 + i, column=COL0 + j,
                value=f'=IF({t_ab}="","",IF({t_ab}>=1E9,0,IF({t_ba}>=1E9,99,ROUND(({t_ba}+0.001)/({t_ab}+0.001),2))))')
wm.column_dimensions['A'].width = 18
wm.freeze_panes = 'B3'

# volgorde: Units, Wapens, Teams, Gevecht, Resultaat, Matrix, WarEra
wb.move_sheet('WarEra', offset=0)
wb._sheets = [wb['Units'], wb['Wapens'], wb['WarEra'], wb['Teams'], wb['Gevecht'], wb['Resultaat'], wb['Matrix']]
wb.save(OUT)
print('ok', len(entries), 'strijders', STEPS, 'stappen')
