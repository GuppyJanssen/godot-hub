# CLAUDE.md – godot-hub (2D space rogue-lite)

Claude Code leest dit bestand aan het begin van elke sessie in deze map.
Houd het kort en actueel. Bijgewerkt: 17 november 2026 (avond).

- Ontwerp: https://claude.ai/artifact/JjvwFyx6Jtb8dEDUjxFCj9
- Ideeën, planning en takenlijst: https://claude.ai/artifact/Cvi6x9PXQSMgAGeYU4JHJB

## Project

- 2D rogue-lite in de ruimte, **Godot 4.7** (GDScript).
- Kamers zoals The Binding of Isaac: één scherm (1920×1080) per kamer, deuren open als de kamer leeg is.
- De wereld is een bol van ringen (`LevelManager.LAYER_WIDTHS` = 1, 6, 12, 24, 48, 96, 48, 24, 12, 6, 1).
- Run-loot gaat na de run naar een vaste kluis; daarmee koop je levels in de skill tree. Skills vervallen met speeltijd.
- Plan: eerst ring 1 compleet, daarna de rest als vertical slice.

## Werkafspraken

- **Taal:** antwoorden en commentaar in de code in het Nederlands. Gebruik "wil", nooit "wilt".
- **De eigenaar is beginner in programmeren.** Leg uit wat je verandert en waarom, in gewone woorden.
- **Lees eerst het echte script** voordat je iets wijzigt. Geen aannames over wat erin staat.
- **Geen code staat vast.** Stel gerust een betere aanpak voor, maar vraag het voordat je grote stukken herschrijft.
- **Kleine stappen.** Eén onderdeel tegelijk, daarna testen.
- **Test zelf.** Start Godot om te controleren of scripts zonder fouten laden voordat je zegt dat iets klaar is.
  Hoe het eruitziet en aanvoelt beoordeelt de eigenaar.
- **Bestanden verplaatsen of hernoemen** gebeurt in Godot (FileSystem-paneel), niet in de Verkenner,
  anders breken de verwijzingen in de scenes. Verplaats je iets vanuit hier, werk dan ook de paden in `.tscn` bij.
- **Maak een commit** voor en na elke ronde wijzigingen, zodat alles terug te draaien is.

## SSOT (Single Source of Truth)

- Alle waarden komen uit **één CSV**, geëxporteerd uit de Google Sheet "One doc to rule them all"
  (tabblad 2 = invullen, tabblad 1 = export).
- Doel: de code zo bouwen dat alleen de SSOT aangepast hoeft te worden, nooit de code.
- Per stat een `base_` en een `_modifier` kolom. **Modifiers zijn percentages: 0 = neutraal, 0.1 = +10%.**
- **Leeg** = geldt niet voor deze rij. **0** = geldt wel en telt mee als 0.
- Skill-ID's zijn `skill_1`, `skill_2`... met een kolom voor de omschrijving en een kolom `parent_skill_id`.
- De CSV in de repo is nog de oude versie (12 kolommen, stats als tekst in één cel). De nieuwe brede sheet moet nog komen.

## Autoloads (in deze volgorde)

| Naam | Script | Rol |
| --- | --- | --- |
| `Game` | `Systems/Game.gd` | Centrale hub: actieve speler, save-slot, run-loot (als meta), debug (F1) |
| `LevelManager` | `Systems/LevelManager.gd` | Ring en kamer |
| `DebugOverlay` | `Systems/Debug_Overlay.gd` | Debugscherm |
| `Mods` | `Systems/modifier_stack.gd` | Alles wat stats van de speler aanpast (skills, items, effecten) |
| `Ssot` | `Systems/ssot.gd` | NIEUWE CSV-lezer op kolomnaam. Leest `Systems/ssot.csv` (export van de tab "CSV tab"). De enige CSV-lezer (MasterDatabase is weg sinds 18 nov) |
| `RunState` | `Systems/run_state.gd` | De lopende run: dodenlijst, gehaalde kamers, kamer-momentopnames, speeltijd. Start/stopt/bewaart ook de factie-oorlog |
| `FactionWar` | `Systems/faction_war.gd` | Factie-oorlog op de achtergrond: per kamer eigenaar en sterkte, tikt elke seconde speeltijd |
| `FactionWarMap` | `Systems/faction_war_map.gd` | Debugkaart van de oorlog (F2, F3 = versnellen). Alleen in debug-builds |

