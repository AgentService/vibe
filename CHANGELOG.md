# Changelog

## [Current Week - In Progress]

### Resource Folder Organization (2025-10-07)

**Organized `scripts/resources/` into logical subfolders for better maintainability:**

**Folder Structure:**
- ✅ Created `scripts/resources/abilities/` subfolder
  - Moved: BaseAbility.gd, DamageAbility.gd, ProjectileAbility.gd, BuffAbility.gd, UtilityAbility.gd
- ✅ Created `scripts/resources/tomes/` subfolder
  - Moved: BaseTome.gd
- ✅ Created `scripts/resources/cards/` subfolder
  - Moved: CardResource.gd, CardPoolResource.gd
- ✅ Created `scripts/resources/world/` subfolder
  - Moved: BiomeConfig.gd, MapConfig.gd, PathAwareBoundaryConfig.gd, ForestTileMapping.gd, GenerationParams.gd, DecorationThemeConfig.gd

**Path Updates:**
- ✅ Updated all .tres resource files to reference new script paths
  - Updated: 2 ability files, 3 tome files, 5 card files, 1 card pool file, 10+ biome/map files
- ✅ Class hierarchy uses `extends ClassName` (no path updates needed)
- ✅ No preload/load statements found that needed updating
- ✅ Fixed CardSystem loading error (melee_pool.tres path updated)

**Benefits:**
- Logical grouping matches `data/content/` structure (abilities/, tomes/, cards/, biomes/)
- Easier navigation with 34 resource scripts now organized into categories
- Scalable architecture for future ability types (MeleeAbility, AoEAbility, etc.)
- Clear separation between game systems

### Data-Driven Starting Abilities (2025-10-07)

**Implemented automatic ability equipping via player_type.tres configuration:**
- ✅ Added `starting_abilities: Array[String]` property to PlayerType
- ✅ Player auto-equips starting abilities in `_ready()` from `player_type.tres`
- ✅ Removed hardcoded `equip_ability()` logic from Arena.gd (cleaner architecture)
- ✅ Created `ranger_player.tres` with `starting_abilities = ["heartseeker"]`
- ✅ Updated PlayerRanger.tscn to use ranger_player.tres instead of default_player.tres
- ✅ **FIXED** `DamageAbility._base_projectile_count` initialization bug
  - **Root Cause:** `_init()` ran BEFORE `duplicate()` copied .tres properties → initialized from default value (1) instead of .tres value (3)
  - **Fix:** Removed initialization from `_init()`, only initialize in `_recalculate_final_stats()` (runs AFTER properties are copied)
  - Heartseeker now correctly fires 3 projectiles instead of 1

**Testing Tool UX Improvements:**
- ✅ Renamed abilities to be character-agnostic: "ranger_arrow" → "heartseeker", "ranger_volley" → "volley"
- ✅ Simplified dropdown display to show only `ability_id` (removed "Name - ability_id" format)
- ✅ Added prefill system: slot dropdowns show currently equipped abilities on tool open
- ✅ Removed redundant "Currently Equipped" section (slots now show equipped state directly)
- ✅ Made window more compact: 1100x700 → 900x600, columns 450px → 350px
- ✅ **Added Tome Equipment UI to AbilityTestingPopup**
  - Added 4 tome dropdowns populated from TomeManager
  - Added stack count labels (x0, x1, x2, etc.)
  - Added +1 Stack buttons for each tome slot
  - Added "Equip Tome" button to apply selected tome to player
  - Added "Clear Tomes" button to remove all equipped tomes
  - Replaced keyboard shortcuts (Alt+1,2,3) with visual UI controls
  - Stack labels update dynamically when tomes are equipped/stacked

**Ability Progression Fixes:**
- ✅ Fixed `DamageAbility.level_up()` to accept optional `levels: int = 1` parameter
  - Supports future upgrade options that give multiple levels at once

### Ability System Architecture Refactor (2025-10-06)

**Refactored ability class hierarchy for cleaner .tres files and better designer experience:**

**Class Hierarchy Changes:**
- ✅ Slimmed down `BaseAbility` from 50+ properties to 10 universal properties
  - Kept only: ability_id, ability_name, description, icon, tags, ability_level, max_level, visual_scene, impact_effect
  - Removed: ALL damage, cooldown, projectile, buff, AOE, orbit properties
