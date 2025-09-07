# Week 34: Aug 18-24, 2025

**Current Sprint Changelog** - See `/changelogs/` for weekly archives and feature history

## [Current Week - In Progress]

### Added
- **PoE-Style Character System**: Implemented comprehensive per-character progression and persistence system
  - **CharacterProfile Resource**: Typed resource class for character data (id, name, class, level, exp, dates, progression)
  - **CharacterManager Autoload**: Full CRUD operations with character creation, loading, listing, deletion, and persistence
  - **Per-character saves**: Individual .tres files in user://profiles/ with unique ID generation and collision handling
  - **PlayerProgression integration**: Automatic synchronization of progression changes with debounced saves (1s timer)
  - **EventBus signals**: Added characters_list_changed, character_created, character_deleted, character_selected
  - **Updated CharacterSelect**: Enhanced with name input field and full character creation workflow
  - **Comprehensive testing**: CharacterManager_Isolated test validates all CRUD operations, persistence, and progression sync
  - **Knight/Ranger classes**: Initial class support with removal of Mage placeholder (per task specification)
  - **Save path management**: Automatic user://profiles/ directory creation and file path utilities
  - **Error handling**: Robust validation for corrupt saves, missing files, and edge cases
- **Player Progression System**: Implemented comprehensive, data-driven progression system with resource-based configuration
  - **PlayerProgression autoload**: Central progression manager handling level-ups, XP tracking, and unlock validation
  - **Typed progression resources**: PlayerXPCurve.gd and PlayerUnlocks.gd for editor-friendly curve configuration
  - **EventBus integration**: Added xp_gained, leveled_up, and progression_changed signals with typed parameters
  - **Debug tools**: F12 progression tools - Add XP (+100), Force Level Up, Reset Progression via DebugManager
  - **XpSystem migration**: Updated to delegate progression logic to PlayerProgression while preserving orb spawning
  - **Multi-level-up support**: Handles large XP gains with proper sequential level-ups and max level capping
  - **Save/Load seams**: export_state() and load_from_profile() methods ready for future SaveManager integration
  - **UI stubs**: CharacterScreen.gd and XPBarUI.gd subscriber stubs for future UI implementation
  - **Comprehensive testing**: PlayerProgression_Isolated test suite validates core progression, signals, and edge cases
  - **Data-driven curve**: 10-level progression curve (100/300/600/1000/1500/2100/2800/3600/4500/5500 XP thresholds)
- **Hideout Phase 0 Boot Switch**: Implemented typed, configurable boot flow with minimal-risk architectural improvements
  - **Typed EventBus signals**: Added enter_map_requested(StringName) and character_selected(StringName) for past-tense signal contracts
  - **DebugConfig Resource**: Updated to use StringName for character_id field (type consistency)
  - **Hideout.tscn structure**: Enhanced with YSort node and renamed spawn point to "spawn_hideout_main" per Phase 0 spec
  - **MapDevice as Area2D**: Converted from Node2D to Area2D with proper collision detection and typed signal emission
  - **PlayerSpawner API**: Added spawn_at(root, spawn_name) method with deferred spawn to avoid race conditions
  - **Boot mode selection**: Main.gd dynamic scene loading already supported hideout/arena toggle via config/debug.tres
  - **Test coverage**: Added test_debug_boot_modes.gd and Hideout_Isolated.tscn for automated boot mode validation
  - **Documentation**: Updated ARCHITECTURE_QUICK_REFERENCE.md with Phase 0 signal patterns and boot configuration
