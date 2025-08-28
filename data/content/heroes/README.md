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

Heroes will use Godot Resources (.tres files) following the pattern established by the enemy system:

```tres
[gd_resource type="Resource" script_class="HeroType" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/domain/HeroType.gd" id="1"]
[resource]
script = ExtResource("1")
id = "knight"
display_name = "Knight"
description = "Melee warrior with defensive abilities"
strength_base = 18
dexterity_base = 12
intelligence_base = 10
vitality_base = 15
starting_abilities = ["melee_strike", "defensive_stance"]
passive_tree_start = "strength_cluster_1"
ascendancies = ["paladin", "berserker"]
weapon_preferences = ["sword", "axe", "mace"]
armor_preferences = ["heavy"]
unlock_requirements = ""
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

Will support **automatic hot-reload** when implemented, using Godot's native resource reloading system.

---

**Next Steps**: Define hero schema and relationship with ability system