- ✅ Created `DamageAbility` (extends BaseAbility) with 10 damage-specific properties
  - Added: base_damage, damage_type, inherent_element, base_cooldown, projectile_count
  - Added: damage_scaling_per_level, cooldown_scaling_per_level, level_breakpoints, breakpoint_bonuses
  - Added: final_damage, final_cooldown (computed), _active_modifiers (runtime)
  - Includes: Modifier system (add_modifier, remove_modifier, _recalculate_final_stats)
  - Includes: Progression system (level_up with scaling and breakpoints)
- ✅ Updated `ProjectileAbility` to extend DamageAbility (was extending BaseAbility)
  - Kept 9 projectile-specific properties: fire_mode, is_homing, homing_strength, chains_to_enemies, chain_radius, pierce_count, knockback_distance, spread_angle, projectile_speed, projectile_lifetime
  - Now uses `super._init()` to initialize parent class tags and computed stats
- ✅ Created `UtilityAbility` stub (extends BaseAbility) for future non-damage abilities
  - Properties: duration, base_cooldown, final_cooldown
  - Stub for future ShieldAbility, MovementAbility, etc.
- ✅ Created `BuffAbility` stub (extends UtilityAbility) for future buff abilities
  - Properties: stat_target, stat_multiplier, flat_bonus, can_stack, max_stacks
  - Stub for future player stat buff system

**Duck Typing for Cross-Hierarchy Modifiers:**
- ✅ Updated `BaseTome.apply_to_ability()` with duck typing check
  - Added `has_method("add_modifier")` check to fail gracefully on non-damage abilities
  - TomeModifier descriptor holds ALL possible properties (damage, speed, pierce, etc.)
  - Each ability class checks `"property_name" in modifier` to apply relevant modifiers only
  - Tomes can modify any ability without tight coupling to class hierarchy
- ✅ `DamageAbility._recalculate_final_stats()` uses duck typing for modifier application
  - Checks for: damage_multiplier, cooldown_multiplier, projectile_count_bonus
  - Future ProjectileAbility can add checks for: pierce_bonus, chain_bonus, etc.

**Ability Testing Tool Updates:**
- ✅ Added property visibility system using duck typing
  - Added `_configure_visible_properties()` method using `"property_name" in ability` checks
  - Shows/hides UI fields based on ability type (ProjectileAbility shows 10 fields, DamageAbility shows 3)
  - Added label references for visibility control (damage_label, cooldown_label, etc.)
- ✅ Updated save/apply logic to use duck typing
  - Removed `if ability is ProjectileAbility` type checks
  - Uses `"property_name" in ability` for all property access
  - Only updates properties that exist on the ability (visible fields)
  - Future-proof: new ability types automatically work without code changes
- ✅ Added tags display below properties grid
  - Shows comma-separated list of ability tags
  - Helps designers understand ability categorization at a glance

**Content File Cleanup:**
- ✅ Cleaned `ranger_arrow.tres` - removed 8 obsolete properties
  - Removed: buff_duration, buff_stat_name, buff_multiplier, aoe_radius, aoe_duration, orbit_radius, orbit_rotation_speed, orbit_projectile_count
  - Added: spread_angle (was missing, now 40.0)
  - Reorganized properties in logical order: BaseAbility → DamageAbility → ProjectileAbility
  - Properties: 26 relevant properties (was 36 with obsolete)
- ✅ Cleaned `ranger_volley.tres` - same cleanup as ranger_arrow

**Designer Experience Improvements:**
- Opening `ranger_arrow.tres` in Godot Inspector now shows 26 relevant properties (was 50+ with many irrelevant)
- Clear property organization: Core Identity → Damage → Cooldown → Projectile Behavior
- No confusing buff_duration or orbit_radius on projectile abilities
- Ability Testing Tool only shows relevant fields (10 for ProjectileAbility, 3 for DamageAbility)
- Duck typing makes the system extensible: new ability types "just work"

**Files Created:**
- `scripts/resources/DamageAbility.gd` (332 lines) - Intermediate base class for damage abilities
- `scripts/resources/UtilityAbility.gd` (107 lines) - Stub for non-damage abilities
- `scripts/resources/BuffAbility.gd` (114 lines) - Stub for buff abilities

