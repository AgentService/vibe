💾: **Gesamtsummary – Systeme, Entscheidungen, offene Punkte (für Obsidian)**

# 0) Projekt-Status (heute)

- **Trennung steht**: ContentDB ↔ BalanceDB; **alle JSON → .tres** migriert; Refactor stabil.
    
- **Kartenbau**: Aktuell wieder **Godot‑Editor** (Tiles) für Map‑Layout; ungenutzte/halbfertige Systeme entfernt.
    
- **Level‑Up‑Karten**: System neu gebaut, stabil (**3 Karten**, animiert/styled).
    
- **Ziel des Gesprächs**: rein **konzeptionell** brainstormen (keine Implementierung), Fundament so legen, dass **Refactoring minimiert** wird und **Vibe‑Coding** weiter Spaß macht.
    

---

# 1) Fähigkeiten (Abilities)

## 1.1 Grundprinzip

- **Basisklassen/Archetypen**: z. B. _Melee_, _Ranged/Projectile_, _Mage/AoE_, optional später _Orbital_, _Beam/Channel_, _Trap/Totem_, _Aura/Passive Proc_.
    
- **Erweiterbarkeit**: Neue Abilities sollen primär als **.tres** (Ressourcen) entstehen — **ohne Kernlogik** anfassen zu müssen.
    

## 1.2 Tag‑System (zentrales Scaling/Filter)

- Abilities tragen **Tags** (z. B. `Melee`, `Projectile`, `AoE`, `DoT`, `Fire`, `Channeling`, `Defensive`, `Utility`).
    
- **Karten/Passives/Items** wirken **über Tags** (z. B. „+% AoE“, „+% Projectile“).
    
- **Indikatoren**: Tags werden **sichtbar** (Farbe, Icon, Textbadge) — schnell lesbar im UI.
    

## 1.3 Nutzung/Slots & Input

- **4 Slots** denkbar, frei belegbar (Mischung aus Active, Auto‑Cast, Utility/Defensiv).
    
- **Autocast** optional (nicht alles autocast); **On‑Press** als MVP, Channel/Procs später.
    

## 1.4 Ressourcen & Timings

- **Cooldown‑basiert** als Start + **Mana** **von Anfang an** (Entscheidung).
    
- Spätere Skalierung über Karten/Items: CDR, Kosten‑Modifikatoren, AoE‑Größe, Projektilanzahl etc.
    

## 1.5 Waffen‑Kopplung

- **Nicht jede Fähigkeit mit jeder Waffe**: bestimmte Abilities verlangen **Waffentypen‑Bedingung** (z. B. „Melee‑Waffe benötigt“ / „Bogen erforderlich“).
    
- **Waffenskalierung**: Waffe liefert Basiseigenschaften (z. B. **Base Damage‑Range**, **Attack Speed**, **Base Crit**); Fähigkeit nutzt diese als Inputs.
    
- **Animationen**: **Waffen‑Grundanimation** + **Ability‑Spezial‑VFX** als Overlay; leichte **Animation‑Variants** pro Ability möglich.
    

## 1.6 Offene Punkte (Abilities)

- Erste **Tag‑Taxonomie** finalisieren (max. 8–10 Tags für MVP).
    
- Minimal‑Interface Ability‑Lifecycle (Events/Signale): `cast_started`, `projectile_spawned`, `hit_landed`, `damage_resolved`, `finished`.
    
- Waffentyp‑Regeln als Daten (nicht Hardcode): Mapping _Ability ↔ erlaubte WeaponTags_.
    

---

# 2) Kampf/Schadenspipeline (nur Struktur)

## 2.1 Schichten

1. **Compute‑Layer**: berechnet finalen Schaden (Stats, Waffe, Tags, „more“/„increased“, Defenses).
    
2. **Presentation‑Layer**: reagiert auf Events (Floating Numbers, Hit‑Flash, Knockback, SFX/VFX).
    

## 2.2 Minimaler DamageContext (MVP)

- Felder: `source`, `target`, `ability_id`, `weapon_ref?`, `tags[]`, `base`, `final`, optional `status[]`.
    
- **Reihenfolge (einfach)**: Base → (optionale „more“) → Defenses. _Crit & komplexe Reihenfolgen später_.
    
- **Status‑Effekte** (früh, klein): 1–2 (z. B. `Burn`, `Slow`) als Proof.
    

## 2.3 Event‑Bus

- Bestehendes **Signal/Event‑Bus** nutzen; **entkoppelte** Module abonnieren:
    
    - `DamageNumbers` (floating text),
        
    - `HitReaction` (Tint/Shake/Knockback),
        
    - `CombatLog` (Debug),
        
    - `OnKill` (Drops/XP).
        

