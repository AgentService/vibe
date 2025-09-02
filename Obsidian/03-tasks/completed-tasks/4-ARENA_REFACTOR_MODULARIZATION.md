# 4-ARENA_REFACTOR_MODULARIZATION

## Problem
Arena.gd has grown to 1048 lines and handles too many responsibilities:
- MultiMesh rendering for projectiles and enemies (4 tiers)
- Animation management for all enemy tiers
- UI setup and management
- Debug controls and testing
- System dependency injection
- Player setup
- Input handling
- Performance monitoring

This violates the single responsibility principle and makes maintenance difficult.

## Goals
1. Primary: Reduce Arena.gd to under 300 lines
2. Maintain hot-reload capabilities
3. Preserve performance (30Hz combat, MultiMesh rendering)
4. Follow existing architecture patterns
5. Keep signal-based communication

## Guiding Principles
- Keep EventBus-based decoupling, Logger for all logs, and GameOrchestrator for system creation/injection.
- One script per scene; systems live under `scripts/systems/*` and are added as child nodes of Arena unless they are autoloads.
- Maintain typed GDScript and small functions (&lt;= 40 lines).
- Extract incrementally; after each step, run the game and a small test suite to catch regressions early.

## Pre-Checks (Step 0)
Before starting the extraction, verify the baseline works:
- Launch the game from the editor (F5) and confirm:
  - Enemies spawn and move
  - Animations play for all tiers
  - Projectiles render and move
  - Debug keys (B, C, F11, F12) operate as expected
  - Pause menu toggles with Escape
- Record baseline performance:
  - FPS stable near 60
  - F12 toggles stats; note counts and memory
- Run quick tests headless (optional):
  - Command: `godot --headless --path . -s tests/cli_test_runner.gd`
  - Expected: No new failures vs. baseline

## Refactoring Strategy (Phased)
- Phase 1: Extract Animation System
- Phase 2: Extract MultiMesh Renderer
- Phase 3: Extract Debug Controller
- Phase 4: Extract UI Manager
- Phase 5: System Injection Cleanup
- Phase 6: Performance Monitor extraction
- Phase 7: Final cleanup & optimization

---

## Step 1: Extract EnemyAnimationSystem (Lines ~824–1047, ~223 lines)

### Objective
Move all enemy animation loading and per-tier frame update logic from Arena into a dedicated system.

### New File
`scripts/systems/EnemyAnimationSystem.gd`
```gdscript
class_name EnemyAnimationSystem
extends Node

signal tier_texture_changed(tier: int, texture: ImageTexture)

# Optional: expose read-only state for tests
var swarm_frame_idx: int = 0
var regular_frame_idx: int = 0
var elite_frame_idx: int = 0
var boss_frame_idx: int = 0

# Internals: loaded AnimationConfig and generated textures per tier
var _swarm_textures: Array[ImageTexture] = []
var _regular_textures: Array[ImageTexture] = []
var _elite_textures: Array[ImageTexture] = []
var _boss_textures: Array[ImageTexture] = []

var _swarm_timer := 0.0
var _regular_timer := 0.0
var _elite_timer := 0.0
var _boss_timer := 0.0

var _swarm_frame_dur := 0.12
var _regular_frame_dur := 0.10
var _elite_frame_dur := 0.10
var _boss_frame_dur := 0.10

func setup() -> void:
	# Load .tres configs (reuse paths from Arena)
	# Build textures like Arena._create_*_textures()
	# Keep Logger usage and identical behavior
	# Emit tier_texture_changed on frame advance
	pass

func update_animations(delta: float) -> void:
	# Advance timers per tier and emit on change
	pass

# Optional utilities for tests
func get_tier_texture_count() -> Dictionary:
	return {
		"swarm": _swarm_textures.size(),
		"regular": _regular_textures.size(),
		"elite": _elite_textures.size(),
		"boss": _boss_textures.size(),
	}
```

### Arena changes (minimal)
- Instantiate and add as child: `enemy_animation_system = EnemyAnimationSystem.new(); add_child(enemy_animation_system); enemy_animation_system.setup()`
- Connect signal: `enemy_animation_system.tier_texture_changed.connect(_on_tier_texture_changed)`
- Replace `_animate_*_tier(delta)` calls with a single `enemy_animation_system.update_animations(delta)`
- Implement handler:
```gdscript
func _on_tier_texture_changed(tier: int, texture: ImageTexture) -> void:
	match tier:
		EnemyRenderTier_Type.Tier.SWARM: if mm_enemies_swarm.multimesh.instance_count > 0: mm_enemies_swarm.texture = texture
		EnemyRenderTier_Type.Tier.REGULAR: if mm_enemies_regular.multimesh.instance_count > 0: mm_enemies_regular.texture = texture
		EnemyRenderTier_Type.Tier.ELITE: if mm_enemies_elite.multimesh.instance_count > 0: mm_enemies_elite.texture = texture
		EnemyRenderTier_Type.Tier.BOSS: if mm_enemies_boss.multimesh.instance_count > 0: mm_en_boss.texture = texture
```