- **Hideout Enemy Leak Fix**: Resolved critical scene transition bug where enemies persisted after arena-to-hideout swap
  - **Scene ownership**: Added ArenaRoot node container for proper enemy parenting (no more leakage to autoloads)
  - **GameOrchestrator transition**: Implemented go_to_hideout/go_to_arena with proper teardown sequence
  - **Arena teardown contract**: Added on_teardown() method with comprehensive cleanup (systems, registries, signals)
  - **SceneTransitionManager integration**: Enhanced existing system to call on_teardown() during scene transitions
  - **WaveDirector cleanup**: Added stop() and reset() methods to halt spawning and clear enemy pools
  - **EntityTracker cleanup**: Added clear(type) and reset() methods for complete entity registry cleanup
  - **Global safety net**: EventBus.mode_changed signal triggers fail-safe purge of arena_owned/enemies groups
  - **Bidirectional flow preserved**: H key (arena → hideout) and E key (hideout → arena) both work seamlessly
  - **Diagnostic logging**: Enhanced teardown with detailed entity count reporting and leak detection
  - **Test coverage**: Added tests/test_scene_swap_teardown.gd for automated validation
- **Hideout System Phase 2**: Implemented scene transition system for seamless navigation between areas
  - **SceneTransitionManager**: Created runtime scene loading/unloading system with EventBus integration
  - **MapDevice interaction**: Interactive portals with Area2D proximity detection and UI prompts
  - **EventBus signals**: Added request_enter_map and request_return_hideout for scene transitions
  - **Coordinated transitions**: Main.gd integrates SceneTransitionManager for smooth scene changes
  - **Player state preservation**: Character data maintained across scene transitions
  - **Bidirectional flow**: Hideout ↔ Arena transitions working (E key to enter, H key to return)
- **Hideout System Phase 1**: Implemented unified player spawning system across all scenes
  - **PlayerSpawner system**: Created reusable scripts/systems/PlayerSpawner.gd for consistent player instantiation
  - **Resource-based config**: Converted debug.json to debug.tres using DebugConfig resource class
  - **Unified spawn points**: Added PlayerSpawnPoint markers to both Arena and Hideout scenes
  - **Scene-specific spawning**: Hideout.gd and refactored Arena.gd both use PlayerSpawner with fallback
  - **EventBus integration**: Player position changes emit events for other systems to consume
  - **Architecture compliant**: Maintains domain/systems/scenes separation, passes all validation checks
- **Hideout System Phase 0**: Implemented dynamic scene loading infrastructure for hub-based game flow
  - **Dynamic scene loading**: Main.gd now reads config/debug.tres and dynamically instantiates Arena or Hideout scenes
  - **Minimal hideout**: Created scenes/core/Hideout.tscn with PlayerSpawnPoint (Marker2D) and Camera2D
  - **Debug configuration**: Enhanced config with start_mode selection ("arena" | "hideout" | "map")
  - **Backwards compatibility**: Arena mode works exactly as before, no breaking changes
  - **Scene switching**: Can switch between modes via config without code changes
- **Entity Tracker Unified Clear-All**: Implemented comprehensive entity registration and damage-based clearing system
  - **Registration gaps fixed**: Added missing EntityTracker registration in WaveDirector._spawn_pooled_enemy and _spawn_special_boss
  - **Unified clear-all**: Updated WaveDirector.clear_all_enemies to route through DebugManager damage pipeline for consistency
  - **Boss clearing**: Replaced direct boss queue_free() with damage-based clearing via DebugManager.clear_all_entities()
  - **Debug validation**: Added temporary logging to track registration counts and clear-all effectiveness
  - **Test coverage**: Enhanced WaveDirector_Isolated test with registration validation and clear-all testing (T/C/D keys)
  - **Results**: 100% entity tracking for both goblins and bosses, unified clear-all via damage pipeline, no memory leaks
- **Arena Refactoring Phase 7 Complete**: EnemyAnimationSystem extraction successfully completed
  - **Animation fix**: Resolved issue where swarm enemies displayed full sprite sheet instead of individual animation frames
  - **Frame extraction**: Implemented proper frame-by-frame extraction from sprite sheets using animation configs
  - **System isolation**: Extracted 223 lines from Arena.gd into standalone EnemyAnimationSystem
  - **Progress**: Arena.gd reduced from 1048+ lines to 792 lines (24% reduction toward <300 line target)
  - **Future phases**: Created Phase 8+ plan to extract remaining ~492 lines via MultiMeshManager, BossSpawnManager, and other systems

