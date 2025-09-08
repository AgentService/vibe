# Map Tiers & Modifikatoren – Ausarbeitung

**Datum:** 2025-09-08  
**Autor:** Professor Synapse (via ChatGPT)

---

## 📈 Map-Tiers

Struktur: 16 Tiers (T1–T16).  
Skalierung: Gegner bekommen mehr HP, DMG, mehr/ härtere Bosse, erhöhte Spawnrate.

Schritt-für-Schritt
- Implementiere eine Variable `tier`.
- Leite Gegnerwerte aus dieser Variable ab (HP, DMG, Spawnrate, Bossanzahl/-stärke).
- Droplogik: Map kann max. +1 Tier höher droppen.

---

## ⚙️ Modifikatoren

Arten
- Gegnerstärke: HP, DMG, Resistenz.
- Gegnerverhalten: Elites, Minibosse, Spezialfähigkeiten.
- Map-Bedingungen: Heilung reduziert, Dunkelheit, Sicht/Bewegungsalus.
- Spieler-Beschränkungen: Dash gesperrt, höhere Kosten/Abklingzeiten.

Schritt-für-Schritt
- Baue ein Mod-System mit Tags.
- Spieler wählt (manuell) oder würfelt (random) Mods.
- Berechne Belohnungs-Multiplikatoren je nach Mod.

---

## 🏆 Belohnungslogik

Prinzip: Schwerer = Bessere Belohnung.

Schritt-für-Schritt
- Definiere Grundbelohnung pro Tier.
- Multipliziere Belohnung abhängig von Modifikatoren.
- Verknüpfe Mod-Typ mit Belohnungstyp (z. B. Gegnerstärke = XP, Map-Bedingung = Währung).

---

## ♾️ Beyond T16

Unendliche Skalierung.

Schritt-für-Schritt
- Erlaube Stapeln von Mods.
- Erhöhe Werte exponentiell.
- Füge Leaderboards oder Rekorde hinzu.