**Files Modified:**
- `scripts/resources/BaseAbility.gd` - Slimmed from ~590 lines to 173 lines
- `scripts/resources/ProjectileAbility.gd` - Updated to extend DamageAbility, added projectile_speed/projectile_lifetime
- `scripts/resources/BaseTome.gd` - Added duck typing check in apply_to_ability()
- `scenes/debug/AbilityTestingPopup.gd` - Added visibility system, updated save/apply logic
- `data/content/abilities/projectile/ranger_arrow.tres` - Cleaned obsolete properties
- `data/content/abilities/projectile/ranger_volley.tres` - Cleaned obsolete properties

**Migration Notes:**
- Existing .tres files are backward compatible (Godot ignores unknown properties)
- Obsolete properties were removed manually from ranger_arrow.tres and ranger_volley.tres
- Future .tres files created in Inspector will only show relevant properties

---

### Path-Aware Forest Arena Tuning (2025-10-06)

**Reduced default procedural generation parameters for smaller, tighter arenas:**
- ✅ Changed `connection_points` default: 3 → 2 (fewer connection points)
- ✅ Changed `chain_length` default: 6 → 4 (shorter path chains)
- ✅ Changed `min_point_distance` default: 120px → 80px (tighter layout)

**Impact:**
- Smaller overall arena footprint (less sprawling)
- Fewer path branches and endpoints
- More compact combat area for faster enemy engagement
- Values now adjustable in Godot Inspector via PathConfiguration resource

**Files Modified:**
- `scripts/resources/PathConfiguration.gd` - Updated default values in @export properties

### Ability Testing Tool - Full Editor Complete (2025-10-06)

**Upgraded ability testing popup to full editor with file saving and hot-reload:**
- ✅ Created `ranger_volley.tres` with cone spread (is_homing=false)
- ✅ Built two-column layout (editor left, equipment right)
- ✅ Implemented ability parameter editing (name, damage, cooldown, projectile count)
- ✅ Added "Save to File" button with ResourceSaver integration
- ✅ Added "Apply to Equipped" button for instant hot-reload without restart
- ✅ Added "Level Up All" and "Refresh from Files" buttons
- ✅ Auto-registration via AbilityManager directory scanner
- ✅ Fixed AbilityController access pattern (member variable, not child node)

**LEFT COLUMN: Ability Editor**
- Ability selection dropdown (all abilities from AbilityManager)
- Editable parameter fields:
  - Name (LineEdit)
  - Base Damage (SpinBox: 1-999, step 0.5)
  - Cooldown (SpinBox: 0.1-60s, step 0.1)
  - Projectile Count (SpinBox: 1-50, ProjectileAbility only)
- Tags display (read-only)
- "Save to File" button → writes changes to .tres via ResourceSaver
- "Apply to Equipped" button → hot-reloads equipped abilities instantly
- File info display (path, last saved timestamp)
- Recursive directory scanning to find ability .tres files

**RIGHT COLUMN: Slot Equipment**
- 4 slot dropdowns (auto-populated from AbilityManager)
- "+1 Lv" buttons per slot for testing level scaling
- "Equip Selected" applies to player's AbilityController
- "Clear All" removes equipped abilities
- "Level Up All" levels all equipped abilities by +1
- "Refresh from Files" hot-reloads AbilityManager registry
- Real-time display of equipped abilities (name + level)

**Ranger Volley (Cone Arrows):**
- Arrows fire straight in 40° cone pattern (no homing curve)
- Same stats as ranger_arrow (44 damage, 0.5s cooldown, 3 projectiles)
- Demonstrates config-driven ability creation (3 field changes)
- Uses existing cone spread system (_calculate_spread_direction)

**Designer Workflow (Edit → Save → Test):**
1. Open Ability Testing Tool via debug panel button
2. Select ability from editor dropdown (e.g., "Ranger Arrow")
3. Edit parameters (damage: 44 → 50, projectile_count: 3 → 5)
4. Click "Save to File" (writes to ranger_arrow.tres)
5. Click "Apply to Equipped" (hot-reloads if equipped)
6. Test in-game immediately (no restart, no F5)
7. Iteration time: ~5 seconds (edit → save → test)

**Architecture Benefits:**
- No hardcoded ability IDs in Player.gd test keybinds
- Direct AbilityController API integration via property access
- Hot-reload compatible (AbilityManager scanner)
- Declarative ability design (config files only)
- File persistence via ResourceSaver (.tres modification)
- Instant apply without restart (duplicate + replace pattern)

