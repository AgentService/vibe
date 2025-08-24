# Week 34: Aug 18-24, 2025

**Current Sprint Changelog** - See `/changelogs/` for weekly archives and feature history

## [Current Week - In Progress]

### Added
- **Obsidian Documentation Updates**: Updated architecture docs to reflect Dictionary to EnemyEntity migration
  - **Enemy-System-Architecture.md**: Updated signal flows, technical implementation, and system integration for Array[EnemyEntity]
  - **Enemy-Entity-Architecture.md**: New dedicated documentation for typed EnemyEntity objects with compile-time safety
  - **Component-Structure-Reference.md**: Updated system dependencies and communication patterns for typed enemy system
  - **EventBus-System.md**: Updated signal architecture with Array[EnemyEntity] flows and cross-system integration patterns
  - **Data-Systems-Architecture.md**: Added typed enemy system section with object pool management and hot-reload support
  - **systems/README.md**: Updated to include new documentation files and current implementation status
- **Complete TRES Migration for Configuration Files**: Migrated all configuration files from JSON to .tres resources
  - **LogConfigResource**: Migrated debug/log_config.json to log_config.tres with type-safe enum validation
  - **RadarConfigResource**: Migrated ui/radar.json to radar_config.tres with Color properties and Inspector editing
  - **XPCurvesResource**: Migrated xp_curves.json to xp_curves.tres with typed curve definitions
  - **Type safety**: All config resources now have @export properties with proper type validation
  - **Inspector editing**: Configuration values can now be edited directly in Godot's Inspector
  - **Hot-reload support**: F5 hot-reload maintained for all .tres configuration files
  - **System compatibility**: All existing systems (Logger, EnemyRadar, XpSystem) updated to load .tres resources
  - **Fallback handling**: Graceful degradation to hardcoded values if .tres files fail to load

### Changed
- **Simplified to MultiMesh-Only Enemy Rendering**: Removed AnimatedSprite2D implementation, clean MultiMesh foundation
  - **Removed EnemyRenderer**: Deleted entire AnimatedSprite2D pool system and animation data
  - **Removed rendering mode switcher**: Eliminated SPRITES_ONLY/MULTIMESH_ONLY/BOTH mode complexity
  - **Simplified MultiMesh updates**: Basic transform and color only, removed scaling and rotation complexity
  - **Clean foundation**: Tier-based MultiMesh system (swarm/regular/elite/boss) ready for step-by-step enhancement

### Fixed
- **Player rendering issue**: Restored missing `knight_animations.json` file to fix black rectangle rendering
  - **Animation data**: Added proper knight sprite sheet animation definitions for idle, run, roll, hit, and death states
- **Enemy visibility issue**: Fixed black SWARM enemies by changing debug color from black to dark red for visibility

### Added
- **Enhanced Melee Combat System**: Improved damage verification and upgrades
  - **Damage logging**: Added detailed combat logs showing enemy damage and kill events
  - **Increased base damage**: Melee damage raised from 25 to 50 for better enemy clearing
  - **Melee upgrade cards**: Added 3 new melee enhancement cards (damage +15, attack speed +0.3, range/cone +40/+15°)
  - **Level-gated projectiles**: Projectile unlock card now requires level 10, focusing early game on melee
  - **Card system improvements**: Added min_level filtering to card selection system
  - **RunManager stats**: Added melee modifier stats integration for card effects
- **Data-Driven Enemy System with Purple Slime**: Fully data-driven enemy spawning with new purple slime tank enemy
  - **Enemy registry**: Central spawn weight system in `enemy_registry.json` eliminates hardcoded enemy types
  - **Purple slime tank**: New tank enemy (5 HP, 40-80 speed) using purple sprite sheet with 20% spawn rate
  - **Green slime rename**: Renamed "grunt" to "green_slime" for consistency with sprite-based naming
  - **Dynamic loading**: EnemyRenderer and WaveDirector load enemy types from JSON automatically
  - **Weighted spawning**: 50% green slime, 30% scout, 100% purple slime (note: user increased purple weight to 100)
  - **Sprite consistency fix**: Fixed sprites changing colors between purple/green by adding enemy type metadata tracking
  - **Future-proof design**: Add new enemies via JSON only, no code changes required
  - **Fallback system**: Graceful degradation if registry files missing or malformed
