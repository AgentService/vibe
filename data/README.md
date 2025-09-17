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
