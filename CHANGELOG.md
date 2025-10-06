# Changelog

## [Current Week - In Progress]

### Task: Cone Arrow Ability (Ranger Volley) - Documentation (2025-10-06)

**Created task document for second projectile ability variant:**
- ✅ Documented how to create cone arrow ability (non-homing)
- ✅ Identified that cone spread system is already built-in
- ✅ Only 3 field changes needed: `is_homing=false`, `homing_strength=0.0`, unique ID/name
- ✅ Estimated implementation time: 15-20 minutes

**Key Insight:**
- Cone spread already implemented in `_calculate_spread_direction()`
- 40-degree total spread, evenly distributed projectiles
- Homing vs non-homing creates completely different gameplay feel
- Demonstrates declarative ability design (config-driven)

**Architecture Benefits:**
- Same arrow visual scene (Arrow.tscn)
- Same damage/pooling/tome systems
- Hot-reload via Godot resource system
- No code changes required

**Files Created:**
- `Obsidian/03-tasks/2d_ABILITIES_cone_arrow_ability.md` - Full task specification

**Next:** Implement ranger_volley.tres and test both ability variants

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