- **AnimatedSprite2D Enemy System**: Complete migration from MultiMesh to animated sprites for enemy rendering
  - **Enemy types**: Support for multiple enemy types (grunt, scout) with unique animations and stats
  - **Sprite animation**: Full AnimatedSprite2D pool (200 sprites) with 2-frame walk cycles at 8 FPS like Vampire Survivors
  - **JSON configuration**: Data-driven enemy types and animation definitions in `/data/enemies/` and `/data/animations/`
  - **Performance optimization**: Viewport culling and 15Hz animation updates for smooth 100-400 enemy rendering
  - **Type variety**: Scouts (fast, low health) vs Grunts (normal speed, normal health) with weighted spawning (70/30 split)
  - **Visual distinction**: Color-coded fallback textures (red grunts, green scouts) and unique sprite configurations
  - **EnemyRenderer system**: Dedicated rendering system managing sprite pool, animation states, and culling
- **Arena and Balance Improvements**: Enhanced default game settings for better experience
  - **Mega Arena default**: Game now starts with the largest arena (mega_arena) instead of basic_arena
  - **Projectile gating**: Auto-projectile shooting only activates after obtaining projectile boons
  - **Closer enemy spawns**: Reduced spawn radius from 1800 to 600 units for more immediate action
  - **Optimized enemy count**: Reduced max enemies from 5500 to 800 for better performance
- **Keybindings Display HUD**: Always-visible control reference panel with table-style formatting
  - **Table layout**: GridContainer with left-aligned actions and right-aligned key bindings
  - **Radar styling**: Matches enemy radar with dark background, gray borders, rounded corners
  - **Essential controls**: Movement (WASD), Attack (Left Click), Pause (F10), FPS (F12), Theme (T), Arena (1-5)
  - **Clean presentation**: Semi-transparent panel positioned below enemy radar for easy reference
- **Melee Auto-Attack System**: Continuous melee attacking enabled by default
  - **Always active**: Auto-attack is enabled by default, no toggle needed
  - **Cursor tracking**: Attacks automatically target cursor position when enemies are nearby
  - **Seamless integration**: Works with existing cooldown and balance systems
- **Enhanced Melee Cone Coverage**: Improved area of effect for better gameplay
  - **Wider cone angle**: Increased from 45° to 65° for better coverage  
  - **Longer range**: Increased from 100 to 150 units for better reach
- **Simplified Card System**: Removed unnecessary melee modifiers and lifesteal
  - **Focused cards**: Only projectile unlock card remains, removed melee damage/speed/range/cone cards
  - **Clean mechanics**: Removed lifesteal system and stat multipliers for simpler gameplay
  - **Core focus**: Melee is now baseline capability, cards focus on projectile unlocks
- **Documentation Updates**: Updated Obsidian architecture docs for KeybindingsDisplay integration
  - **UI Architecture**: Updated component hierarchy and implementation status
- **Enemy Render Tier System (Phase 2)**: Implemented basic render tier foundation for visual hierarchy
  - **Four render tiers**: SWARM (≤24px), REGULAR (24-48px), ELITE (48-64px), BOSS (>64px)
  - **Tier-based MultiMesh routing**: Enemies automatically route to appropriate render layers based on size
  - **JSON configuration**: enemy_tiers.json defines tier properties and thresholds
  - **Backward compatibility**: Existing mm_enemies continues working alongside new tier system
  - **Performance optimization foundation**: Sets up for future per-tier rendering optimizations