`Systems/SaveSystem.gd` is geen autoload en wordt op veel plekken los aangemaakt met `load(...).new()`.
Het regelt nog de kluis (`meta_data.json`) en een deel van `current_run.json`.

## Wat er op 16 november 2026 gebouwd is

- **Loot-splatter:** `Entities/Loot/loot_splatter.gd` + `loot_drop.gd`. Kegel ±35°, snelheid 60–400, afremming 600.
  Waarden staan nog als `DEFAULT_` in het script; moeten naar de SSOT, per wapen.
- **RunState:** schrijft `user://<slot>/run_state.json`, naast `current_run.json`.
  Positie, HP van de speler en de loot-tellers lopen nog via het oude systeem.
- **Kamer onthouden via de groep `saveable`:** elk object dat onthouden wil worden meldt zich aan in die groep
  en heeft `get_run_id()`, `get_run_state()` en `apply_run_state(data)`. De kamer (`World/Levels/game_room.gd`)
  verzamelt en zet terug, zonder te weten wat voor objecten het zijn. Uitleg staat in dat script onder "KAMER ONTHOUDEN".
  Groep `save_only_on_quit` = alleen bewaren bij "terug naar hoofdmenu" (kogels).
  Nu aangemeld: vijanden (`test_body.gd`), fabrieken (`enemy_spawner.gd`), loot, kogels (`weapon_output.gd`).
- **Eén spawner-script** (`enemy_spawner.gd`) met Faction, Unit Type en Sprite Scale in de Inspector.
- **Factie × type:** `Systems/enemy_stats.gd`. Een vijand = basis van `unit_<type>` × modifiers van `faction_<factie>`;
  een eigen rij `enemy_<factie>_<type>` gaat voor. Vijanden zonder factie/type (oude testvijanden) krijgen
  vaste testwaarden uit `test_body.gd` (LEGACY_TEST_HEALTH, DEFAULT_LOOT_*).
- **Kogels** verdwijnen als hun bereik op is en geven hun vliegrichting door bij een treffer.
  Het bereik komt uit de SSOT (`base_fire_range`), via `current_weapon_stats["weapon_range"]` van de speler.

Nog niet aangesloten (staan klaar, worden nergens aangeroepen): `World/ring_math.gd`, en alles in `Ideeen/`.
Basisopzet van Thomas, nog niet in gebruik: `Quirk/BaseQuirk.gd`, `Entities/Objects/entity.gd` (+ `meteor_entity.gd`,
`Entity.tscn`), `World/Levels/Level.gd`.

## Toegevoegd op 17 november 2026

- **Nieuwe CSV:** `Systems/ssot.csv` (Import As = Keep File, net als de oude CSV). De Google Sheet heeft tab "SSoT"
  (invullen, kopregel in rij 4) en "CSV tab" (export; één formule in A1: `=ARRAYFORMULA(SSoT!A4:EI1000)`; komen er kolommen achteraan bij, dan moet de laatste kolomletter mee, dus nieuwe rijen en
  tussengevoegde kolommen komen vanzelf mee). Claude kan de sheet bewerken via de ingebouwde browser van de desktop-app. Rij-ids: `world` (wereld- en
  oorloginstellingen), `unit_light`, `unit_heavy`, `unit_factory`, `faction_a` t/m `faction_i` en hybrides
  `faction_ab`, `faction_bc`, `faction_ca` (en zo verder per driehoek). data_type: `world_settings`, `unit_type`, `faction`.
- **Kamergrenzen:** `Systems/room_bounds.gd` (`RoomBounds.apply`) bepaalt de bewegingsruimte voor speler én vijanden
  (Zuidpool: onderkant dicht, links/rechts rondlopen; gewone ring: dicht zolang er vijanden leven).