### Tests (run after implementing Step 1)
- Launch game (F5). Observe:
  - Animations still run for all tiers (watch enemy textures cycling).
  - No new errors in Output. Logger shows animation load logs.
- Force spawn a boss (B key) and verify boss textures animate.
-less quick check:
  - `godot --headless --path . -s tests/cli_test_runner.gd`
- Hot-reload check:
  - Modify a frame duration in a `.tres` and re-save; confirm in-game cadence changes without restart.

### Rollback
- Keep original animation methods in Arena commented until Step 1 confirmed.
- If failure, disconnect the new system and re-enable Arena methods.

---

## Step 2: Extract MultiMeshRenderer (Lines ~151–247, ~527–573, ~143 lines)

### Objective
Centralize MultiMesh setup and per-tick instance updates for enemies (by tier) and projectiles.

### New File
`scripts/systems/MultiMeshRenderer.gd`
```gdscript
class_name MultiMeshRenderer
extends Node

# References injected from Arena (nodes & helpers)
var mm_projectiles: MultiMeshInstance2D
var mm_swarm: MultiMeshInstance2D
var mm_regular: MultiMeshInstance2D
var mm_elite: MultiMeshInstance2D
var mm_boss: MultiMeshInstance2D
var enemy_render_tier: EnemyRenderTier

func setup(projectiles: MultiMeshInstance2D, swarm: MultiMeshInstance2D, regular: MultiMeshInstance2D, elite: MultiMeshInstance2D, boss: MultiMeshInstance2D, tier_helper: EnemyRenderTier) -> void:
	mm_projectiles = projectiles
	mm_swarm = swarm
	mm_regular = regular
	mm_elite = elite
	mm_boss = boss
	enemy_render_tier = tier_helper
	# Move Arena._setup_projectile_multimesh() here
	# Move Arena._setup_tier_multimeshes() here

func update_projectiles(alive_projectiles: Array[Dictionary]) -> void:
	# Move Arena._update_projectile_multimesh() here
	pass

func update_enemies(alive_enemies: Array[EnemyEntity]) -> void:
	# Move Arena._update_enemy_multimesh() and _update_tier_multimesh() here
	pass
```

### Arena changes (minimal)
- Instantiate and add: `multimesh_renderer = MultiMeshRenderer.new(); add_child(multimesh_renderer)`
- Call setup with current nodes and `enemy_render_tier`
- Replace signals to point to renderer:
  - `ability_system.projectiles_updated.connect(multimesh_renderer.update_projectiles)`
  - `wave_director.enemies_updated.connect(multimesh_renderer.update_enemies)`
- Remove direct MultiMesh setup/update code from Arena after validation.

### Tests
- Launch (F5). Verify:
  - Projectiles still render; enemy groups still render by tier and color.
  - No warnings about null MultiMesh or tiers.
- Press F11 to stress test (if enabled) and confirm stable FPS and instance counts.

### Rollback
- Keep original Arena update methods commented until confirmed.

---

## Step 3: Extract DebugController (Lines ~621–811, ~190 lines)

### Objective
Move input-driven debug actions (B, C, F11, F12, T…) and test helpers into a system that can be disabled in production.

### New File
`scripts/systems/DebugController.gd`
```gdscript
class_name DebugController
extends Node

# References needed for actions
var wave_director: WaveDirector
var card_system: CardSystem
var melee_system: MeleeSystem
var ability_system: AbilitySystem
var arena_ref: Node  # To access HUD/pause, etc., or inject dedicated managers.

var enabled: bool = true

func setup(arena: Node, deps: Dictionary) -> void:
	arena_ref = arena
	wave_director = deps.get("WaveDirector")
	card_system = deps.get("CardSystem")
	melee_system = deps.get("MeleeSystem")
	ability_system = deps.get("AbilitySystem")

func _input(event: InputEvent) -> void:
	if not enabled or not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_F11:
			# Spawn many enemies / stress test (use modern systems)
			pass
		KEY_F12:
			# Toggle performance overlay or print stats
			pass
		KEY_C:
			# Manual card selection test
			pass
		KEY_B:
			# V2 boss spawn shortcut
			pass
		KEY_T:
			# Boss damage test
			pass
```