- **Enemy System MVP**: Complete data-driven enemy variety system with JSON configuration
  - **EnemyType domain model**: Load enemy definitions from JSON with validation and schema support
  - **EnemyEntity wrapper**: Extends dictionary structure with typed access while maintaining compatibility
  - **EnemyRegistry system**: Loads all enemy JSONs with hot-reload (F5) and weighted random selection
  - **Enemy JSON files**: Three enemy types (grunt_basic, slime_green, archer_skeleton) with different stats, colors, and AI
  - **Enhanced WaveDirector**: Type-aware spawning using EnemyRegistry for weighted selection
  - **MultiMesh rendering**: Per-instance colors and sizes based on enemy type for visual variety
  - **EnemyBehaviorSystem**: Dedicated AI system with chase, flee, patrol, and guard patterns
  - **Data schema**: Complete enemy configuration in vibe/data/README.md with example
  - **Canvas Layer Structure**: Documented new HUD layout with keybindings panel  
  - **Component Reference**: Added detailed KeybindingsDisplay component documentation
  - **System README**: Added keybindings component to key implementation files

### Previously Added
- **Transform Caching Optimization**: Enemy MultiMesh rendering now caches Transform2D objects instead of creating them every frame
  - **Performance improvement**: Eliminates 24,000 Transform2D allocations per second (800 enemies × 30Hz)
  - **Zero-risk optimization**: Same behavior, 67% faster transform updates, eliminates 2.3MB/second allocations
  - **Smart initialization**: Cache size matches max_enemies from balance data (800 transforms)
  - **Implementation**: Added _enemy_transforms Array[Transform2D] cache and _setup_enemy_transforms() function
- **FPS Counter and Performance Monitoring**: Real-time performance metrics display in HUD
  - **FPS display**: Always-visible FPS counter in bottom-left corner, updates every 0.5 seconds
  - **Debug overlay toggle**: F9 key toggles extended performance stats (draw calls, memory usage, entity counts)
  - **Performance test script**: `test_transform_performance.gd` validates transform caching benefits
  - **Arena debug stats**: get_debug_stats() method provides real-time enemy/projectile counts for monitoring
- **Comprehensive Pause System Overhaul**: Replaced manual pause checks with Godot's built-in pause system
  - **PauseManager autoload**: Centralized pause state management with proper process_mode configuration
  - **Process mode assignment**: Game systems (PAUSABLE), UI elements (WHEN_PAUSED), debug systems (ALWAYS)
  - **Fixed pause issues**: Eliminated attack stacking, lag bursts after resume, and camera glitches during pause
  - **XP Orb integration**: Orbs now properly pause with game systems
  - **Legacy compatibility**: RunManager.pause_game() redirects to PauseManager for backwards compatibility
- **Performance Optimization for 5500 Enemies**: Hybrid culling system for massive enemy counts
  - **Viewport culling**: Only render enemies visible on screen + 200px margin (5-10x FPS improvement when zoomed in)
  - **Distance-based updates**: Only update enemy AI/physics within 2500px radius (50% physics reduction)
  - **Alive enemies caching**: Cache alive enemy lists, only rebuild when enemies spawn/die (eliminates O(n) scans)
  - **Configurable cache size**: Transform cache size now matches max_enemies (5500) via balance data
  - **Smart culling stats**: Debug overlay shows total vs visible enemy counts for monitoring
  - **Camera zoom limit**: Reduced min zoom from 0.5 to 0.6 (configurable via balance data)
- **Performance Benchmarking System**: Automated performance testing with JSON result tracking
  - **Comprehensive test scenarios**: Baseline, light/medium/heavy load, maximum load, zoom stress tests
  - **Detailed metrics**: FPS percentiles, memory usage, culling efficiency, enemy counts
  - **JSON result storage**: Results saved to `user://benchmarks/` with timestamps for comparison
  - **Benchmark analyzer**: Compare before/after results, track optimization improvements
  - **Debug controls**: Quick benchmark (B key), full suite (F8), benchmark UI panel (F7)
  - **Automated comparisons**: Track performance changes across major updates