- **Sheet opgeschoond (17 nov):** SSoT is ingedeeld in blokken met kopregels (SPELER, PLANETEN, ITEMS, WAPENS, LOOT,
  SKILLS, WERELD, VIJAND-TYPES, FACTIES, VIJAND-OVERRIDES). Kopregels hebben geen entry_id en worden door Ssot overgeslagen.
  Brainstorm-rijen staan in een eigen tabblad (niet in de CSV). Reservekopie: tabblad "SSoT backup 17-11".
  Skills: 25 rijen (skill_speed, skill_damage, skill_fire_rate, ...); de skill tree bouwt zich op uit alle upgrade_skill-rijen.
  Effect PER LEVEL: base_<stat> = vaste bonus, <stat>_modifier = procent (0.01 = +1% per level, +100% op 100).
  data_type `upgrade_skill` (SkillEffects.SKILL_TYPE). Kosten in fill_costs_per_point als "olrite:5" (skill_tree.gd leest dit).
  Teksten in de sheet mogen niet met + of - beginnen (Sheets maakt er een formule van).
  Let op: `decay_modifier` is wél een vermenigvuldiger (1 = neutraal), zie skill_decay.gd.
- **Skill tree (24 nov):** wordt in code opgebouwd (skill_tree.gd + SkillTreeLayout + SkillTreeNode), geen vaste knoppen
  meer in SkillTree.tscn. Takken kruisen nooit (rechte lijnen; klemt een tak, dan wordt de boom met een afgeleide seed opnieuw gelegd). Stamboom = SSOT `parent_skill_id` (leeg = vaste automatische keuze op skill-id, gelijk in elke save;
  "root" = het midden, anders de eerste skill). Plek van de takken = `tree_seed` in meta_data.json (per save, bij eerste keer
  openen gekozen). Nooit gekochte skills = zwart vakje met "?"; gekocht = `discovered_skills` in de save. Te koop als de parent
  punten heeft. Randkleur = SSOT `skill_kind` (wapen/schip/beweging/loot/tree/overig), tijdelijk FALLBACK_KIND in skill_tree.gd.
  Verborgen: `skill_menu_visible` = 0. Max level: `fill_levels_amount`.
- **Vijand-overrides** (sheet rij 21-38, data_type `enemy_override`): `enemy_<factienaam>_<type>`, bijvoorbeeld
  `enemy_organic_light`. De factienaam komt uit de ingame_name van de factie-rij (A = Organic, B = Mech, C = Energy,
  AB = Cyborg); zonder naam werkt de letter (`enemy_bc_light`). Lege cel = type + factie. Light heet in-game "grunt",
  behalve bij Organic ("spore"); de Organic heavy heet "scout".
- **Factie-oorlog:** `faction_war.gd`. Rekent alleen met getallen per kamer (owner, strength, attacker...). Regels: zijwaarts
  en een beetje omhoog, nooit omlaag; lagere driehoek komt alleen omhoog via door de speler geleegde kamers; hybrides alleen
  binnen een driehoek; geleegde kamers blijven `reoccupy_delay` leeg. Instellingen uit SSOT-rij `world`, standaarden in `DEFAULTS`.
  Driehoek per ring in `RING_TRIANGLE` (aanname: ring 1-3 ABC, 4-6 DEF, 7-9 GHI). Doet nog niets met de vijanden in een kamer:
  dat komt met de plaatsingspunten (`FactionWar.get_room_owner(ring, kamer)`).
- **Vijanden zonder voorkant:** `test_body.gd` heeft `faces_player`. Uit = tolt rond met eigen snelheid, treffers geven een zetje.
  Komt uit de SSOT-kolom `behavior_faces_player` (factie-rij of eigen vijand-rij; 1/0, leeg = Inspector). Factie A = 0.
- **Gedrag van vijanden** (`test_body.gd`, uit de SSOT; eigen rij `enemy_<factie>_<type>` gaat voor factie en type):
  `behavior_searching` = `hunt` (standaard: meteen op de speler af) of `wander` (zwerft tot alarm);
  `behavior_agro` = `chase` (standaard), `kamikaze` (ontploft bij de speler, raakt alles in `base_explosion_radius`,
  laat maar 10% loot vallen) of `keep_distance` (verkenner: blijft op afstand met de speler in zicht);
  `behavior_scan_radius` = kijkafstand, 0/leeg = blind. Wie de speler ziet slaat alarm voor zijn factie (geraakt: pas na `hit_alarm_delay` = 1,5 s, zodat stil uitschakelen kan)
  in die kamer (onthouden in RunState als `alarm_<factie>`). Niet-blinde, zwervende vijanden die een kogel zien,
  gaan kijken waar die vandaan kwam. Zicht = afstand + raycast (vijanden, loot en speler blokkeren niet).
  Organic: `enemy_a_light` = blinde kamikaze, `enemy_a_heavy` = verkenner (kijkafstand 450).