---

# 3) Items, Inventar & Loot

## 3.1 Inventar/Char‑Bildschirm

- Taste **C** öffnet Inventar/Char‑Screen; **pausiert** im Run (Roguelike‑Swarm).
    
- **Slots**: Start schlank (z. B. Waffe, Rüstung, Schuhe, Ring, Amulett), später erweitern zu PoE‑ähnlichem Set.
    

## 3.2 Item‑Modell (MVP, AH‑ready)

- Felder: `uid`, `type` (weapon/armor/jewel/…), `rarity`, `ilvl/req`, `affixes[] {id, tier, roll}`, `tags[]`, `ver`, optional `owner_id`.
    
- **Filter (Solo & später AH)**: Type, Rarity, Affix‑IDs & Werte, DPS/EHP‑Aggregate, Level‑Req, Tags.
    
- **Uniques zuerst**: wenige markante Uniques mit festen/kleinen Range‑Rolls; später Crafting & Basisitems.
    

## 3.3 Loot‑Erlebnis & Aufnahme

- **Aufnehmen**: Drüberlaufen/Klick; MVP pausiert nicht, aber **Highlight** möglich.
    
- **Feedback**: **Beam/„roter Strahl“** (D2‑Gefühl) für seltene/Uniques (Entscheidung).
    
- **End‑of‑Run Reward**: _optional später_ (Kiste/Slot‑Machine).
    

## 3.4 Client/Server‑Gedanke (vorausplanen)

- **Heute**: reines **Client‑Solo**; Server später.
    
- **Andockpunkte**: `uid`, deterministische Serialisierung (tres/JSON), **Versionierung**.
    
- **Sync‑Philosophie später**: Server autoritativ für Inventar/Änderungen (Aufheben, Craft, Transfer, AH).
    

## 3.5 Offene Punkte (Items)

- Erste **Affix‑Liste** & ihre **Tags‑Brücke** (Affix kann Tags verleihen).
    
- Dropraten‑Kurve (häufige Early‑Uniques vs. seltener High‑Tier‑Loot).
    
- Crafting‑Pfad definieren (später).
    

---

# 4) Kampagne, Maps & Endgame

## 4.1 Kampagnenform (Entscheidung)

- **Kurze, geführte Einführung** (~1 h) mit kleinem roten Faden (NPC‑Hints, Basis‑Story) → dann **Endgame**.
    
- Endgame hat höhere Priorität in der Entwicklung; Kampagne kann später wachsen.
    

## 4.2 Map‑Layouts & Vielfalt

- **Feste Kartenlayouts** pro Biome (_Beach_, _Rocks_, _Swamp_, _Fire_ …) als Start;
    
- Spätere _leichte Randomisierung_ innerhalb des Layouts möglich (Deko/Spawnpositionen/Varianten).
    

## 4.3 Endgame‑Progression (Tiers)

- **Tier‑Leiter**: T1 → …; Gegner skalieren pro Tier.
    
- Spieler kann 1–2 Tiers „überziehen“ (Try‑Hard/Skill‑Check), sonst farmen/builden → spürbarer Progress.
    

## 4.4 Events/League‑Mechanics (Fundament jetzt!)

- **Event‑System von Anfang an** als Daten: Pool mit **Gewichten**, **Gates** (ab Tier/Level X), **max pro Map**.
    
- Events erscheinen an **vordefinierten Zonen** (Marker/Areas); beim Nähern **Trigger**.
    
- Später **Atlas/Passivbaum‑ähnlicher Bias**: Spieler justiert Häufigkeit bestimmter Events.
    

## 4.5 Spawns & Gegner‑Präsenz

- **Mix zulässig**:
    
    - Dein **WaveDirector** (Swarm um den Spieler), **plus**
        
    - **statische Gegner/Patrouillen** mit Aggro‑Radius **und**
        
    - Event‑Spawns (z. B. „Loch im Boden“).
        
- Das bleibt roguelite‑artig, gewinnt aber Varianz & Zielpunkte.
    

## 4.6 Daten-/Ressourcen‑Struktur (konzeptionell, .tres)

- `MapDef.tres`: `id`, `biome`, `tier`, `objectives[]`, `spawn_table_id`, `event_regions[]`, `reward_bias`, `theme_tags[]`.
    
- `SpawnTable.tres`: Pools, Dichte‑Kurve, Bosse, Level‑Spanne.
    
- `EventDef.tres`: `id`, `min_tier`, `max_per_map`, `possible_regions`, `weight`, `on_trigger: actions[]`.
    