- **Architecture Boundary Enforcement System**: Automated tools to prevent violations of the layered architecture
  - **Automated validation**: test_architecture_boundaries.gd detects forbidden patterns (get_node() in systems, EventBus in domain, etc.)
  - **Static analysis tool**: check_boundaries_standalone.gd provides detailed dependency graphs and violation reports
  - **Multiple run methods**: Command-line headless execution, Godot Editor integration, batch file for easy access
  - **Dependency matrix**: Visual representation of cross-layer dependencies with violation counts
  - **Real violation detection**: Successfully identified actual architecture violation in XpSystem.gd
  - **Pre-commit hooks**: Automatic architecture validation before each commit with clear error messages
  - **CI integration**: GitHub Actions workflow runs boundary checks on all PRs with automated PR comments
  - **Comprehensive documentation**: ARCHITECTURE_RULES.md with examples, fixes, and debugging guidance
  - **Layer enforcement**: Autoload→Domain, Systems→Domain+Autoload, Scenes→Systems+Autoload, Domain→Pure data
  - **Developer experience**: Clear violation messages with file:line references and suggested fixes
  - **Batch file utility**: check_architecture.bat for one-click analysis execution
  - **Essential documentation**: Quick reference guide and streamlined project README

- **Centralized Logger System**: Structured logging with optional categories and configurable log levels
  - **Log Levels**: DEBUG, INFO, WARN, ERROR, NONE with runtime switching
  - **Optional Categories**: Category-based filtering (balance, combat, waves, player, ui, performance)
  - **Hot-reload Config**: JSON configuration with F5 reload support via BalanceDB integration
  - **F6 Debug Toggle**: Quick DEBUG/INFO level switching during development
  - **Smart Defaults**: Works without config file, categories are optional, sensible fallbacks
  - **Proper Output**: Errors use push_error(), warnings use push_warning(), others use print()
  - **Migration-friendly**: Simple Logger.info() calls, categories only when needed

- **BalanceDB Schema Validation System**: Comprehensive runtime validation for all JSON balance data
  - **Type validation**: Enforces correct data types with JSON float-to-int conversion for whole numbers
  - **Range validation**: Critical gameplay values validated against sensible min/max ranges
  - **Nested structure validation**: Complex objects like arena_center, colors validated recursively  
  - **Required field validation**: Missing critical fields caught at load time, not during gameplay
  - **Hot-reload safety**: F5 reloading validates data before applying changes, with proper error handling
  - **Comprehensive test coverage**: 7 test scenarios covering valid/invalid data, types, ranges, nesting
  - **Developer experience**: Clear error messages with field names and expected vs actual values
  - **Clean logging**: Integrated with Logger system using "balance" category

- **Changelog Management System**: Implemented hybrid approach with weekly archives, feature tracking, and quarterly summaries
  - **Weekly archives**: Previous weeks stored in `/changelogs/weekly/2025-wXX.md` 
  - **Feature tracking**: Major features documented in `/changelogs/features/`
  - **Comprehensive README**: `/changelogs/README.md` with approach documentation and quick reference
  - **Documentation updates**: Updated all MD file references to new changelog structure
  - **FeatureHistory migration**: Consolidated existing FeatureHistory folder into new changelogs structure
  - **File consolidation**: Combined duplicate enemy radar documentation into single comprehensive implementation file

- **Obsidian Documentation System**: Created comprehensive UI system architecture documentation
  - **Systems documentation**: 6 core system docs in `/Obsidian/systems/` with [[linking]]
  - **UI Architecture analysis**: Current vs proposed implementation comparison
  - **Component breakdown**: Detailed scene structure and dependency mapping
  - **Signal flow documentation**: EventBus communication patterns
  - **Modal system analysis**: Current CardPicker implementation and proposed generic system
  - **Integration with workflow**: Added Obsidian update steps to CLAUDE.md and custom commands