**Implementation Details:**
- Window size: 1000x700px (two-column layout)
- AbilityController is a member variable (`ability_controller = AbilityController.new(self)`)
- Access via `player.ability_controller`, NOT `player.get_node("AbilityController")`
- Recursive directory scan for .tres file paths
- Type-specific fields (projectile count shown only for ProjectileAbility)
- Player is in group "player" (singular), not "players"
- Added `clear_ability_slot()` method to AbilityController API

**Files Created:**
- `data/content/abilities/projectile/ranger_volley.tres`
- `scenes/debug/AbilityTestingPopup.tscn` (completely rewritten, two-column layout)
- `scenes/debug/AbilityTestingPopup.gd` (completely rewritten, 475 lines, full editor)

**Bug Fixes:**
- ✅ Fixed newline display in "Currently Equipped" RichTextLabel (`\\n` → `\n`)
- ✅ Fixed shared definition mutation (duplicate ability on load to editor)
- ✅ Fixed base_damage/base_cooldown not applying (added `_recalculate_final_stats()` call)
- ✅ Fixed projectile_count not applying (set `_base_projectile_count` instead of `projectile_count`)
  - Root cause: `_recalculate_final_stats()` resets `projectile_count = _base_projectile_count`
  - Solution: Set the baseline value that recalculation uses

**Files Modified:**
- `scenes/debug/DebugPanel.tscn` + `.gd` (button + popup management)
- `scripts/systems/AbilityController.gd` (added clear_ability_slot method)
- `scenes/debug/AbilityTestingPopup.gd` (4 bug fixes applied)

**Complete:** 100% of ability-debug-panel-design.md spec implemented

### Overkill Prevention - Working Solution Verified (2025-10-06)

**Implemented and verified projectile overkill prevention (Option B - Queue Bypass):**
- ✅ Added comprehensive header documentation listing 6 potential solutions (A-F)
- ✅ Implemented Option B (bypass damage queue) with `BYPASS_DAMAGE_QUEUE_FOR_TESTING` flag
- ✅ **VERIFIED WORKING:** Arrows 2-5 in volley correctly skip already-dead targets
- ✅ Cleaned up verbose debug logging after verification
- ✅ Kept old queued approach commented out for reference

**Problem Solved:**
- DamageService uses zero-allocation queue (`_queue_enabled=true`) by default
- Damage queued for 30Hz tick processing, not applied immediately
- When 5 arrows hit 900HP boss simultaneously, all saw `is_alive=true` (before fix)
- All 5 arrows applied damage and despawned, wasting 4 arrows (before fix)

**How It Works:**
- **Arrow 1:** `is_alive=true` → applies immediate damage → `is_alive_after=false` ✓
- **Arrow 2-5:** `is_alive=false` → **SKIPPED (target already dead)** ✓
- `_process_damage_immediate()` updates `_entity_alive[index] = 0` synchronously
- Godot processes collision callbacks sequentially, not simultaneously
- Each arrow sees updated alive state from previous arrow in same frame

