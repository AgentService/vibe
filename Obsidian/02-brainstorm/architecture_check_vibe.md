# Architektur-Basis-Check für Vibe Roguelike

**Datum:** 2025-09-07  
**Autor:** Professor Synapse (via ChatGPT)

---

## 🏛️ Architektur-Checkliste

### Phase 1: Trennung der Zuständigkeiten
- Jede Klasse hat nur eine Aufgabe.  

### Phase 2: Event-Architektur
- Lose Kopplung via EventBus. Keine direkten Abhängigkeiten.  

### Phase 3: Datengetrieben
- Gegner, Fähigkeiten, Karten kommen aus Daten.  

### Phase 4: Performance
- Object-Pooling prüfen.  
- Test: 500+ Gegner.  

---

## ✅ Done-Kriterien
- Verantwortlichkeiten getrennt.  
- EventBus konsequent.  
- Inhalte datengetrieben.  
- Performance stabil.