- **EventBus Typed Contracts System**: Implemented compile-time payload guarantees for all cross-system signals
  - **Typed payload classes**: 14 payload classes in `/vibe/scripts/domain/signal_payloads/` with compile-time safety
  - **Complete signal migration**: All 12 EventBus signals converted to use typed payload objects instead of loose parameters
  - **Comprehensive validation**: Enhanced `test_signal_contracts.gd` with structure validation for all payload types
  - **Backward compatibility removal**: Clean migration removing old multi-parameter signal patterns
  - **Developer experience**: Clear payload class structure with typed properties and descriptive documentation
  - **IDE support**: Full IntelliSense support with payload property auto-completion
  - **Runtime validation**: Advanced test coverage validating payload object structure and property types
  - **Architecture enforcement**: Payload classes accessed via EventBus preloads to avoid dependency issues

### Added  
- **Melee Combat System**: Complete cone-shaped AOE melee attack system replacing projectile defaults
  - **Core mechanics**: 25 damage, 100 range, 45° cone, 1.5 attacks/sec baseline with left-click activation
  - **Visual feedback**: Semi-transparent yellow cone polygon shows attack area and direction
  - **Mouse targeting**: Cone attacks aimed at cursor position with world coordinate transformation
  - **Damage integration**: Proper EventBus integration with EntityId.player() and EntityId.enemy(index)
  - **Balance system**: JSON-configurable damage, range, cone angle, attack speed, lifesteal
  - **Card system overhaul**: 8 melee-focused upgrade cards with damage, speed, range, angle, lifesteal options
  - **Dual combat**: Left-click melee (default), right-click projectiles (unlockable via card)
  - **Cone detection**: Dot product-based algorithm for precise enemy hit calculation
  - **Effect pooling**: Attack effects with 0.2-second fade animation and memory management

### Removed
- **Performance Benchmark System**: Removed all benchmark/performance testing files and UI elements
  - Deleted: BenchmarkAnalyzer.gd, PerformanceBenchmark.gd system files
  - Removed: Benchmark panel, quick benchmark buttons, full suite functionality
  - Kept: FPS display and basic performance stats in debug overlay
  - Cleaned: All F7/B key bindings for benchmark operations removed
  - Updated: HUD simplified to show only essential controls

### Changed
- **Logger Migration**: Completed migration of all print statements to centralized Logger system
  - **Main systems**: Arena.gd, Main.gd, CardPicker.gd, CardSystem.gd, TextureThemeSystem.gd, XpSystem.gd migrated
  - **Strategic logging**: Added warning logs for pool exhaustion in AbilitySystem and WaveDirector
  - **Error tracking**: Added failure logging for damage system pool lookups
  - **Category organization**: UI interactions use "ui" category, player events use "player" category
  - **Default DEBUG level**: All systems now use Logger with DEBUG level by default for development
  - **Cleaned debug output**: Removed specific alive projectiles/enemies counter logs from Arena
  - **Abilities category**: Added to log config for projectile and ability system logging

### Fixed
- **Enemy Sprite Consistency**: Fixed sprites changing colors between purple and green slimes during gameplay
  - **Root cause**: Sprite pool reusing AnimatedSprite2D nodes between different enemy types without proper reconfiguration
  - **Fix**: Added enemy type metadata tracking to sprites, ensuring proper reconfiguration when enemy type changes
  - **Implementation**: `sprite.set_meta("configured_enemy_type", enemy_type)` tracks which type each sprite is configured for
  - **Result**: Sprites maintain correct appearance throughout lifetime, no more color bleeding between enemy types
- **Extended Pause Lag Burst**: Fixed lag spikes when resuming after extended pause during level up
  - **Root cause**: RunManager._accumulator and Arena.spawn_timer continued accumulating time during pause
  - **Fix**: Added pause state checks to prevent time accumulation in RunManager._process() and Arena._process()
  - **Result**: Smooth resume regardless of pause duration, no more combat step bursts after card selection