- **Speler** heeft nu `take_damage(amount)` (schild eerst, daarna HP, overlijden afgehandeld); botsingen en ontploffingen gebruiken die.
- **Fabriek:** veld heet `spawn_unit_type` (welk type hij maakt); eigen levens uit `unit_factory`. In `game_room.tscn`
  maakt spawner1 grunts (light) en spawner2 een verkenner (heavy).
- **Witte flits** werkt op alle zichtbare sprites van de vijand. Oude icoon-sprite uit `test_body.tscn` gehaald.
- Fabrieken staan standaard op Unit Type `light` (de sheet gebruikt light/heavy/factory, geen grunt).

## Opgeschoond op 17 november 2026

- `Player.gd`: het eerste schietblok dat `can_fire` negeerde is weg (full-auto vuurde elk frame),
  de dubbele herlaad-wachttijd is weg, en bij overlijden gaan nu ook Element 1 t/m 3 naar de kluis.
- `game_room.gd`: omhoog en omlaag komen niet meer altijd in kamer 0 uit, maar in de kamer boven of onder
  je (`_room_index_after_ring_change`).
- `hud.gd`: maakte in de skill tree elk frame een nieuw SaveSystem aan; dat wordt nu hergebruikt.
- `pre_menu.gd`: twee ongebruikte kopieën van functies uit SaveSystem verwijderd.
- Verwijderd (ongebruikt): `heavy_spawner.gd`, `Weapon.gd`, `Player/player_stats.gd`, `world_stats.gd`,
  `Overworld.gd/.tscn`, `player.tscn*.tmp`, `fg.txt`, de `.translation`-bestanden en drie wees-`.import`-bestanden;
  plus de ongebruikte functies `LevelManager.handle_room_transition`/`_load_current_room`,
  `Game.transfer_run_loot_to_meta_bank`/`load_and_force_continue_position`, `PlayerStats.get_calculated_speed`
  en `Game.debug_is_full_auto`.
- Vijanden worden groter of kleiner volgens `base_size` in de SSOT (heavy = 1.5). Geraakte verkenners slaan pas
  na `hit_alarm_delay` (1,5 s) alarm.

## Bekende problemen

- **`neutral_spawner.gd`** (bewust bewaard: wordt omgebouwd tot plaatsingspunt) gebruikt nog de oude controle via `current_run.json` en het oude `SaveSystem`.
  Nergens in een scene geplaatst.

- **Skills doen nog niets** in het spel; de skill-ID's in `SkillTree.tscn` komen niet overeen met de CSV.
- **Run-loot staat dubbel:** als meta op `Game` en in `run_loot_*` op de speler. `RunState.loot` telt mee maar is niet leidend.
- **Half beschadigde vijanden** worden door het oude `SaveSystem.save_current_run()` onder de verkeerde kamer weggezet
  (de LevelManager wijst dan al naar de nieuwe kamer). RunState doet dit nu goed; het oude deel kan weg.
- **`SaveSystem.gd.new()`** wordt op veel plekken aangemaakt en niet opgeruimd.

## Volgende stappen (in deze volgorde)

1. Run-loot, positie en HP van de speler overzetten naar `RunState`; daarna de oude `current_run.json` uitfaseren.
2. `SaveSystem` als autoload, alleen nog voor de kluis.
3. ~~MasterDatabase vervangen door `Ssot` + `StatCalc`~~ (klaar, 18 nov).
4. Skills koppelen (`SkillEffects`) en het verval (`SkillDecay`).
5. Het seed-systeem voor kamers.

## Toegevoegd op 18 november 2026

- **MasterDatabase weg.** De speler laadt zijn wapens via `SsotWeapon.from_ssot()` (`Player._load_weapon_stats`).
  Kolommen in de sheet: `base_damage`, `base_fire_rate`, `base_fire_range`, `base_bullet_speed`, `base_burst_count`
  (kogels per schot), `base_muzzle_count`, `base_bullet_spread` (graden), `weapon_type` ("auto" = full-auto), `base_size`.
  Skills tellen mee via `StatCalc.player_value`. Eén kogel met spreiding krijgt een willekeurige afwijking.
