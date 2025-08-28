# Game Data Schemas

This directory contains game balance and configuration data in both .tres resources and JSON files. Complex content uses .tres format for type safety and Inspector editing, while simple configuration remains in JSON format. All data is loaded through the BalanceDB autoload singleton.

## Directory Structure

```
/data/
├── balance/          # Balance tunables (.tres resources)
│   ├── combat_balance.tres    # Combat system values
│   ├── abilities_balance.tres # Ability system configuration  
│   ├── waves_balance.tres     # Wave director and enemy settings
│   ├── player_balance.tres    # Player base stats
│   └── melee_balance.tres     # Melee combat system
├── cards/            # Card system data (.tres resources)
│   ├── melee/        # Melee enhancement cards
│   └── pools/        # Card pool definitions
├── content/          # Game content definitions (.tres resources)
│   ├── enemies/      # Enemy type definitions (.tres files)
│   ├── abilities/    # Ability definitions (planned .tres)
│   ├── items/        # Item definitions (planned .tres)
│   ├── heroes/       # Hero/class definitions (planned .tres)
│   ├── maps/         # Map definitions (planned .tres)
│   └── arena/        # Arena configurations (.tres files)
├── animations/       # Animation configurations (.tres resources)
│   └── *_animations.tres  # Frame data and timing for each enemy type
├── debug/            # Debug and logging configuration
│   └── log_config.tres    # Logger configuration
├── ui/               # UI component configuration
│   └── radar_config.tres  # Enemy radar settings (.tres resource)
└── xp_curves.tres    # Experience progression curves (.tres resource)
```

## Resource Format Guidelines

### .tres Resources (Primary Format)
- **Complex content**: Enemies, abilities, items, heroes, maps
- **Balance data**: Combat, abilities, waves, player, melee settings  
- **Configuration data**: Logging, UI, XP curves
- **Benefits**: Type safety, Inspector editing, validation, hot-reload

### JSON Files (Legacy/Simple Config)
- **Simple configurations**: Enemy registry, enemy tiers
- **Benefits**: Easy AI assistance, text editing, version control diffs

## Balance Resource Classes

### Resource Classes

All .tres resources are backed by typed GDScript resource classes:

- **CombatBalance**: Combat system values (collision, damage, crits)
- **AbilitiesBalance**: Ability system configuration  
- **WavesBalance**: Wave spawning and enemy settings
- **PlayerBalance**: Player base stats and modifiers
- **MeleeBalance**: Melee combat system values
- **LogConfigResource**: Debug logging configuration
- **RadarConfigResource**: Enemy radar UI settings  
- **XPCurvesResource**: Experience progression curves

## Content Creation Workflow

### Creating New .tres Resources

1. **Create Resource Class**: Define a new resource class in `scripts/domain/`
   ```gdscript
   extends Resource
   class_name MyConfigResource
   
   @export var my_property: float = 1.0
   @export var my_enum: MyEnum = MyEnum.DEFAULT
   ```

2. **Use Inspector**: Create .tres files using Godot's Inspector
   - Right-click in FileSystem dock
   - Create → Resource
   - Select your resource class
   - Set properties in Inspector
   - Save as .tres file

3. **Load in Code**: Use ResourceLoader in systems
   ```gdscript
   var config: MyConfigResource = load("res://data/my_config.tres")
   if config:
       my_value = config.my_property
   ```

### Hot-Reload Support

- **Automatic Balance Files**: 0.5 second auto-reload for files registered in BalanceDB
- **Scene Resources**: Instant hot-reload for @export resources (arena, player configs)
- **F5 Fallback**: Manual reload trigger for all resources

## Hot Reloading

The BalanceDB singleton provides automatic hot-reloading for balance files during development:

### **Auto-Reload (0.5s)**
Balance files are automatically monitored and reloaded when changed:
```gdscript
// Currently monitored files in BalanceDB._setup_auto_reload():
- res://data/balance/combat_balance.tres
- res://data/balance/abilities_balance.tres  
- res://data/balance/melee_balance.tres
- res://data/balance/player_balance.tres
- res://data/balance/waves_balance.tres
- res://data/ui/radar_config.tres
```

### **Adding New Auto-Reload Files**
To add a new balance file to auto-reload monitoring:
1. Add file path to `_balance_files` dictionary in `BalanceDB._setup_auto_reload()`
2. Ensure file is loaded in `BalanceDB.load_all_balance_data()`
3. Test file changes are detected within 0.5 seconds

### **Manual Reload**  
- **F5 Key**: Triggers full resource reload for all files
- **Signal**: Listen to `BalanceDB.balance_reloaded` for updates

## Fallback Values

All systems include hardcoded fallback values. If a .tres resource fails to load, systems log warnings and continue with fallbacks to prevent crashes.

## Adding New Balance Values

1. Add new @export property to appropriate resource class
2. Update fallback values in `BalanceDB.gd` 
3. Set default value in .tres file using Inspector
4. Update consuming systems to use new property
5. Update this documentation

## Adding New Enemy Types

The enemy system uses .tres resources with automatic discovery. To add a new enemy type:

1. **Create enemy resource**: Add `data/content/enemies/new_enemy.tres` using EnemyType resource class
2. **Set spawn weight**: Configure `spawn_weight` property in the .tres file
3. **Add sprite sheet**: Place sprite sheet texture in `assets/sprites/` (if needed)
4. **Test integration**: Run enemy tests to verify resource validity

The EnemyRegistry automatically discovers all .tres files in the enemies directory without requiring manual registration.

## Enemy System Schemas

### content/enemies/*.tres

Individual enemy configurations using Godot Resources. See `/data/content/enemies/README.md` for complete schema and editing workflow.

**Example**: `knight_regular.tres`
- Uses `EnemyType` resource class with typed properties
- Editable in Godot Inspector or as text
- Automatic hot-reload when files change
- Type safety and validation built-in

### animations/*_animations.tres

Animation configurations using .tres resources with type-safe properties. See specific animation files for resource class definitions and Inspector editing workflows.

**Example**: `knight_animations.tres`
- Uses `AnimationConfig` resource class
- Sprite sheet path, frame dimensions, timing data
- Automatic hot-reload when changed
- Type safety and validation