### Arena changes (minimal)
- Instantiate and add: `debug_controller = DebugController.new(); add_child(debug_controller)`
- Provide dependencies via dict in `setup()`, sourced from GameOrchestrator injections.
- Remove debug logic from Arena `_input` where applicable; keep Escape/pause in Arena.

### Tests
- Launch (F5) and press B/C/F11/F12/T:
  - Ensure same behavior as before (logs and effects).
  - Confirm no regressions in input handling (pause via Escape still works).
- Toggle `enabled` false and confirm no debug actions fire.

---

## Step 4: Extract ArenaUIManager (Lines ~324–365, ~406–435, ~71 lines)

### Objective
Own HUD, CardSelection, PauseMenu instantiation and UI-related signal wiring in a single manager.

### New File
`scripts/systems/ArenaUIManager.gd`
```gdscript
class_name ArenaUIManager
extends Node

const HUD_SCENE: PackedScene = preload("res://scenes/ui/HUD.tscn")
const CARD_SELECTION_SCENE: PackedScene = preload("res://scenes/ui/CardSelection.tscn")
const PAUSE_MENU_SCENE: PackedScene = preload("res://scenes/ui/PauseMenu.tscn")

var hud: HUD
var card_selection: CardSelection
var pause_menu: PauseMenu

signal card_selected(card: CardResource)

func setup() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.name = "UILayer"
	add_child(ui_layer)

	hud = HUD_SCENE.instantiate()
	ui_layer.add_child(hud)

	card_selection = CARD_SELECTION_SCENE.instantiate()
	ui_layer.add_child(card_selection)

	pause_menu = PAUSE_MENU_SCENE.instantiate()
	add_child(pause_menu)

	# Bubble selection through manager
	card_selection.card_selected.connect(func(card): card_selected.emit(card))

func toggle_pause() -> void:
	if pause_menu:
		pause_menu.toggle_pause()

func open_card_selection(cards: Array[CardResource]) -> void:
	card_selection.open_with_cards(cards)

func try_toggle_debug_overlay() -> void:
	if hud and hud.has_method("_toggle_debug_overlay"):
		hud._toggle_debug_overlay()
```

### Arena changes (minimal)
- Instantiate and add: `ui_manager = ArenaUIManager.new(); add_child(ui_manager); ui_manager.setup()`
- Connect: `ui_manager.card_selected.connect(_on_card_selected)`
- Replace UI wiring in Arena with calls to `ui_manager`:
  - `PauseManager.pause_game(true)`; `ui_manager.open_card_selection(cards)`
  - Escape handling: `ui_manager.toggle_pause()`
  - F12: `ui_manager.try_toggle_debug_overlay()` (or use DebugController to call this)

### Tests
- Launch (F5):
  - Level-up triggers card selection (manually via EventBus or gameplay).
  - Escape toggles pause.
  - HUD visible and responds to debug overlay toggle.

---

## Step 5: System Injection Cleanup (Refactor ~51 lines → ~10)

### Objective
Simplify Arena’s injection point while remaining compatible with GameOrchestrator’s current `set_*` calls.

### Approach
- Add a collector in Arena:
```gdscript
var _injected: Dictionary = {}

func inject_systems(systems: Dictionary) -> void:
	_injected = systems.duplicate()
	# Optional: connect signals here centrally
```
- Preserve existing `set_*` methods for backward compatibility (used by GameOrchestrator today).
- Optionally have each `set_*` populate `_injected`:
```gdscript
func set_card_system(s: CardSystem) -> void:
	_injected["CardSystem"] = s
	# existing logic…
```
- Later (post-confirmation), update `GameOrchestrator.inject_systems_to_arena(arena)` to pass a dictionary once and remove individual `set_*` plumbing.

### Tests
- Launch (F5) and confirm nothing changed functionally.
- Validate logs show all systems injected.

---

## Step 6: Extract Performance Monitor (~50 lines)

### Objective
Move performance stats and printing out of Arena into a system, callable by UI/Debug.