- **Loot uit de SSOT** (rij van het type of een eigen vijand-rij): `base_loot_drop` (minimum), `loot_drop_max`,
  `loot_drop_chance` (kans op telkens één extra). Light en heavy: 3 / 10 / 0.5, factory 0 (fabrieken droppen nog niets).
  Splatter: `base_loot_splatter` = maximale snelheid; leeg = standaard uit `loot_splatter.gd`.
- **Kamers vullen (seed + factie-oorlog).** `Systems/room_populator.gd` zet bij het laden van een kamer fabrieken
  neer (`Entities/Spawners/factory.tscn`). Eigenaar uit `FactionWar.get_room_owner`, plekken en type uit
  `RunState.room_seed(ring, kamer, generatie)`. De vaste testfabrieken in `game_room.tscn` zijn weg. RunState onthoudt
  per kamer `pop_owner`, `pop_gen`, `pop_count`; na leegmaken + herbezetting komt er een nieuwe generatie.
  Instellingen in SSOT-rij `world`: `room_factory_min/max`, `room_heavy_chance`, `room_grunts_per_factory`,
  `room_heavies_per_factory` (leeg = standaard in het script). Polen (ring 0 en de laatste) blijven leeg.
- **Seed:** `RunState.run_seed` (bewaard in de save); hoofdmenu heeft een veld "Seed" (leeg = willekeurig, tekst
  wordt een getal). F1 toont seed, ring, kamer en eigenaar.
- **Loot:** `Entities/Loot/loot_drops.gd` (LootDrops) voor vijanden én fabrieken. Kolom `loot_drop_type`
  (olrite, metal, ...). Fabrieken droppen Metal (5 / 15 / 0.5).
- **Wapens:** toetsen 1 t/m 0 = de wapens in SSOT-volgorde, `[` en `]` bladeren door alle wapens. Nieuwe rijen:
  railgun, raketwerper, zuursproeier, magneetkanon, stralingsmortier, stuiterbal, golfkanon (en laserbeam ingevuld).
  Homing, explosies, zuur/straling over tijd en stuiteren bestaan nog alleen als kolommen; de kogel doet er nog niets mee.

- **Loot klontert samen** (`loot_drop.gd`): blokjes van dezelfde grondstof drijven na `loot_merge_delay` langzaam
  (`loot_merge_speed`) naar elkaar toe binnen `loot_merge_radius` (rij `world`, leeg = standaard) en worden stenen,
  klompjes en losse blokjes. Groottes per grondstof: `loot_chunk_small` / `loot_chunk_large` (olrite 15/97, metal 8/90).
- **Muzzles:** de speler schiet uit `base_muzzle_count` lopen naast elkaar; F1 kan dat overschrijven (SSOT, 1, 2, 4).
- **Wapenvakken (run):** de speler begint met alleen het pistool. `RunState.weapon_slots` = 4 vakken (0 boven = altijd
  pistool, 1 rechts, 2 onder, 3 links), `weapon_selected`, bewaard in de run-save. Wisselen: scrollen of 1-4; het
  wapenwiel (`Systems/weapon_wheel.gd`) is dan even zichtbaar. Wapens op de grond: `Entities/Loot/weapon_pickup.tscn`
  (WeaponPickup.spawn). Leeg vak = meteen oppakken en kiezen; alles vol = F (gebruik-knop) ruilt het gekozen wapen
  (ook het pistool), het oude wapen blijft liggen (saveable). F1 heeft een knop per wapen die het naast de speler legt.
- **God Mode** (F1): geen schade, geen energieverbruik, en de speler vliegt door alle barrieres (RoomBounds en
  game_room laten hem eruit, ook als er nog vijanden zijn; de kamer telt dan niet als gehaald).
- **Testkamer** onder de startkamer (alleen met God Mode, via de onderkant van ring 0): `LevelManager.in_test_room`,
  ring blijft 0. `Systems/test_room.gd` (TestRoom) zet een TestDummy (`Entities/Objects/test_dummy.gd`: schade,
  damage type, schade/sec) neer, plus één object per vijandtype uit de SSOT (rijen `unit_<type>`, data_type `unit_type`;
  fabriek = factory.tscn, elk ander type voorlopig test_body.tscn) van één factie (`TestEnemyRespawner`, respawn na 1 s,
  `passive` op test_body en basic_spawner: niet aanvallen, geen vijanden maken, niet bewaren, wel loot). Een wisselvlak
  (erover vliegen) gaat naar de volgende factie (a, b, c, ab, bc, ca, later d-i). Niets in de testkamer wordt bewaard. Terug: omhoog vliegen. Kogels geven hun `damage_type` door via `on_hit_info()`.