- `NodeGraph/ActDef.tres`: für Intro‑Kette bzw. späteres Branching (optional).
    

## 4.7 Offene Punkte (Maps/Endgame)

- Zonenlänge (5–8 min?), Modifikatoren je Map (0–2) als MVP?
    
- Belohnungs‑Bias je Biome (z. B. +Projectile‑Affixe)?
    
- Gate‑Mechanik (Keys/Shards/Story‑Token)?
    

---

# 5) Modularität & UI‑Ankopplung

## 5.1 Module & Verantwortungen

- **MapController** (lädt MapDef, platziert Marker),
    
- **SpawnController** (liest SpawnTable, steuert Wellen/statische Spawns),
    
- **EventController** (EventPool, Trigger, Cap/Map),
    
- **RewardController** (Drops, Karten‑Choices),
    
- **AbilityService** (Cast/Tags/Costs),
    
- **CombatService** (DamageContext),
    
- **InventoryService** (Items/Filter),
    
- **UI‑Mediators** je Screen (MapInfo, EventPopup, Inventory, Cards).
    

## 5.2 Kommunikation

- **Signale/Event‑Bus** als Standard; UI **abonniert** State‑Änderungen.
    
- Module kommunizieren über **klare Interfaces** (Eingaben/Ausgaben), nicht direkt über Szenen‑Bäume.
    

## 5.3 Map‑Events konkret (Beispiel „Feuerkarte: Loch“)

- `event_region` (12×12) in MapDef → **EventController** registriert Region.
    
- Beim **Nähern**: würfeln aus `possible_events` (z. B. `AbyssLike`, `BreachLike`, `Shrine`), `max_per_map` prüfen, Event instanzieren (Loch + Spawnsequenz).
    
- Alles **data‑driven** (Tuning via .tres).
    

---

# 6) Movement & Eingabe (kurz)

- **Optionen**:
    
    - _WASD + Maus‑Aim_,
        
    - _Mouse‑only_ (ARPG‑Style),
        
    - **beides konfigurierbar** (Empfehlung: Wahlfreiheit).
        
- Looting: click/overlap; wichtige Drops **Beam‑FX**.
    

---

# 7) Zusammengefasste Entscheidungen (heute)

- **Abilities**: Basisklassen + **Tag‑System**; **Cooldown + Mana**; **Waffentyp‑Bedingungen**; Waffe skaliert Werte; Waffengrund‑Anim + Ability‑VFX.
    
- **Items**: Pausierbares **C‑Inventar**; Start‑Slots reduziert; **Uniques** früh; Item‑Schema mit `uid`, `affixes[]`, `tags[]`, `ver`; **Beam‑FX** für Seltenes.
    
- **Sync‑Vorausblick**: Später Server autoritativ; heute `uid`/Version/Serialisierung vorbereiten.
    
- **Maps/Endgame**: Kurze **Intro‑Kampagne (~1 h)** → **Tier‑basiertes Mapping**; feste Layouts; **Event‑System** von Beginn an (Pool, Caps, Gates); Wave + statische Gegner Mix.
    
- **Modularität**: Klare **Controller‑Module**, Event‑Bus, UI‑Mediators, .tres‑getrieben.
    

---

# 8) Offene Fragen / To‑Decide

1. **Tag‑Liste (MVP)**: finale Auswahl & Icons/Farben.
    
2. **Ability‑Lifecycle‑Events**: minimale Menge für FX/Logs.
    
3. **Item‑Affix‑Kernset** & deren Tag‑Interaktion.
    
4. **Zonenlänge/Map‑Mods/Belohnungs‑Bias** (konkrete Zahlen).
    
5. **Event‑Katalog (MVP 3–5)** inkl. minimaler Actions (Spawn, Shrine, Kurz‑Objective).
    
6. **Movement‑Default** (WASD, Mouse, oder beides aktiv).
    

---

# 9) Nächste Schritte (konzeptionell, kein Code)

- **A)** _Abilities_: Tag‑Liste (8–10) + Waffentyp‑Matrix + 3 Archetypen für MVP bestimmen.
    
- **B)** _Combat_: `DamageContext`‑Felder fixieren + 1–2 Status‑Effekte auswählen.
    
- **C)** _Items_: Pflicht‑Filter definieren + 5 Beispiel‑Uniques mit klaren Rolls/Tags skizzieren.
    
- **D)** _Maps_: Intro‑Flow (3 Zonen) textuell ausarbeiten + erste 3 **EventDefs**.
    
- **E)** _Module_: Interface‑Skizzen (ein Satz Inputs/Outputs je Controller) als Notizen.