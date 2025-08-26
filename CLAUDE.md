# CLAUDE.md
> Guidance for Claude Code when working in this repository.

**Quick Links:** [CURSOR.md](CURSOR.md) | [ARCHITECTURE.md](ARCHITECTURE.md)

## Project Overview
- **Engine:** Godot 4.2+ (2D top-down).
- **Focus:** PoE-style buildcraft (skills + supports, items/affixes, small skill tree), wave/survivor arena.
- **MCP Integration:** GDAI MCP Plugin v0.2.4 installed. Provides AI tools for scene creation, script editing, debugging, and visual feedback.


## IMPORTANT – Working Rules
- **YOU MUST** use **typed GDScript**; keep functions small (<40 lines); avoid God objects.
- **YOU MUST** keep tunables in **`/godot/data/*`** (JSON) or engine config in `.tres` (see "Content formats").
- **YOU MUST** communicate across systems via **Signals**; use `EventBus` autoload for global events.
- **YOU MUST** use **Logger** for all output; never use `print()`, `push_error()`, or `push_warning()` directly.
- **YOU MUST** maintain **determinism**:
  - Combat runs on a **fixed step (30 Hz)** via accumulator; rendering stays frame-rate based.
  - RNG via a **singleton with named streams** (`RNG.stream("crit"|"loot"|"waves")`), seeded per run by `RunManager`.
- **YOU MUST** use **pools** for projectiles/enemies and **MultiMeshInstance2D** for high-count rendering variants.
- **YOU MUST NOT** add networking to the client MVP (server/leagues later).

## Content formats
- **Gameplay content** (enemies, abilities, items, heroes, maps) → **`.tres` resources** in `/vibe/data/content/*`.
- **Balance tunables** (damage, rates, spawn weights) → **`.tres` resources** in `/vibe/data/balance/`.
- **Engine config/inspector-friendly** data (theme, input maps, export presets) → **`.tres/.res`**.
- Document all schema changes in `/godot/data/README.md` and include one example file.

## Hot-Reload Patterns
- **Scene-based resources**: Use `@export var resource: ResourceType` for automatic Inspector hot-reload (Player, Arena configs)
- **System-based resources**: Use `ResourceLoader.load()` with file monitoring or F5 hot-reload for autoload systems (Balance data)  
- **Best practice**: Follow Godot patterns (@export for scenes, ResourceLoader for systems)
- **Performance**: Cache frequently accessed resources, use `CACHE_MODE_IGNORE` only for hot-reload scenarios

## Layers & Dependency Rules
- **`scenes/*` (UI/View)** → may call `scripts/systems/*`, never deep-link domain. Signal connections only.
- **`scripts/systems/*` (Rules)** → may import `scripts/domain/*`, `autoload/*`. Emit/consume via EventBus.
- **`scripts/domain/*` (Models)** → pure data; no scene/signal wiring. Typed classes with helpers only.
- **`autoload/*` (Glue)** → `RunManager`, `EventBus`, `RNG`, `ContentDB`, `Balance`. Global state coordination.

```gdscript
# ✓ Correct: System emits to EventBus
EventBus.enemy_killed.emit(pos, xp_value)

# ✗ Wrong: System directly references scenes
get_node("../../UI/HUD").update_health(hp)
```

## Performance
- **30 Hz** combat step; keep heavy math there. ([See ARCHITECTURE.md - Fixed-Step Combat](ARCHITECTURE.md#fixed-step-combat-loop-decision-5a))
- **MultiMeshInstance2D**: one per visual variant (e.g., `proj_firebolt_basic`, `enemy_grunt_default`). ([See ARCHITECTURE.md - Performance](ARCHITECTURE.md#performance-decision-10a))
- Keep object pools; MultiMesh is render-only; logic stays on pooled entities. ([See ARCHITECTURE.md - Performance](ARCHITECTURE.md#performance-decision-10a))
- Import settings: Filter Off, Mipmaps Off for pixel-clean UI/sprites.

## Logging
- **Usage**: `Logger.info("message")` or `Logger.debug("message", "category")` - never use `print()` directly.
- **Levels**: DEBUG (default), INFO, WARN, ERROR. Config: `/data/debug/log_config.json`.
- **Categories**: `balance`, `combat`, `waves`, `player`, `ui`, `abilities` (optional filtering).
- **Hot-reload**: F5 reloads config, F6 toggles DEBUG/INFO levels.

## Testing
- Headless **Monte-Carlo sims** in `/godot/tests/` for DPS/TTK; seeds required. ([See ARCHITECTURE.md - Testing](ARCHITECTURE.md#testing-decision-7))
- Add a minimal sim when adding/altering combat-relevant mechanics.
- **Test script patterns**:
  - **Simple standalone tests**: `extends SceneTree` + `_initialize()` + `quit()` - for pure logic testing without autoloads
  - **Tests requiring autoloads**: Use `.tscn` scenes with script attached - ensures EventBus, RNG, RunManager are available
  - **Rule**: If your test needs EventBus, RNG, ContentDB, or any autoload → use `.tscn` scene, NOT raw `.gd` script
- **Test logging**: Use `print()` directly in tests for output - do NOT use Logger in test files

## Workflow (for Claude)
1) **Update schemas** in `/vibe/data/content/*/README.md`; add one example .tres.
   ```tres
   // Example: /vibe/data/content/abilities/fireball.tres
   [gd_resource type="Resource" script_class="AbilityType"]
   [resource]
   id = "fireball"
   damage_base = 25.0
   cooldown = 1.5
   projectile_count = 1
   ```
2) **Implement systems** in `scripts/systems/*`; emit/consume signals.
   ```gdscript
   # AbilitySystem.gd
   EventBus.damage_requested.emit(source_id, target_id, damage, ["fire"])
   EventBus.combat_step.connect(_on_combat_step)
   Logger.info("AbilitySystem initialized", "abilities")
   ```
3) **Add strategic logging**; use `Logger.info()` for important events, `Logger.warn()` for issues.
   ```gdscript
   Logger.info("System initialized", "abilities")
   Logger.warn("Pool exhaustion detected", "performance")
   ```
4) **Add/adjust headless sim**; verify DPS/TTK bands stay within ±10%. **Use `print()` for all test output** - never Logger.
   ```bash
   # For tests with autoloads (EventBus, RNG, ContentDB, etc.) - USE .tscn
   "../Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
   "../Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_balance.tscn
   
   # For simple standalone scripts (no autoloads needed) - USE .gd
   "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/simple_math_test.gd
   
   # WRONG: Using --script with autoload dependencies will fail
   # "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_with_eventbus.gd  # ❌ FAILS
   ```
4b) **Consider isolated system test** for new core systems; see `/Obsidian/systems/Isolated-Testing-System.md`.
   ```bash
   # Create SystemName_Isolated.tscn for visual system testing
   "../Godot_v4.4.1-stable_win64_console.exe" --headless vibe/tests/SystemName_Isolated.tscn --quit-after 5
   ```
5) **Wire minimal UI**; keep it lean; use CanvasLayer for overlays.
6) **Update Obsidian docs** if system architecture changed; note required updates in commit message.
7) **Commit** with conventional prefix (`feat:`, `balance:`) and short DPS impact rationale.

## ALWAYS END TASK WITH ##
- update CHANGELOG.md with quick summary of what you have done (current week only - see `/changelogs/README.md` for management approach)
- note any Obsidian documentation updates needed in `/Obsidian/systems/*` (if architecture/systems changed)