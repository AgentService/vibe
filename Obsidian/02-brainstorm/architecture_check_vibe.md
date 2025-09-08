# Architektur-Basis-Check (Vibe)

**Datum:** 2025-09-08  
**Autor:** Professor Synapse (via ChatGPT)

---

## 🎯 Ziel
Schnelle, wiederholbare Prüfung der Architektur-Konventionen gemäß docs/ARCHITECTURE_QUICK_REFERENCE.md und docs/ARCHITECTURE_RULES.md. Fokus: Verantwortlichkeiten, Events, Daten, Performance/Determinismus.

---

## 🧩 Verantwortlichkeiten & Grenzen
Checkliste
- [ ] Systeme liegen unter `scripts/systems/*` und sind entkoppelt (keine Cross-Layer Reach-ins).
- [ ] Szenen steuern Orchestrierung; eine Szene = ein Skript; minimaler Node-Baum.
- [ ] Komponenten sprechen via Signale/Callbacks mit Owner, keine Tree-Scans.
- [ ] Autoloads klein & fokussiert: `EventBus`, `Logger`, `GameOrchestrator`, `RNG`, `RunManager`.

---

## 🔔 Events & Signale
Checkliste
- [ ] Cross-System via `EventBus.gd` (typed signals, Vergangenheitsform).
- [ ] Verbindungen in `_ready()` oder `setup()`, Trennung in `_exit_tree()`.
- [ ] Keine direkten Modulaufrufe für Querschnitts-Flow (nur Signale/Services).

---

## 🗃️ Daten & Ressourcen
Checkliste
- [ ] Tunables als `.tres` unter `data/*` (keine Magic Numbers in Gameplay-Code).
- [ ] Preload für Hot Paths, `ResourceLoader` für seltene Pfade.
- [ ] Trennung Run-Daten vs. Meta-Daten (siehe Save/RunManager).

---

## ⚔️ Damage v2 Pfad (einheitlich)
Prinzipien
- [ ] Alle Schaden-Anfragen über `DamageRegistry.gd` (Service), nie direkt `_damage()`.
- [ ] Payload-Form: `{source: String, target: String, base_damage: float, tags: Array[StringName|String]}`.
- [ ] Signal-Sequenz: `damage_requested` → `damage_applied` → `damage_taken`.
- [ ] IDs sind Strings (`"player"`, `"enemy_15"`, `"boss_ancient_lich"`), Auflösung via Registry/Services.

---

## ⏱️ Performance & Determinismus
Checkliste
- [ ] Kein unnötiges `_process/_physics_process` (deaktiviert, wenn ungenutzt).
- [ ] Vermeide per-Frame Allokationen; Arrays/Dicts wiederverwenden; Node-Refs cachen.
- [ ] Physik-Layer/Areas für Filter statt manueller Checks.
- [ ] RNG deterministisch in Tests (RNG Autoload oder lokaler RNG mit Seed).

---

## 🧪 Tests
Checkliste
- [ ] Isolierte Tests unter `tests/*` spiegeln Systeme/Flows (Suffix `_Isolated`- [ ] Tests laufen headless via `tests/cli_test_runner.gd` oder Batch-Script.
- [ ] Keine Global-State-Leaks; Autoloads resetten/stubben pro Test.

---

## ✅ Quick-Run Prüfliste (Empfohlen)
- [ ] `State Manager`: Menü → Hideout → Arena → Menü (Flow intakt).
- [ ] `Character System`: Klassen datengetrieben (Resources/Defs), keine `if class ==`.
- [ ] `Save`: Meta- vs. Run-Daten getrennt; Run-Abbruch verwirft nur Run.
- [ ] `Ability`: modular, Tags für Klassen-Synergien; keine harte Kopplung.

---

## 📌 Hinweise
- Abweichungen dokumentieren und Tasks unter `Obsidian/03-tasks/` anlegen.
- Bei Änderungen an Grenzen/Flows: `docs/ARCHITECTURE_*` aktualisieren und Tests ergänzen.
