# CLAUDE.md – godot-hub (2D space rogue-lite)

Claude Code leest dit bestand aan het begin van elke sessie in deze map.
Houd het kort en actueel. Bijgewerkt: 17 november 2026.

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
| `MasterDatabase` | `Systems/master_database.gd` | OUDE CSV-lezer. Nog in gebruik door speler, wapens en vijanden |
| `LevelManager` | `Systems/LevelManager.gd` | Ring en kamer |
| `DebugOverlay` | `Systems/Debug_Overlay.gd` | Debugscherm |
| `Mods` | `Systems/modifier_stack.gd` | Alles wat stats van de speler aanpast (skills, items, effecten) |
| `Ssot` | `Systems/ssot.gd` | NIEUWE CSV-lezer op kolomnaam. Draait naast MasterDatabase |
| `RunState` | `Systems/run_state.gd` | De lopende run: dodenlijst, gehaalde kamers, kamer-momentopnames, speeltijd |

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
  een eigen rij `enemy_<factie>_<type>` gaat voor. De rijen bestaan nog niet in de sheet, dus vijanden vallen
  terug op `enemy_test_1` enzovoort uit de MasterDatabase. Facties krijgen voorlopig een testkleur.
- **Kogels** verdwijnen als hun bereik op is en geven hun vliegrichting door bij een treffer.
  Het bereik komt uit de CSV (`weapon_range` in de stats-cel van het wapen).

Nog niet aangesloten (staan klaar, worden nergens aangeroepen): `stat_calc.gd`, `skill_effects.gd`, `skill_decay.gd`,
`Player/Weapons/ssot_weapon.gd`, `Player/Weapons/weapon_shooter.gd`, `World/ring_math.gd`, en alles in `Ideeen/`.

## Opgeschoond op 17 november 2026 (nog niet in Godot getest)

- `Player.gd`: het eerste schietblok dat `can_fire` negeerde is weg (full-auto vuurde elk frame),
  de dubbele herlaad-wachttijd is weg, en bij overlijden gaan nu ook Element 1 t/m 3 naar de kluis.
- `game_room.gd`: omhoog en omlaag komen niet meer altijd in kamer 0 uit, maar in de kamer boven of onder
  je (`_room_index_after_ring_change`, dezelfde rekenregel als `LevelManager.handle_room_transition`).
- `hud.gd`: maakte in de skill tree elk frame een nieuw SaveSystem aan; dat wordt nu hergebruikt.
- `pre_menu.gd`: twee ongebruikte kopieën van functies uit SaveSystem verwijderd.

## Bekende problemen

- **Ongebruikte bestanden** (mogen weg na controle): `Entities/Spawners/heavy_spawner.gd` (vervangen door het
  gedeelde script in `basic_spawner.gd`), `Entities/Weapon Output/Weapon.gd`, `Player/player_stats.gd`,
  `Resources/world_stats.gd`, de drie `Player/player.tscn*.tmp` en `fg.txt`.
- **`World/Overworld.gd`** roept `Player.new(Vector2(100,100))` aan, maar `Player` neemt geen argumenten.
  Het script wordt nergens gebruikt; laden geeft een fout.
- **`neutral_spawner.gd`** gebruikt nog de oude controle via `current_run.json` en het oude `SaveSystem`.
  Nergens in een scene geplaatst.

- **Twee kogelscripts:** `weapon_output.gd` is in gebruik, `weapon.gd` niet. Eén kiezen.
- **Skills doen nog niets** in het spel; de skill-ID's in `SkillTree.tscn` komen niet overeen met de CSV.
- **Run-loot staat dubbel:** als meta op `Game` en in `run_loot_*` op de speler. `RunState.loot` telt mee maar is niet leidend.
- **Half beschadigde vijanden** worden door het oude `SaveSystem.save_current_run()` onder de verkeerde kamer weggezet
  (de LevelManager wijst dan al naar de nieuwe kamer). RunState doet dit nu goed; het oude deel kan weg.
- **`SaveSystem.gd.new()`** wordt op veel plekken aangemaakt en niet opgeruimd.

## Volgende stappen (in deze volgorde)

1. Run-loot, positie en HP van de speler overzetten naar `RunState`; daarna de oude `current_run.json` uitfaseren.
2. `SaveSystem` als autoload, alleen nog voor de kluis.
3. De nieuwe brede CSV in de repo zetten en `Ssot` + `StatCalc` de `MasterDatabase` laten vervangen.
4. Skills koppelen (`SkillEffects`) en het verval (`SkillDecay`).
5. Het seed-systeem voor kamers.
