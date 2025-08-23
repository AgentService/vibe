# Hero/Class Definitions

Player character class and hero definitions with abilities and progression.

## Implementation Status

**Status**: 📋 **TODO** - Not yet implemented

## Planned Features

When implemented, heroes will include:
- **Starting abilities** and skill loadouts
- **Base stats** (strength, dexterity, intelligence)
- **Passive tree positioning** (PoE-style skill tree access)
- **Ascendancy options** for specialization
- **Equipment restrictions** and preferences
- **Progression unlocks** and milestones

## Schema (Planned)

```json
{
  "id": "knight",
  "name": "Knight",
  "description": "Melee warrior with defensive abilities",
  "base_stats": {
    "strength": 18,
    "dexterity": 12,
    "intelligence": 10,
    "vitality": 15
  },
  "starting_abilities": ["melee_strike", "defensive_stance"],
  "passive_tree_start": "strength_cluster_1",
  "ascendancies": ["paladin", "berserker"],
  "equipment_preferences": {
    "weapon": ["sword", "axe", "mace"],
    "armor": ["heavy"]
  },
  "unlock_requirements": null
}
```

## Design Philosophy

### Hero as Ability Container
- Heroes define **which abilities** are available
- Abilities themselves are separate content (see `/abilities/`)
- Supports flexible mixing of skills across classes

### PoE-Inspired Progression
- **Passive skill tree** shared across classes
- **Starting position** determines early access
- **Ascendancy system** for late-game specialization
- **Run upgrades** (temporary) vs **persistent progression**

## Related Systems (Future)

- **ContentDB**: Will load hero definitions
- **Ability System**: Manages hero skill loadouts
- **Passive Tree**: Character progression system
- **Ascendancy System**: Advanced specialization
- **Character Creation**: Hero selection UI

## Hot-Reload

Will support **F5** hot-reload when implemented.

---

**Next Steps**: Define hero schema and relationship with ability system