### Changed
- **Project Structure Update**: Completed migration from vibe/ subdirectory to project root structure
  - **File paths updated**: All documentation, configuration, and test files updated to use new structure
  - **Core files**: .clinerules/, docs/, memory-bank/, tests/, scripts/, data/, scenes/, autoload/ now at project root
  - **CI/CD**: Updated GitHub workflows and pre-commit hooks for new structure
  - **Documentation**: Updated all .md files including ARCHITECTURE.md, CURSOR.md, LESSONS_LEARNED.md
  - **Tests**: Updated all test file imports and scene references
  - **Godot executable**: Updated references from "../Godot_v4.4.1-stable_win64_console.exe" to "./Godot_v4.4.1-stable_win64_console.exe"

### Removed
- **Legacy Enemy System Decommissioned**: Completed removal of dual-path enemy system in favor of V2-only approach
  - **Core changes**: Removed EnemyRegistry.gd, use_enemy_v2_system toggle, legacy spawn branch in WaveDirector
  - **Data cleanup**: Removed knight_*.tres legacy enemy resources (kept dragon_lord.tres for boss scenes)
  - **Architecture**: Simplified WaveDirector to use V2 system exclusively, updated EnemyRenderTier to work without EnemyRegistry
  - **Tests**: Removed test_hybrid_spawning.gd and legacy test dependencies
  - **Result**: Single enemy pipeline through V2 system, reduced maintenance burden, no feature regression

### Added
- **Unified Damage System V3 Cleanup**: Completed removal of all legacy damage system code paths and feature flags
  - **Removed**: unified_damage_v3 feature flag from CombatBalance schema and BalanceDB
  - **Simplified**: DamageRegistry now uses unified EventBus-based syncing exclusively
  - **Cleaned**: All V2/V3 version comments updated to reflect current standard architecture
  - **Legacy removal**: Eliminated fallback code paths, unused WaveDirector references in MeleeSystem
  - **Result**: Single clean damage pipeline using EntityTracker spatial queries, EventBus synchronization, and unified entity registration
- **Memory Bank Documentation System**: Established memory-bank/ as single source of truth for session resets and onboarding
  - Core files: projectbrief.md, productContext.md, systemPatterns.md, techContext.md, activeContext.md, progress.md
  - Sourced from: README.md, ARCHITECTURE.md, docs/ARCHITECTURE_QUICK_REFERENCE.md, docs/ARCHITECTURE_RULES.md, CLAUDE.md, LESSONS_LEARNED.md, changelogs, Obsidian systems docs
  - Workflow: Read all Memory Bank files at task start; update activeContext and progress after significant changes
- **Hybrid Enemy Spawning System**: Complete dual-mode enemy spawning supporting both pooled enemies and scene-based special bosses
  - **EnemyType.gd extensions**: Added boss_scene, is_special_boss, and boss_spawn_method properties for hybrid spawning
  - **WaveDirector hybrid routing**: _spawn_from_type() method routes enemies to pooled or scene spawning based on type properties
  - **Special boss scenes**: DragonLord boss example using editor-created CharacterBody2D scene with complex AI and died signal
  - **Public spawn API**: spawn_boss_by_id() and spawn_event_enemies() methods for future map event system integration
  - **EnemyRegistry filtering**: Special bosses (spawn_weight = 0.0) automatically excluded from random wave spawning
  - **Signal integration**: Scene bosses emit "died" signal properly integrated with EventBus for XP/loot rewards
  - **Test coverage**: Complete validation testing for both pooled (knight_regular) and scene-based (dragon_lord) spawning paths
  - **Content pipeline examples**: Updated .tres files showing pooled boss (knight_boss), regular enemies (knight_regular), and special scene boss (dragon_lord)
  - **Future-ready architecture**: Supports complex boss encounters, multi-phase bosses, and map-triggered events while preserving existing performance
