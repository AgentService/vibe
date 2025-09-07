# Vibe Roguelike – Next Steps Plan

**Datum:** 2025-09-07  
**Autor:** Professor Synapse (via ChatGPT)

---

## 🎯 Ziel

Diese Datei enthält eine klare Abfolge von Phasen und Aufgaben, um den aktuellen Stand des Projekts zu überprüfen, bei Bedarf zu resetten oder anzupassen, und die nächsten Schritte für Game Flow, Hideout und Ability-System umzusetzen.

---

## 🔍 Phase 0 – System-Überprüfung

1. **State-Handling**: Sind Zustände klar getrennt oder steckt Logik in Szenen?  
2. **Charakter-System**: Werden Klassen datengetrieben oder per If-Abfragen gehandhabt?  
3. **Save-System**: Sind Run-Daten und Meta-Daten getrennt?  
4. **Ability-System**: Ist es modular oder monolithisch? Reset bei Bedarf.

---

## 🏗️ Phase 1 – State Manager
- Zentralen State Manager anlegen.  
- Test: Menü → Hideout → Arena → Menü.

---

## 🧙 Phase 2 – Charakter-Klassen
- ClassDefinition als Datenobjekte.  
- Zwei Testklassen definieren und prüfen.

---

## 💾 Phase 3 – Savegames
- Run-Daten von Meta-Daten trennen.  
- Test: Charakter bleibt erhalten, Run wird verworfen.

---

## 🏠 Phase 4 – Hideout
- Interaktionspunkte modular anlegen.  
- Test: Mehrere Interaktionen möglich.

---

## 🔥 Phase 5 – Ability-System & Klassen
- Fähigkeiten mit Tags versehen.  
- Klassen nutzen nur passende Tags.  

---

## ✅ Phase 6 – Done-Kriterien
- State Manager kontrolliert Fluss.  
- Klassen sind datengetrieben.  
- Savegames sind getrennt.  
- Hideout modular.  
- Ability-System entkoppelt.
