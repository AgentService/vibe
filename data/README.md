# Data Configuration Files Index

This directory contains all game configuration files using the **hybrid functional + flat** organization structure for improved developer experience.

## Directory Structure

```
data/
├── core/                    # Essential game mechanics (most accessed)
├── balance/                 # All tuning values (designer focus)  
├── content/                 # Asset-heavy configurations
├── debug.tres              # Debug configuration (consolidated)
└── ui.tres                 # UI configuration (consolidated)
```

## Core Files (`/data/core/`)

**Essential game mechanics - most frequently accessed by developers:**

- `character-types.tres` - Player character definitions and stats
- `progression-xp-curve.tres` - XP curve configuration and level thresholds
- `boss-scaling.tres` - Boss scaling multipliers for debug mode

## Balance Files (`/data/balance/`)

**All tuning values - primary focus for game designers:**

- `combat.tres` - Combat balance parameters
- `melee.tres` - Melee combat specific balance
- `player.tres` - Player stats and capabilities
- `waves.tres` - Wave spawning and difficulty scaling
- `visual-feedback.tres` - Visual feedback timing and intensity

## Content Files (`/data/content/`)

**Asset-heavy configurations:**

### Animation Configs
- `regular_enemy_animations.tres` - Regular enemy animation frames
- `elite_enemy_animations.tres` - Elite enemy animation frames
- `boss_enemy_animations.tres` - Boss enemy animation frames
- `swarm_enemy_animations.tres` - Swarm enemy animation frames
- `knight_animations.tres` - Knight character animations

### Enemy Definitions
- `enemy-templates/` - Base enemy templates (boss_base.tres, melee_base.tres, ranged_base.tres)
- `enemy-variations/` - Scene-based enemy variations (ancient_lich.tres, banana_lord.tres, dragon_lord.tres)
- `enemy-variations-mesh-backup/` - Backup of MultiMesh enemy variations (archived)

### Cards & Items
- `cards-melee/` - Melee upgrade cards (damage_boost.tres, attack_speed.tres, etc.)
- `melee_pool.tres` - Melee card pool configuration
- `items/` - Item definitions with dual-resource pattern (*_gameplay.tres, *_metadata.tres)

### Game Content
- `default_arena.tres` - Arena configuration
- `default_player.tres` - Default player configuration  
- `unlocks.tres` - Player progression unlocks

### Map Configurations
- `maps/` - Arena and map configurations
  - `underworld_config.tres` - Underworld arena configuration (MapConfig)
  - `tilesets/` - TileSet resources for map building
  - `UNDERWORLD_SETUP_GUIDE.md` - Setup instructions for underworld arena

## Flat Configuration Files

**Single-file configurations for simplified access:**

- `debug.tres` - Debug logging configuration (consolidated from debug/ folder)
- `ui.tres` - UI configuration including radar settings (consolidated from ui/ folder)
- `ui-debug-theme.tres` - Debug UI theme resources

## Hot-Reload Support

All configuration files support F5 hot-reload for rapid development:

- **Core files**: Reloaded by respective managers (DebugManager, PlayerProgression)
- **Balance files**: Reloaded by BalanceDB autoload system
- **Content files**: Reloaded by content loading systems (EnemyFactory, CardSystem)

## Usage Patterns

### For Game Designers
Start with `/data/balance/` - all tuning values are here with descriptive names.

### For Developers  
Start with `/data/core/` for essential mechanics, then `/data/content/` for assets.

### For Debug/Testing
Use `/data/debug.tres` for logging config and `/data/core/boss-scaling.tres` for debug scaling.

## Migration Notes

This structure was migrated from the previous nested organization to:
- **Reduce search time** - developers can find any config in <10 seconds
- **Logical grouping** - related configs are organized by function
- **Consistent naming** - predictable file names following clear patterns
- **Easy discovery** - new developers can quickly understand available options
- **Preserved hot-reload** - all F5 functionality maintained

## Resource Format Guidelines

### .tres Resources (Primary Format)
- **Complex content**: Enemies, abilities, items, heroes, maps
- **Balance data**: Combat, abilities, waves, player, melee settings  
- **Configuration data**: Logging, UI, XP curves
- **Benefits**: Type safety, Inspector editing, validation, hot-reload

### Hot-Reload Patterns
- **Scene-based resources**: Use `@export var resource: ResourceType` for automatic Inspector hot-reload
- **System-based resources**: Use `ResourceLoader.load()` with file monitoring for autoload systems
- **Auto-reload**: Balance files monitored with 0.5s detection via BalanceDB
- **Manual reload**: F5 key triggers full resource reload

