# CLAUDE.md
> Guidance for Claude Code when working in this repository.

**Quick Links:** [CURSOR.md](CURSOR.md) | [ARCHITECTURE.md](ARCHITECTURE.md) | [Project State](Obsidian/current_state/2025-09-20_PROJECT_STATE_ASSESSMENT.md)

## Quick Reference Table

| Folder | Purpose | Key Entry Points | Documentation |
|--------|---------|-----------------|---------------|
| `autoload/` | Global singletons & coordination | EventBus.gd, RunManager.gd, RNG.gd | autoload/CLAUDE.md |
| `scripts/systems/` | Core game logic (30Hz combat) | Arena.gd, DamageSystem.gd, BossSpawnManager.gd | scripts/systems/CLAUDE.md |
| `scripts/domain/` | Pure data models & types | EnemyType.gd, signal_payloads/*.gd | scripts/domain/CLAUDE.md |
| `scenes/` | UI & visual components | main/Main.tscn, arena/Arena.tscn, ui/MainMenu.tscn | scenes/CLAUDE.md |
| `data/` | Game content & balance | content/*.tres, balance/*.tres | data/README.md |
| `tests/` | Monte-Carlo sims & validation | *.tscn (with autoloads), *.gd (standalone) | tests/CLAUDE.md |

## Project File Structure

```
vibe/                          ← Top-down wave survival roguelike (PoE-style)
├── autoload/                  ← Global singletons (EventBus, RNG, RunManager)
│   ├── EventBus.gd           ← Central event hub with typed payloads
│   ├── RunManager.gd         ← Game state coordination & seeding
│   ├── RNG.gd                ← Deterministic streams (crit|loot|waves)
│   ├── Logger.gd             ← Centralized logging with categories
│   └── StateManager.gd       ← Scene transitions (MENU→ARENA→RESULTS)
├── scripts/
│   ├── systems/              ← 30Hz combat logic & game rules
│   │   ├── Arena.gd          ← Main game coordinator
│   │   ├── DamageSystem.gd   ← Unified damage processing
│   │   ├── BossSpawnManager.gd ← Zone-based boss spawning
│   │   ├── events/           ← Breach event system (PoE Atlas-style)
│   │   └── multimesh-backup/ ← Performance optimization experiments
│   ├── domain/               ← Pure data types & models
│   │   ├── EnemyType.gd      ← Enemy definitions & stats
│   │   ├── signal_payloads/  ← Typed EventBus contracts (14+ classes)
│   │   └── *.gd              ← Balance configs, entity types
│   └── resources/            ← Godot resource definitions
├── scenes/                   ← UI & visual components
│   ├── main/Main.tscn        ← Entry point scene
│   ├── arena/Arena.tscn      ← Combat arena (UnderworldArena variant)
│   ├── ui/                   ← HUD components & modals
│   │   ├── MainMenu.tscn     ← State: MENU
│   │   ├── CharacterSelect.tscn ← Character creation
│   │   └── hud/components/   ← Modular HUD system (6+ components)
│   └── bosses/               ← Scene-based boss entities
├── data/                     ← Hot-reloadable game content
│   ├── content/              ← Gameplay definitions (.tres)
│   │   ├── abilities/        ← Ability data (foundation ready)
│   │   ├── enemy-templates/  ← Enemy configurations
│   │   └── cards-melee/      ← Card system data
│   ├── balance/              ← Tunable parameters (.tres)
│   └── debug/                ← Logger config, debug settings
├── tests/                    ← Headless testing & validation
│   ├── *.tscn                ← Tests requiring autoloads
│   ├── *.gd                  ← Standalone logic tests
│   └── run_tests.tscn        ← Main test runner
├── assets/                   ← Art, audio, fonts
└── Obsidian/                 ← Architecture docs & planning
    ├── current_state/        ← Project assessments
    └── systems/              ← Detailed system documentation
```

## AI Navigation Instructions

This repository uses **hierarchical documentation** to reduce search time and improve AI navigation:

- **Main CLAUDE.md (this file)**: Project-wide rules, architecture overview, workflow
- **Subfolder CLAUDE.md files**: Context-specific patterns, entry points, integration details
- **File structure above**: Primary navigation map for understanding responsibilities

When working in a specific area:
1. **Check subfolder CLAUDE.md first** for context-specific patterns and entry points
2. **Reference this file** for project-wide rules and architecture boundaries
3. **Use file structure** to understand which layer you're working in

The subfolder documentation will be automatically fetched when needed, providing focused context without overwhelming the main documentation.

## Project Overview
- **Engine:** Godot 4.2+ (2D top-down).
- **Focus:** PoE-style buildcraft (skills + supports, items/affixes, small skill tree), wave/survivor arena.
- **MCP Integration:** GDAI MCP Plugin v0.2.4 installed. Provides AI tools for scene creation, script editing, debugging, and visual feedback.


## IMPORTANT – Working Rules
- **YOU MUST** use **typed GDScript**; keep functions small (<40 lines); avoid God objects.
- **YOU MUST** keep tunables in **`/data/*`** (JSON) or engine config in `.tres` (see "Content formats").
- **YOU MUST** communicate across systems via **Signals**; use `EventBus` autoload for global events.
- **YOU MUST** use **Logger** for all output; never use `print()`, `push_error()`, or `push_warning()` directly.
- **YOU MUST** maintain **determinism**:
  - Combat runs on a **fixed step (30 Hz)** via accumulator; rendering stays frame-rate based.
  - RNG via a **singleton with named streams** (`RNG.stream("crit"|"loot"|"waves")`), seeded per run by `RunManager`.
- **YOU MUST** use **pools** for projectiles/enemies and **MultiMeshInstance2D** for high-count rendering variants.
- **YOU MUST NOT** add networking to the client MVP (server/leagues later).
- **YOU MUST** always use Context7 when I need code generation, setup or configuration steps, or library/API documentation. This means you should automatically use the Context7 MCP tools to resolve library id and get library docs without me having to explicitly ask.

## Content formats
- **Gameplay content** (enemies, abilities, items, heroes, maps) → **`.tres` resources** in `/data/content/*`.
- **Balance tunables** (damage, rates, spawn weights) → **`.tres` resources** in `/data/balance/`.
- **Engine config/inspector-friendly** data (theme, input maps, export presets) → **`.tres/.res`**.
- Document all schema changes in `/data/README.md` and include one example file.

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
- Headless **Monte-Carlo sims** in `/tests/` for DPS/TTK; seeds required. ([See ARCHITECTURE.md - Testing](ARCHITECTURE.md#testing-decision-7))
- Add a minimal sim when adding/altering combat-relevant mechanics.
- **Test script patterns**:
  - **Simple standalone tests**: `extends SceneTree` + `_initialize()` + `quit()` - for pure logic testing without autoloads
  - **Tests requiring autoloads**: Use `.tscn` scenes with script attached - ensures EventBus, RNG, RunManager are available
  - **Rule**: If your test needs EventBus, RNG, ContentDB, or any autoload → use `.tscn` scene, NOT raw `.gd` script
- **Test logging**: Use `print()` directly in tests for output - do NOT use Logger in test files

## Workflow (for Claude)
1) **Update schemas** in `/data/content/*/README.md`; add one example .tres.
   ```tres
   // Example: /data/content/abilities/fireball.tres
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
   "./.Godot_v4.4.1-stable_win64_console.exe" --headless tests/run_tests.tscn
   "../Godot_v4.4.1-stable_win64_console.exe" --headless tests/test_balance.tscn
   
   # For simple standalone scripts (no autoloads needed) - USE .gd
   "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/simple_math_test.gd
   
   # WRONG: Using --script with autoload dependencies will fail
   # "../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/test_with_eventbus.gd  # ❌ FAILS
   ```
4b) **Consider isolated system test** for new core systems; see `/Obsidian/systems/Isolated-Testing-System.md`.
   ```bash
   # Create SystemName_Isolated.tscn for visual system testing
   "./Godot_v4.4.1-stable_win64_console.exe" --headless tests/SystemName_Isolated.tscn --quit-after 5
   ```
5) **Wire minimal UI**; keep it lean; use CanvasLayer for overlays.
6) **Update Obsidian docs** if system architecture changed; note required updates in commit message.
7) **Commit** with conventional prefix (`feat:`, `balance:`) and short DPS impact rationale.

## Setup Tips for AI Tools

### For AI Code Assistants Working in This Repository

**📋 Add the Entire File Structure**
- Use the Project File Structure section above as your navigation map
- For each major folder, understand its purpose and key entry points
- This structure acts as a directory service - always check it first before deep searching

**📁 Create Subfolder CLAUDE.md Files**
- Each major subfolder should have its own CLAUDE.md with context-specific patterns
- Focus on: integration patterns, signal usage, common entry points, gotchas
- AI tools will automatically reference these when working in specific areas
- **Tip**: Add this suggestion to any new CLAUDE.md files you create

**🎯 Use File Structure for Quick Orientation**
- Before searching code: check which layer you're working in (autoload vs systems vs domain)
- Before adding features: understand the EventBus signal patterns for that area
- Before debugging: identify the system boundaries and communication patterns

**🔍 Navigation Efficiency Tips**
- **For autoload changes**: Check EventBus.gd for signal contracts, then system implementations
- **For game logic**: Start with Arena.gd coordination, then specific system files
- **For data structures**: Start with scripts/domain/, then check .tres resource usage
- **For UI work**: Check scenes/ui/ structure, then component patterns in hud/components/
- **For testing**: Use .tscn for autoload dependencies, .gd for pure logic

**📖 Reference Hierarchy**
1. **Project File Structure** (above) → Quick orientation
2. **Subfolder CLAUDE.md** → Context-specific patterns
3. **Main CLAUDE.md rules** → Project-wide constraints
4. **Obsidian docs** → Deep architectural understanding

This hierarchical approach reduces search time and provides focused context without information overload.

## ALWAYS END TASK WITH ##
- update CHANGELOG.md with quick summary of what you have done (current week only - see `/changelogs/README.md` for management approach)
- note any Obsidian documentation updates needed in `/Obsidian/systems/*` (if architecture/systems changed)
- **update relevant subfolder CLAUDE.md** if you worked in that area:
  - Modified autoloads? Update `autoload/CLAUDE.md` with new patterns/dependencies
  - Added/changed systems? Update `scripts/systems/CLAUDE.md` with integration patterns
  - Created domain models? Update `scripts/domain/CLAUDE.md` with relationships
  - Modified UI/scenes? Update `scenes/CLAUDE.md` with new patterns
  - Added tests? Update `tests/CLAUDE.md` with test patterns/execution methods