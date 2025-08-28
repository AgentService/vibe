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

Abilities will use Godot Resources (.tres files) following the pattern established by the enemy system:

```tres
[gd_resource type="Resource" script_class="AbilityType" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/domain/AbilityType.gd" id="1"]
[resource]
script = ExtResource("1")
id = "fireball"
display_name = "Fireball"
ability_type = "projectile"
damage_base = 25.0
damage_scaling = ["spell_damage", "fire_damage"]
cooldown = 1.5
projectile_speed = 400.0
projectile_count = 1
projectile_pattern = "straight"
tags = ["spell", "fire", "projectile"]
vfx_scene = "res://effects/fireball.tscn"
supported_gems = ["multiple_projectiles", "faster_casting"]
```

## Related Systems (Future)

- **ContentDB**: Will load and validate ability definitions
- **AbilitySystem**: Handles casting, cooldowns, and effects
- **Hero/Class System**: Determines available abilities
- **Support Gem System**: Modifies ability behavior

## Hot-Reload

Will support **automatic hot-reload** when implemented, using Godot's native resource reloading system.

---

**Next Steps**: Define ability schema and implement ContentDB loading