- **Loot-vormen:** los blokje = vierkantje, klompje (`loot_chunk_small`) = cirkel ×1.7, steen (`loot_chunk_large`) =
  5-puntige ster ×2.6. Samenklonteren telt de hoeveelheid, dus klompjes + losse blokjes kunnen samen een steen worden.

- **24 nov (2):** de speler heeft GEEN botsvorm op zijn CharacterBody2D, alleen een Area2D (groep "player").
  Areas die de speler moeten zien (wapen-pickups, het factie-vlak in de testkamer) luisteren dus naar area_entered.
  Gebouwen = unit_types met base_speed 0 (factory, tower, hq): die gebruiken de fabriek-scene (basic_spawner.gd,
  building_type) en hun base_size telt vanaf een fabriek (1 = fabriekgrootte). Bewegende types tellen vanaf de grunt.
  Factie-oorlog: de wereld is bij de start al grotendeels gevuld (zie _fill_ring_at_start, instellingen
  start_empty_chance, start_empty_chance_lowest_ring en start_edge_strength in de SSOT-rij world).
  SSOT: grondstoffenrijen (data_type loot) met resource_kind en rarity_tier; element_1..3 heten in-game Biomass,
  Circuitry, Crystal (entry_id blijft tot de grondstoffenlijst in de code zit). Nieuwe rijen cryo, arc_coil, thermion,
  isotope, neutronium_core, void_shard worden nog niet door de code gebruikt.
- **24 nov (3): grondstoffenlijst.** Element 1-3 bestaan niet meer. Alle grondstoffen zijn rijen met data_type loot in de SSOT
  (olrite, metal, keepium, biomass, circuitry, crystal, cryo, arc_coil, thermion, isotope, neutronium_core, void_shard).
  Code: Systems/loot_resources.gd (LootResources). Kluis = MetaProgress.resources (id -> aantal, meta_data.json "resources");
  run-buit = RunState.loot. Einde run (dood, opgeven, nieuwe run): LootResources.bank_run_loot(). Oude saves
  (currency_1..6, element1, loot-type 1..6) worden bij het laden omgezet via LootResources.normalize().
  Speler en PlayerStats hebben geen currency-velden meer; Game.get_meta("run_loot_*") bestaat niet meer.
  HUD toont alleen grondstoffen met een aantal > 0. Skill-kosten: fill_costs_per_point "id:prijs".
  Loot-gedrag (loot_drop.gd): trekt naar dichtste niet-rakende buur, botst, draait, klontert pas als binnen
  loot_merge_circle genoeg ligt. Instellingen in de SSOT-rij world (loot_merge_*, loot_orbit_strength, loot_cluster_friction).
  Elke kolomkop in de SSOT heeft een notitie met uitleg.

## Toegevoegd op 24 november 2026 (audit)

- **Veiligheid:** saves zijn alleen JSON via `SaveSystem.read_json/write_json` (typecontrole, max grootte, atomisch
  schrijven). Nooit `.tres`/`.res` uit `user://` laden (kan code uitvoeren). Scene-paden uit een save: alleen
  `res://` (`game_room._is_safe_scene_path`). Slotnamen: `SaveSystem.is_valid_slot`. F1-menu alleen in debug-builds.
- **Speler** leest alles uit `player_base` (zie de kop van `Player.gd`). De stand gaat via Game-meta en
  `RunState.extra["player_status"]`.
- **Skills** worden toegepast door `SkillEffects.refresh_from_save()` (Player._ready). Verval: `SkillDecay`
  (Normal na de run, Hard tijdens de run, via RunState).
- **Snelheid:** `Ssot.get_number` cachet omgerekende getallen. Loot gebruikt een gedeeld rooster
  (`loot_drop._ensure_grid`) en `loot_max_pieces_per_drop`.
- **Kogels:** pierce, bounce, knockback en explosies in `weapon_output.gd`; vijandschilden in `EnemyShield`.
- `base_bullet_spread` = hoek naar elke kant (20 = waaier van 40°), voor speler en vijanden.