## Auto-Reload Configuration

Currently monitored files in BalanceDB:
```gdscript
- res://data/balance/combat.tres
- res://data/balance/melee.tres
- res://data/balance/player.tres
- res://data/balance/waves.tres
- res://data/ui.tres
```

## Sprite Import Guidelines

### Pixel Art Import Settings
For optimal pixel-perfect rendering with mixed sprite sizes (16x16, 48x48, 64x64):

**Required Import Settings:**
- **Filter**: OFF (maintains pixel crispness)
- **Mipmaps**: OFF (prevents blur at different scales)
- **Fix Alpha Border**: ON (prevents edge artifacts)

**Scaling Strategy:**
- **Base Unit**: 16x16 pixels as fundamental unit
- **48x48 sprites**: 3x scale (16×3=48)
- **64x64 sprites**: 4x scale (16×4=64)
- **Consistent Density**: All sprites maintain same pixel-per-unit ratio

**Project Display Settings:**
- **Stretch Mode**: "viewport" with aspect "keep"
- **Texture Filter**: 0 (nearest neighbor)
- **Snap 2D**: Transforms and vertices snapped to pixels
- **MSAA**: Disabled for pure pixel art aesthetics

## Schema Documentation

See individual config files for their data schemas. Each `.tres` file corresponds to a GDScript Resource class in `/scripts/domain/` or `/scripts/resources/`.

### Item System Schema (2025-10-14)

The item system uses a **dual-resource pattern** with coupled filenames for clean separation of gameplay and catalog concerns:

#### File Naming Convention

```
data/content/items/
  ├── {item_id}_gameplay.tres    # BaseItem (procs, stats, cooldowns)
  └── {item_id}_metadata.tres    # ItemMetadata (display, icon, unlock)
```

**Examples:**
- `thunder_mitts_gameplay.tres` + `thunder_mitts_metadata.tres`
- `cheese_gameplay.tres` + `cheese_metadata.tres`
- `clover_gameplay.tres` + `clover_metadata.tres`

#### BaseItem Schema (`{item_id}_gameplay.tres`)

**Resource Class:** `res://scripts/resources/items/BaseItem.gd`

**Core Identity:**
```gdscript
@export var item_id: String = ""           # Unique identifier (matches metadata)
@export var internal_name: String = ""     # Debug name
```

**Stat Bonuses (Applied to Player.runtime_stats):**
```gdscript
@export var max_hp_bonus: int = 0                    # Flat HP addition (additive stacking)
@export var movement_speed_mult: float = 1.0         # Speed multiplier (multiplicative stacking)
@export var damage_mult: float = 1.0                 # Damage multiplier (multiplicative stacking)
@export var pickup_radius_mult: float = 1.0          # Pickup radius multiplier (multiplicative)
@export var crit_chance_bonus: float = 0.0           # Crit chance addition (additive, 0.1 = +10%)
```

**Proc Type 1: Lightning (Cooldown-Based):**
```gdscript
@export var on_hit_lightning: bool = false           # Enable lightning proc
@export var lightning_cooldown: float = 10.0         # Cooldown in seconds
@export var lightning_damage_mult: float = 0.5       # % of triggering hit's damage
@export var lightning_chain_count: int = 0           # Additional targets (0 = single target)
@export var lightning_chain_range: float = 200.0     # Chain range in pixels
```

**Proc Type 2: Explosion (Chance-Based):**
```gdscript
@export var on_hit_explosion: bool = false           # Enable explosion proc
@export var explosion_chance: float = 0.25           # Proc chance (0.25 = 25%)
@export var explosion_damage_mult: float = 0.65      # % of triggering hit's damage
@export var explosion_radius: float = 100.0          # AOE radius in pixels
```

**Proc Type 3: Freeze (Chance-Based):**
```gdscript
@export var on_hit_freeze: bool = false              # Enable freeze proc
@export var freeze_chance: float = 0.075             # Proc chance (0.075 = 7.5%)
@export var freeze_duration: float = 2.0             # Freeze duration in seconds
@export var freeze_slow_mult: float = 0.0            # Speed reduction (0.0 = full freeze)
```

**Proc Type 4: Poison (Chance-Based with Overflow Scaling):**
```gdscript
@export var on_hit_poison: bool = false              # Enable poison proc
@export var poison_chance: float = 0.4               # Base proc chance (0.4 = 40%)
@export var poison_duration: float = 3.0             # DoT duration in seconds
@export var poison_damage_per_tick: float = 0.3      # % of hit as poison damage over duration
# Overflow: >100% proc chance converts to damage multiplier (50 stacks = 100% + 20x damage)
```

