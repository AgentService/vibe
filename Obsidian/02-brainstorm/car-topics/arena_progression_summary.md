# Arena Progression & Time-Based Scaling – Brainstorming Summary

## Thema
Diskussion über Arena-Progression, Timer-Scaling und Teleporter-Events für Markus' Roguelike-Game (inspiriert von Risk of Rain und PoE Atlas).

---

## Bisherige Erkenntnisse

### Risk of Rain (1 & 2)
- **Timer:** läuft kontinuierlich, Gegner skalieren exponentiell mit der Zeit.
- **Teleporter:** von Anfang an in jeder Stage vorhanden, kann jederzeit aktiviert werden.
- **Teleporter-Event:** spawnt Boss + Adds, skaliert mit *aktueller Difficulty* (Timer + Stage-Level + Spieleranzahl).
- **Belohnung:** garantierte Items vom Boss, Fortschritt ins nächste Stage.
- **Zwischen Stages:**
  - Items & Level bleiben bestehen.
  - Gold wird zu XP konvertiert → Start mit 0 Gold, aber stärkerem Charakter.
  - Timer läuft ununterbrochen weiter, Difficulty steigt global.
- **Run-Ende:** Tod = kompletter Run vorbei (Singleplayer). In Multiplayer: Wiederbelebung nach Teleporter-Event, wenn Team überlebt.

### Spielerentscheidungen
- Kernfrage: **Wann aktiviere ich den Teleporter?**
  - Früh: schwacher Boss, aber wenig Items.
  - Spät: mehr Items, aber deutlich härterer Boss.
- Optimaler Zeitpunkt: nicht zu früh, nicht zu spät → Balance aus Loot & Risiko.

### Vergleich zu anderen Spielen
- **Risk of Rain:** Survival-orientiert, Timer als Kernspannung, Runs enden beim Tod.
- **Deep Rock Galactic:** Missions-orientiert mit festem Finale (Escape).
- **Hades:** fixe Arenen + Bosse, kein Timer.
- **Vampire Survivors:** Timer endet Run (meist nach 30 Min), finale „Reaper“-Phase.
- **Death Must Die:** Mischung → Timer + klares Endevent.

### Designentscheidungen für Markus' Spiel
- Karten sind kleiner, daher **Teleporter finden** wie in RoR ungeeignet.
- Idee: **Mindestzeit**, ab wann Teleporter erscheint (z. B. Minute 10).
- Offen: **Maximalzeit** → entweder frei lassen (RoR-Style, nur Timer-Skalierung als Druck) oder Auto-Trigger nach bestimmter Zeit (Death Must Die-Style).
- Gegner sollen **kontinuierlich spawnen**, nicht fix wie in PoE → impliziert, dass Farmen immer möglich ist, aber Risiko mit Zeit steigt.
- Teleporter-Event sollte mit **aktueller Difficulty** skalieren (RoR-Logik), nicht fix.

### Vorteile/Nachteile RoR-Ansatz (variable Difficulty)
**Vorteile:**
- Einheitliches Scaling-System, weniger Sonderlogik.
- Spannendes Risk/Reward-Dilemma bei Teleporter-Timing.
- Höhere Replayability, jeder Run einzigartig.

**Nachteile:**
- Gefahr von „optimal play“-Muster („immer X Minuten farmen“).
- Kann unfair wirken, wenn Boss bei spätem Start übermächtig ist.
- Balancing schwierig zwischen Loot-Rate und Gegner-Skalierung.

### Alternative: Fixe Boss-Schwierigkeit
- Einfacher zu balancen, planbarer.
- Aber weniger Spannung, Runs fühlen sich gleichförmiger an.

---

## Offene Fragen
1. Soll der Teleporter ein **Mindest- & Maximalzeitfenster** haben oder nur Mindestzeit?
2. Will Markus Runs eher als **Survival (Highscore)** oder als **Mission (Finale-Event)** gestalten?
3. Welche **Meta-Progression** bleibt zwischen Runs erhalten?
   - Nur Atlas-Mastery / Content-Freischaltungen?  
   - Oder auch dauerhafte Charakter-Upgrades?
4. Soll Tod = kompletter Run vorbei sein (klassisch Roguelike), oder gibt es **weichere Systeme** (z. B. Respawn nach Event)?
5. Wie stark darf Farmen sein, ohne dass es immer „optimal“ wird, den Teleporter später zu starten?

---

## Nächste Schritte
- Entscheidung treffen: **RoR-Modell** (variabel, risk/reward) oder Hybrid mit Maximalzeit.  
- Simulationslauf durchspielen (z. B. 20-Minuten-Run mit 2 Teleportern), um Pacing zu testen.  
- Klären, wie Meta-Progression im Atlas verankert wird (Score vs Unlocks).  
