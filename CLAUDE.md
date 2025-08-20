# CLAUDE.md
> Guidance for Claude Code when working in this repository. Keep it concise, practical, and mechanics-first.

**Quick Links:** [CURSOR.md](CURSOR.md) | [ARCHITECTURE.md](ARCHITECTURE.md)

## Project Overview
- **Engine:** Godot 4.2+ (2D top-down).
- **Focus:** PoE-style buildcraft (skills + supports, items/affixes, small skill tree), wave/survivor arena.
- **Philosophy:** Art-light, **data-driven**, deterministic, testable. Mechanics > visuals.

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
- **Gameplay content** (skills, supports, affixes, items, trees, waves) → **JSON** in `/godot/data/...`.
- **Engine config/inspector-friendly** data (theme, input maps, export presets) → **`.tres/.res`**.
- Document all schema changes in `/godot/data/README.md` and include one example file.

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
- **Console output patterns**:
  - Simple scripts: `extends SceneTree` + `_initialize()` + `quit()`
  - Tests with autoloads: Use `.tscn` scenes, not raw `.gd` scripts

## Workflow (for Claude)
1) **Update schemas** in `/godot/data/README.md`; add one example JSON.
   ```json
   // Example: /godot/data/abilities/fireball.json
   {"id": "fireball", "damage": 25, "cooldown": 1.5, "projectile_count": 1}
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
4) **Add/adjust headless sim**; verify DPS/TTK bands stay within ±10%.
   ```bash
   # For tests with autoloads (BalanceDB, EventBus, etc.)
   "../Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
   
   # For simple standalone scripts
   "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/simple_test.gd
   ```
5) **Wire minimal UI**; keep it lean; use CanvasLayer for overlays.
6) **Update Obsidian docs** if system architecture changed; note required updates in commit message.
7) **Commit** with conventional prefix (`feat:`, `balance:`) and short DPS impact rationale.

## ALWAYS END TASK WITH ##
- update CHANGELOG.md with quick summary of what you have done (current week only - see `/changelogs/README.md` for management approach)
- note any Obsidian documentation updates needed in `/Obsidian/systems/*` (if architecture/systems changed)