**Example Item:**
```tres
[gd_resource type="Resource" script_class="BaseItem" load_steps=2 format=3]
[ext_resource type="Script" path="res://scripts/resources/items/BaseItem.gd" id="1"]

[resource]
script = ExtResource("1")
item_id = "thunder_mitts"
internal_name = "Thunder Mitts"
on_hit_lightning = true
lightning_cooldown = 10.0
lightning_damage_mult = 0.5
lightning_chain_count = 2
lightning_chain_range = 250.0
```

#### ItemMetadata Schema (`{item_id}_metadata.tres`)

**Resource Class:** `res://scripts/resources/ItemMetadata.gd`

**Properties:**
```gdscript
@export var item_id: String = ""                     # Unique identifier (matches gameplay)
@export var display_name: String = ""                # UI display name
@export var description: String = ""                 # Tooltip/shop description
@export var icon: Texture2D = null                   # Item icon
@export var unlock_cost: int = 0                     # Rift Fragments cost
@export var quest_requirement: String = ""           # Quest ID to unlock
@export var rarity: String = "common"                # Rarity tier (common/rare/epic/legendary)
```

**Example Metadata:**
```tres
[gd_resource type="Resource" script_class="ItemMetadata" load_steps=3 format=3]
[ext_resource type="Script" path="res://scripts/resources/ItemMetadata.gd" id="1"]
[ext_resource type="Texture2D" path="res://assets/items/thunder_mitts_icon.png" id="2"]

[resource]
script = ExtResource("1")
item_id = "thunder_mitts"
display_name = "Thunder Mitts"
description = "Strikes lightning on hit every 10 seconds, chaining to 2 nearby enemies."
icon = ExtResource("2")
unlock_cost = 500
rarity = "rare"
```

#### Stacking Formulas

**Multiplicative Bonuses (Compound Exponentially):**
```gdscript
# Example: 3x Feather (+15% speed each)
movement_speed_mult = pow(1.15, 3) = 1.52x total speed

# Example: 3x Clover (+30% pickup radius each)
pickup_radius_mult = pow(1.3, 3) = 2.197x total radius
```

**Additive Bonuses (Linear Scaling):**
```gdscript
# Example: 3x Health Ring (+25 HP each)
max_hp_bonus = 25 * 3 = 75 HP total

# Example: 3x Rabbits Foot (+10% crit chance each)
crit_chance_bonus = 0.1 * 3 = 0.3 (30% crit chance)
```

**Proc Chance Stacking (Multiplicative Probability):**
```gdscript
# Example: 3x Spicy Meatball (25% explosion chance each)
effective_chance = 1 - pow(1 - 0.25, 3) = 57.8%

# Example: 50x Cheese (40% poison chance each)
effective_chance = 1 - pow(1 - 0.4, 50) = 100% (capped)
# Overflow: excess 100% * 50 = 5000% → damage_multiplier = 1 + 49 = 50x
```

#### Integration Points

**ItemManager Autoload:**
- Dual registry: `get_base_item(item_id)` for gameplay, `get_item_metadata(item_id)` for catalog
- EventBus consumers: `damage_dealt` (proc checks), `combat_step` (cooldown updates)
- Player integration: `set_player()` for stat bonus application

**Quest System:**
```gdscript
# Quest completion unlocks items
MetaProgression.discover_item("items", "thunder_mitts")
MetaProgression.unlock_item("items", "thunder_mitts")
```

**Shop System:**
```gdscript
# Shop displays metadata
var metadata = ItemManager.get_item_metadata("thunder_mitts")
shop_ui.display_item(metadata.display_name, metadata.icon, metadata.unlock_cost)
```

**Chest/Reward System:**
```gdscript
# Chest spawns gameplay resource
ItemManager.equip_item("thunder_mitts")  # Loads BaseItem, applies stats/procs
```

#### Item Categories

**Proc Items (On-Hit Effects):**
- Thunder Mitts (lightning chains)
- Spicy Meatball (explosion AOE)
- Frost Glaive (freeze slow)
- Cheese (poison DoT with overflow)

**Stat Items (Passive Bonuses):**
- Feather (+15% movement speed)

**Utility Items (Future Systems):**
- Clover (+30% pickup radius)
- Rabbits Foot (+10% crit chance)
- Lucky Coin (luck/drop rate - TBD)