- **Player Stats Migration to .tres**: Migrated hardcoded player stats to PlayerType.gd resource system
  - **PlayerType.gd resource**: New typed resource class for player statistics (move_speed, max_health, pickup_radius, roll_stats)
  - **default_player.tres**: Configuration resource with current player values (110 move_speed, 199 max_health, etc.)
  - **Validation system**: PlayerType.validate() method ensures stat integrity with error reporting
  - **Fallback handling**: Graceful degradation to hardcoded values if .tres loading fails
  - **Inspector editing**: Player stats now editable through Godot Inspector in default_player.tres
  - **Architecture consistency**: Follows established EnemyType.gd pattern for data-driven character stats
- **EnemyBehaviorSystem Removal**: Completely removed unused EnemyBehaviorSystem class and all references
  - **File Deleted**: Removed vibe/scripts/systems/EnemyBehaviorSystem.gd entirely
  - **Documentation Cleaned**: Removed all references from 6 Obsidian documentation files
  - **AI Logic**: All enemy AI is now handled directly by WaveDirector
  - **No Breaking Changes**: System was already unused - no functional impact
- **Architecture Boundary Check Enhancement**: Updated boundary validation to allow pure Resource config imports
- **Unified Damage System V2 COMPLETE**: Full implementation of unified damage pipeline with entity synchronization
  - **DamageRegistry.gd**: Dictionary-based entity storage system replacing dual damage paths
  - **DamageService autoload**: Single damage pipeline for all entity types (pooled enemies, scene bosses, player)
  - **Entity registration hooks**: Automatic registration in WaveDirector spawn methods and boss scene _ready()
  - **Critical entity synchronization**: DamageRegistry damage reflects back to actual game entities (HP updates, death triggers)
  - **Boss integration**: set_current_health() methods and proper _die() triggering for DragonLord/AncientLich
  - **Enemy integration**: Direct WaveDirector enemy.hp updates and alive state management
  - **Legacy system disabled**: All old damage code commented out and signal conflicts resolved
  - **Unified damage calculation**: Single crit system (10% base) and modifier pipeline
  - **Auto-registration**: Seamless entity registration on first damage attempt (no T key needed)
  - **Universal damage**: Both melee and projectile systems now work consistently across all entity types
  - **Debug tools**: debug_register_all_existing_entities() for runtime diagnostics (T key)
  - **Production ready**: Clean, polished system with minimal logging and automatic memory management
- **Limbo Console Integration**: Added in-game developer console for runtime debugging and balance tuning
  - **Plugin Installation**: Limbo Console v0.4.1 installed to vibe/addons/limbo_console/
  - **F1 Toggle Key**: Console accessible via F1 key (more intuitive than default backtick)
  - **Debug Controls**: Added F1 (Console) and C (Cards) to KeybindingsDisplay debug section  
  - **Runtime Commands**: Supports custom command registration for balance parameter adjustment
  - **Development Workflow**: Perfect for live-tuning balance values during playtesting
  - **MCP Integration**: Can be used with MCP tools for automated testing scenarios
- **Universal Hot-Reload System**: Complete automatic .tres resource hot-reload system without F5 dependency
  - **BalanceDB File Monitor**: Timer-based monitoring (0.5s interval) for all balance .tres files in BalanceDB autoload
  - **Scene @export Pattern**: Arena and Player use @export variables for automatic Inspector hot-reload
  - **Direct Resource Access**: Removed cached variables, use direct property access for real-time updates
  - **Cache Bypassing**: ResourceLoader.CACHE_MODE_IGNORE ensures fresh resource loading on every change
  - **Developer Documentation**: Clear instructions in data/README.md for adding new files to auto-reload system
  - **Best Practice Patterns**: @export for scene-based resources, ResourceLoader monitoring for autoload systems
  - **Zero Manual Input**: Changes to balance, arena, and player .tres files automatically affect running games
  - **Complete Coverage**: Player stats, arena config, all balance files support automatic hot-reload
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
  - **EnemyBehaviorSystem**: ~~Dedicated AI system with chase, flee, patrol, and guard patterns~~ REMOVED - AI moved to WaveDirector
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
  - **Main systems**: Arena.gd, Main.gd, CardPicker.gd, CardSystem.gd, XpSystem.gd migrated
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