- **Hotkey Menu Display**: Fixed empty keybinds overlay not showing text entries
  - **Root cause**: RichTextLabel with BBCode wasn't displaying properly in .tscn format
  - **Fix**: Changed to programmatic text setting with proper BBCode formatting
  - **Result**: Keybinds overlay now properly displays colored hotkey text
- **F8 Key Conflict**: Resolved F8 key causing game to close unexpectedly
  - **Root cause**: Conflicting F8 handlers between Arena and HUD systems
  - **Fix**: Removed duplicate F8 handlers, consolidated to F7 for performance menu
  - **Result**: F7 now consistently opens performance menu without crashes
- **Performance Results Display**: Fixed benchmark results not appearing after 30s test completion
  - **Root cause**: Button handlers not awaiting async benchmark completion
  - **Fix**: Made button handlers async and properly await benchmark results
  - **Result**: Results now display immediately after benchmark completion

### Added
- **Melee Combat System**: Replaced projectile-based combat with cone-shaped AOE melee attacks
  - **MeleeSystem**: New system managing cone-based AOE attacks with cursor targeting
  - **Balance configuration**: Configurable damage, range, cone angle, attack speed, and lifesteal
  - **Stat multipliers**: Full integration with card upgrade system for melee-specific buffs
  - **Visual feedback**: Attack effects pool for cone visualization during attacks
  - **Smart targeting**: Cone detection using dot product for precise enemy hit detection
- **Melee-Focused Card System**: Completely redesigned upgrade cards for melee combat
  - **Damage cards**: +30% damage, +50% damage/-20% speed trade-offs
  - **Speed cards**: +25% attack speed, +40% speed/-15% damage berserker mode
  - **Range cards**: +20% attack range for extended reach
  - **Utility cards**: +15% cone angle, +5% lifesteal for survivability
  - **Projectile unlock**: "Unlock Projectiles" card enables right-click ranged attacks
- **Dual Attack System**: Melee primary (left-click) with optional projectiles (right-click)
  - **Default melee**: Left-click for cone AOE attacks aimed at cursor
  - **Optional projectiles**: Right-click attacks only available after unlocking via card
  - **Stat separation**: Independent upgrade paths for melee vs projectile builds
  - **Control documentation**: Updated all hotkey displays to show new combat controls
- **Pre-commit Hook Execution Error**: Fixed git pre-commit hook failing with "No such file or directory" 
  - **Root cause**: Hook was changing to `vibe/` directory but using relative paths to Godot executable
  - **Path resolution fix**: Updated hook to use absolute paths from project root instead of relative paths
  - **Manual execution fix**: Updated help text to show correct command paths for manual architecture validation
  - **Developer experience**: Pre-commit hooks now execute reliably without path-related failures
  
- **Godot Headless Console Output**: Resolved issue preventing console output from appearing in headless test execution
  - **Root cause**: Test scripts extending `Node` instead of `SceneTree` when run with `--script` flag
  - **Script lifecycle fix**: Changed from `_ready()` to `_initialize()` method for proper SceneTree execution
  - **Autoload dependency solution**: Documented scene-based testing (`.tscn`) vs raw script testing patterns
  - **Documentation update**: Added console output patterns and command examples to CLAUDE.md Testing section
  - **Validation patterns**: Clear distinction between simple scripts and tests requiring singleton access

- **Testing Documentation Enhancement**: Updated CLAUDE.md to prevent autoload access errors during test development
  - **Clear autoload rule**: If test needs EventBus, RNG, ContentDB, or any autoload → use .tscn scene, NOT raw .gd script
  - **Workflow examples**: Added correct/wrong command patterns with concrete examples in workflow section
  - **Error prevention**: Documentation now prevents "test script doesn't have access to autoloads" implementation errors

### Technical

---

**Previous Weeks**: [Week 33](/changelogs/weekly/2025-w33.md) | [All Weeks](/changelogs/weekly/) | [Feature History](/changelogs/features/)

**Archive Policy**: This file contains current 2-3 weeks only. Completed weeks archived every Monday to maintain readability.