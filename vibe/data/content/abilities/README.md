# Ability Definitions

Skill and ability definitions for players and enemies.

## Implementation Status

**Status**: 📋 **TODO** - Not yet implemented

## Planned Features

When implemented, abilities will include:
- **Damage calculations** with scaling formulas
- **Cooldown and resource costs** (mana, stamina, etc.)
- **Projectile patterns** and targeting behaviors
- **Visual/Audio effects** references
- **Modifier tags** for stat scaling and interactions
- **Support gem compatibility** (PoE-style linked skills)

## Schema (Planned)

```json
{
  "id": "fireball",
  "name": "Fireball",
  "type": "projectile",
  "damage": {
    "base": 25,
    "scaling": ["spell_damage", "fire_damage"]
  },
  "cooldown": 1.5,
  "projectile": {
    "speed": 400,
    "count": 1,
    "pattern": "straight"
  },
  "tags": ["spell", "fire", "projectile"],
  "vfx": "res://effects/fireball.tscn",
  "supports": ["multiple_projectiles", "faster_casting"]
}
```

## Related Systems (Future)

- **ContentDB**: Will load and validate ability definitions
- **AbilitySystem**: Handles casting, cooldowns, and effects
- **Hero/Class System**: Determines available abilities
- **Support Gem System**: Modifies ability behavior

## Hot-Reload

Will support **F5** hot-reload when implemented.

---

**Next Steps**: Define ability schema and implement ContentDB loading