### New File
`scripts/systems/PerformanceMonitor.gd`
```gdscript
class_name PerformanceMonitor
extends Node

func get_debug_stats(arena_ref: Node, wave_director: WaveDirector, ability_system: AbilitySystem) -> Dictionary:
	var stats: Dictionary = {}
	if wave_director:
		var alive_enemies: Array[EnemyEntity] = wave_director.get_alive_enemies()
		stats["enemy_count"] = alive_enemies.size()
		# Optional: visible count via arena_ref helper/camera system if needed
	if ability_system:
		var alive_projectiles: Array[Dictionary] = ability_system._get_alive_projectiles()
		stats["projectile_count"] = alive_projectiles.size()
	stats["fps"] = Engine.get_frames_per_second()
	stats["memory_mb"] = int(OS.get_static_memory_usage() / (1024 * 1024))
	return stats

func print_stats(stats: Dictionary) -> void:
	Logger.info("=== Performance Stats ===", "performance")
	for k in stats.keys():
		Logger.info("%s: %s" % [k, str(stats[k])], "performance")
```

### Arena/UI/Debug changes
- Instantiate once and share via DebugController/UIManager as needed.
- Replace `_print_performance_stats()` and `get_debug_stats()` usage with PerformanceMonitor.

### Tests
- Launch (F5), press F12:
  - Same overlay/printout behavior.
  - No warnings about missing methods in Arena.

---

## Step 7: Final Cleanup & Optimization (Target: &lt; 300 lines)

### Objective
- Remove commented legacy code migrated in Steps 1–6.
- Re-check function sizes and cyclomatic complexity.
- Ensure process/input functions are gameplay-only.
- Keep only:
  - `_ready()` setup and connections
  - Core gameplay input (mouse/auto-attack, Escape pause)
  - Simple handlers that delegate to systems
  - Minimal helpers (e.g., visible rect if still needed here)

### Tests (Final)
- Full gameplay session for several minutes:
  - Spawning, combat, UI, debug, animations, rendering
- Headless tests:
  - `godot --headless --path . -s tests/cli_test_runner.gd`
- Performance:
  - Maintain 60 FPS with 1000 enemies (F11) if applicable
- Hot-reload sanity:
  - Change small values in `.tres` and re-save; confirm live updates

---

## Migration & Testing Strategy (Applied After Each Step)

1. Create new system files and wire them in Arena minimally.
2. Keep old Arena code commented until new system verified in-game.
3. Launch the game (F5) and verify:
   - Logs show expected setup messages (categories: "enemies", "cards", "ui", "debug", "performance", "orchestrator").
   - Interactions work (mouse attacks, auto-attack, pause, card selection).
4. Optional headless test run:
   - `godot --headless --path . -s tests/cli_test_runner.gd`
5. Profile before/after (FPS, memory, entity counts).
6. Only then remove legacy code from Arena.

---

## Unit Test Targets
- EnemyAnimationSystem: frame advance cadence; texture count by tier; signal emissions.
- MultiMeshRenderer: instance counts and transforms updated; per-tier color material set.
- DebugController: key handling dispatch; guarded by `enabled`.
- ArenaUIManager: state transitions; card selection bubble; pause toggle.
- PerformanceMonitor: dictionary content with plausible ranges.

## Integration Test Targets
- Enemy spawning + rendering (counts match).
- Animation sync under load.
- UI responsiveness during gameplay and pause.
- Debug commands end-to-end.

## Performance Tests
- Maintain 60 FPS with 1000 enemies (stress key).
- MultiMesh update efficiency (no per-frame allocations in inner loops).
- Memory usage comparable or improved.

## Risk Mitigation
- Keep legacy code commented until replaced system passes in-game checks.
- Profile at each step; revert if regression.
- Use EventBus and system signals to reduce coupling.
- Verify hot-reload after each system add.

## Success Metrics
- [ ] Arena.gd &lt; 300 lines
- [ ] All tests passing
- [ ] No performance regression
- [ ] Hot-reload working
- [ ] Code review approval

## Dependencies
- Existing systems remain unchanged
- GameOrchestrator injection pattern preserved initially; later simplified
- EventBus signal flow maintained

## Timeline (Estimate)
- Phase 1–2: Animation & Rendering (2 hours)
- Phase 3–4: Debug & UI (1 hour)
- Phase 5: Injection cleanup (30 min)
- Phase 6–7: Perf monitor + cleanup (30–60 min)
- Total: ~4 hours

## Quick Launch Checklist (Repeat After Each Step)
- Run game in editor (F5).
- Exercise:
  - Move player, auto-attack, manual attacks (L/R mouse)
  - Pause (Esc), level-up flow (trigger EventBus.level_up or play)
  - Debug keys: B/C/F11/F12/T
- Watch Output:
  - No new errors/warnings
  - Expected Logger categories appear
- Optional headless suite:
  - `godot --headless --path . -s tests/cli_test_runner.gd`
- Record FPS and memory; compare to baseline.