**Solution Options Documented:**
- **Option A:** Disable queue globally (works but loses performance)
- **Option B:** Bypass queue for projectiles (✓ current working implementation)
- **Option C:** Stagger spawn timing (doesn't solve root issue)
- **Option D:** Smart target selection (complex algorithm, may still be useful)
- **Option E:** Check queue for pending damage (couples to internals)
- **Option F:** Accept overkill as intended (simple but feels bad)

**Files Modified:**
- `scripts/entities/AbilityProjectile.gd`:
  * Added 73-line header documentation analyzing problem + solutions
  * Added `BYPASS_DAMAGE_QUEUE_FOR_TESTING` const flag (line 144)
  * Modified `_on_enemy_collision()` with conditional damage logic
  * Removed verbose logging after verification
  * Updated header "Current Status" to reflect working solution

**Next:** Monitor performance, decide if permanent or evaluate Option C/D for better targeting

### Projectile Knockback Support (2025-10-06)

**Added knockback support to projectile abilities:**
- ✅ Added `knockback_distance` property to ProjectileAbility resource class
- ✅ Updated AbilityProjectile to use **current player position** for knockback direction
- ✅ Configured ranger_arrow.tres with 50px knockback distance
- ✅ Integrated with existing BossHitFeedback system (shader flash + velocity-based knockback)
- ✅ Fixed knockback direction: enemies always pushed **away from player** (not projectile)
- ✅ Added `PlayerState.get_position()` method for proper encapsulation
- ✅ Fixed rapid-fire knockback: **accumulates velocity** instead of replacing

**Architecture:**
- Knockback flows through: ProjectileAbility → projectile_data → AbilityProjectile → DamageService → DamageAppliedPayload → BossHitFeedback
- Uses boss velocity system with hit-stop (0.15s freeze) and organic decay (0.82 factor)
- Uses **PlayerState.get_position()** (30Hz cached position via combat_step)
- **Accumulative knockback:** Rapid hits add velocity together instead of canceling
- Hit-stop resets on each hit for impact feel, velocity accumulates for pushback
- Proper encapsulation: Systems should use get_position() not direct property access

**Files Modified:**
- `scripts/resources/ProjectileAbility.gd` - Added knockback_distance export and data payload
- `scripts/entities/AbilityProjectile.gd` - Use PlayerState.get_position() for knockback direction
- `scripts/systems/boss/BossHitFeedback.gd` - Accumulative knockback for rapid-fire abilities
- `autoload/PlayerState.gd` - Added get_position() encapsulation method
- `data/content/abilities/projectile/ranger_arrow.tres` - Set knockback_distance = 50.0

### Ability System - Phase 1.2 Complete (2025-10-06)

**Completed full ability system foundation with 30Hz deterministic updates:**
- ✅ Created AbilityController system class (component-based architecture)
- ✅ Refactored Player.gd to delegate all ability logic to AbilityController
- ✅ Integrated with EventBus.combat_step for fixed 30Hz updates (deterministic cooldowns)
- ✅ Added DebugAbilityDisplay UI component for real-time ability/tome visualization
- ✅ Connected to RunManager's existing fixed-step accumulator

**Architecture Benefits:**
- **Deterministic timing**: Abilities run at exact 30Hz regardless of framerate
- **Clean separation**: Player handles movement, AbilityController handles abilities
- **Future-proof**: Compatible with networked play and replay systems
- **Memory efficient**: Proper EventBus cleanup via _notification()

**Files Created:**
- `scripts/systems/AbilityController.gd` - Ability management component (275 lines)
- `scripts/ui/debug/DebugAbilityDisplay.gd` - Debug visualization component
- `autoload/AbilityManager.gd` - Ability registry autoload (from previous commit)
- `tests/ability_system/AbilityManager_test.tscn/gd` - Autoload validation tests

**Files Modified:**
- `scenes/arena/Player.gd` - Reduced from 1110 to ~930 lines (ability logic extracted)
- `scenes/arena/Player.tscn` - Added DebugAbilityDisplay label node
- `project.godot` - Registered AbilityManager autoload

**Branch:** `ability_system` (Phase 1.1-1.4 implementation)

**Next:** Phase 1.3 - First vertical slice (Ranger Arrow ability with projectile spawning)

### Visual Effects POC - Testing Playground Created (2025-10-06)

**Created interactive test harness for ability visual effects experimentation:**
- ✅ Created POC test scene: `tests/visual_effects/EffectsPOC.tscn`
- ✅ Implemented 3 visual methods: Sprite+Shader, GPUParticles2D, Line2D
- ✅ Added auto-fire system (1 second interval, toggleable)
- ✅ Added stress test (spawn 100 random effects)
- ✅ Live parameter control: scale (0.5-3.0x), AOE radius (50-500px), color
- ✅ Real-time debug display in window title (FPS, active effects count)

**Visual Effect Methods (Placeholder Implementations):**
- **Method A (Sprite+Shader)**: Projectile + AOE variants with tween fade
- **Method B (GPUParticles2D)**: Projectile + AOE variants with particle emission
- **Method C (Line2D)**: AOE circle with procedural generation

**Keyboard Controls:**
- `1-5`: Spawn different visual effect methods
- `A`: Toggle auto-fire for continuous effect spawning
- `+/-`: Adjust scale, `[/]`: Adjust AOE radius, `R`: Random color
- `SPACE`: Stress test (100 effects), `C`: Clear all effects

**Branch:** `visual-effects-poc` (POC development branch)

**Next Steps:**
1. Add textures to Sprite2D nodes (replace icon.svg)
2. Create glow shaders for Method A
3. Test performance with 100+ effects to measure FPS
4. Document findings and choose best method for Phase 6

**Files Created:**
- `tests/visual_effects/EffectsPOC.tscn` - Main test scene
- `tests/visual_effects/EffectsPOC.gd` - Test harness script
- `tests/visual_effects/README.md` - Testing documentation
- `tests/visual_effects/effects/` - Effect method implementations (6 files)

### Content - Added Tome Icons (2025-10-06)

**Added rune icon to tome items in unlock shop:**
- ✅ Updated damage_tome.tres with runeGrey_tileOutline_001.png icon
- ✅ Updated agility_tome.tres with runeGrey_tileOutline_001.png icon
- ✅ Icon: `res://assets/ui/runes/icons/runeGrey_tileOutline_001.png`

**Visual Improvement:**
- Tomes now display distinctive rune slab icon in UnlockShop grid
- Replaces empty icon_path with thematically appropriate rune imagery
- Consistent visual identity for knowledge/ability upgrade items

**Files Modified:**
- `data/content/tomes/damage_tome.tres` - Added rune icon path
- `data/content/tomes/agility_tome.tres` - Added rune icon path

### MapSelectButton - Removed Tier Display (2025-10-06)

**Removed tier from MapSelectButton component (tier selected via MapDetailsPanel instead):**
- ✅ Removed MapTier Label node from MapSelectButton.tscn (line 74-77)
- ✅ Removed `@export var map_tier` property from MapSelectButton.gd
- ✅ Removed `@onready var map_tier_label` reference from MapSelectButton.gd
- ✅ Removed `p_tier` parameter from `setup()` method signature
- ✅ Removed tier assignment in `_apply_properties()` method
- ✅ Updated usage documentation in docstring

**Architecture Rationale:**
- Maps don't have inherent tiers - players select difficulty tier separately
- Tier is a gameplay modifier selected in MapDetailsPanel difficulty grid
- Each map (Forest, Underworld) can be played at any tier (1-4)
- Displaying tier on map button implied incorrect map-tier binding

**Before:** `setup("forest_arena", "Forest", "Tier 1", "Description...", icon, false)`
**After:** `setup("forest_arena", "Forest", "Description...", icon, false)`

### UI Consistency - Standardized Back Buttons (2025-10-05)

**Created reusable BackButton component for all menu scenes:**
- ✅ Created BackButton.tscn component (extends MainButton)
- ✅ Standardized position: offset (50, 50), size 150x50
- ✅ Standardized text: "< Back" with arrow
- ✅ Updated UnlockShopScene to use BackButton component
- ✅ Updated MapSelect to use BackButton component
- ✅ Updated CharacterSelect to use BackButton component

**Technical Details:**
- Component inherits from MainButton for consistent styling
- Single source of truth for back button appearance
- Eliminates duplicate inline button definitions
- `button_text = "< Back"` property set in component

**Before:** Each scene had different back button styling (UnlockShop had "BACK" at (20,20) with 100x40 size)
**After:** All three scenes use identical BackButton component at (50,50) with 150x50 size

### Main Menu Background Blur (2025-10-05)

**Added subtle blur effect to main menu background:**
- ✅ Created custom shader with adjustable blur_amount uniform (default: 5.0)
- ✅ Applied ShaderMaterial to MenuBackground BackgroundImage
- ✅ 9-sample box blur for soft, diffused background effect
- ✅ Integrated darkening directly in shader (darken_color uniform)

**Technical Details:**
- Shader uses simple 3x3 box blur pattern (9 texture samples)
- `blur_amount` uniform allows runtime adjustment (0.0-5.0 range)
- `darken_color` uniform (default: vec4(0.2, 0.2, 0.2, 1.0)) for background dimming
- Final COLOR = blurred texture * darken_color for combined effect
- Offset calculation: `blur_amount / 1000.0` for subtle effect

### UI Consistency - MapSelect Scene Update (2025-10-05)

**Aligned MapSelect with Kenny UI styling pattern:**
- ✅ Replaced old raven_starter.png textures → Kenny UI panel-008.png
- ✅ Applied consistent dark teal NinePatchRect panels (Color 0.0392157, 0.231373, 0.270588, 1)
- ✅ Updated scene structure to match UnlockShop/CharacterSelect patterns
- ✅ Simplified layout: MapSelectionPanel (left, 700x600) + MapDetailsPanel (right, 500x600)
- ✅ Added MainMenu theme with 30px margins
- ✅ Connected map buttons to show details panel on selection
- ✅ Updated MapSelect.gd to reference new node paths with unique names
- ✅ Forest map fully functional, Underworld disabled (content pending)
- ✅ Removed orphaned WindowPositioner autoload from project.godot
- ✅ Added difficulty tier grid with checkboxes (Tier 1-4, stages, reward multipliers)
- ✅ Integrated LocalLeaderboard tracking for total runs and best stats
- ✅ Added placeholder methods to LocalLeaderboard: `get_total_runs_for_map()`, `get_best_run_for_map()`
- ✅ Created MapSelectButton component (reusable like CharacterSelectButton and ShopItemCard)
- ✅ Added disabled overlay state with "COMING SOON" label for locked maps
- ✅ Completed MapSelectButton integration: unified signal handler `_on_map_selected(map_id)`
- ✅ Removed old map-specific handlers (_on_forest_selected, _on_underworld_selected)
- ✅ Configured map_id properties: Forest ("forest_arena"), Underworld ("underworld_arena")
- ✅ Added hover/focus/pressed button styling to match CharacterSelectButton pattern
- ✅ Implemented visual selection state: Forest auto-selected on load with focus style
- ✅ Added `set_selected()` method to MapSelectButton for focus management

**Technical Details:**
- Map selection buttons trigger details panel visibility
- Difficulty tier grid: 3 columns (Tier, Stages, Reward) with 4 rows of data
- Total runs counter dynamically pulled from LocalLeaderboard
- Best depth and highscore displayed from player's best run
- Details panel automatically populates with Forest map data on scene load
- START RUN button transitions to arena with SessionState integration
- Clean two-panel layout with scrollable map list and fixed-size details panel
- Fixed "File not found" error for removed WindowPositioner.gd autoload

### Changelog Reorganization (2025-10-04)

**Simplified Structure:**
- ✅ Removed `/changelogs/` weekly folder structure
- ✅ Archived old CHANGELOG.md → `CHANGELOG_2025-10-04.md` (full history preserved)
- ✅ Created fresh CHANGELOG.md for current work only
- ✅ Moved 24 feature changelogs to `/Obsidian/03-tasks/completed-tasks/` organized by category:
  - **architecture/** (5 files) - Signals refactor, Arena architecture, MCP integration, Memory leak fixes
  - **combat/** (5 files) - Unified damage system, Melee combat, Enemy rendering, Hit feedback, Radar
  - **data/** (6 files) - Balance system, tres migration, ContentDB, JSON cleanup
  - **systems/** (3 files) - Hideout, Arena expansion, Logging
  - **ui/** (4 files) - Character system, Sprite improvements, Camera, Card system

**Rationale:** Single CHANGELOG.md easier to maintain, historical features archived by category for reference

### Ability System - Visual Effects POC Task (2025-10-04)

**Created Task 2e**: Visual Effects POC (3-4 hours)
- **Position**: Between Phase 4 (Tome Validation) and Phase 6 (Ability Library expansion)
- **Branch**: Separate `visual-effects-poc` for throwaway testing code
- **Purpose**: Test 3 visual effect methods before expanding ability library to determine best approach for scalable visual effects
- **Testing Focus:**
  - Method A: Sprite2D + Shader (glow effects with runtime customization)
  - Method B: GPUParticles2D (high-performance particle systems with emission shape scaling)
  - Method C: Line2D (procedural geometry for lightning/arcs)
- **Scope**: Projectiles and AOE/aura attacks (scalability requirement - no pre-rendered sprites)
- **Testing Strategy:**
  - Scalability test: 3 AOE sizes (150px, 300px, 500px) per method
  - Performance test: 100 simultaneous effects stress test
  - Color customization test
- **Architecture Foundation**: All methods support runtime AOE/size scaling via item modifiers (no sprite sheet dependencies)
- **Deliverable**: POC_FINDINGS.md documenting method selection for Phase 6 implementation
- **Cross-References:**
  - Updated parent task `2_ABILITIES_system_implementation.md` Phase 2e section
  - Updated migration guide `ability-system-melee-migration-guide.md` visual timeline
  - Task file: `Obsidian/03-tasks/2e_ABILITIES_visual_effects_poc.md` (6 subtasks)

---

## Archive

Previous changelog archived to `CHANGELOG_2025-10-04.md`
