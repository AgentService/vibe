# Item Definitions

Equipment and loot definitions including stats, affixes, and properties.

## Implementation Status

**Status**: 📋 **TODO** - Not yet implemented

## Planned Features

When implemented, items will include:
- **Base item types** (weapons, armor, accessories)
- **Affix system** with tiers and roll ranges
- **Rarity system** (normal, magic, rare, unique)
- **Requirements** (level, stats, class restrictions)
- **Socket system** for support gems
- **Auction House readiness** with searchable properties

## Schema (Planned)

```json
{
  "id": "iron_sword",
  "name": "Iron Sword",
  "type": "weapon",
  "subtype": "one_handed_sword",
  "rarity": "normal",
  "level_requirement": 5,
  "base_stats": {
    "physical_damage": {"min": 8, "max": 12},
    "attack_speed": 1.2,
    "critical_chance": 0.05
  },
  "affix_pools": ["weapon_physical", "weapon_general"],
  "sockets": {"max": 3, "links": 2},
  "tags": ["weapon", "melee", "sword"]
}
```

## Auction House Preparation

Items will include properties for future trading:
- **Unique ID**: Globally unique identifier
- **Ownership**: Creator/owner tracking
- **Deterministic serialization**: Consistent JSON output
- **Searchable facets**: Type, rarity, affix values
- **Version field**: For schema migration

## Related Systems (Future)

- **ContentDB**: Will load base item definitions
- **Loot System**: Generates items with random affixes  
- **Inventory System**: Item storage and management
- **Crafting System**: Item modification and enhancement
- **Auction House**: Item trading (future multiplayer feature)

## Hot-Reload

Will support **F5** hot-reload when implemented.

---

**Next Steps**: Design item schema with auction house compatibility