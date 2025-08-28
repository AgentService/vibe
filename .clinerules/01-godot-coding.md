## Brief overview
- Coding standards for Godot/GDScript in this workspace.
- Emphasize clarity, static typing, and alignment with existing architecture.

## GDScript style
- Use static typing everywhere (vars, functions, signals); prefer typed arrays/dicts.
- Naming: Classes PascalCase; constants UPPER_SNAKE_CASE; functions/vars snake_case; signals past-tense snake_case.
- Use @onready for node refs with explicit types; prefer %NodeName for scene-owned nodes.
- Avoid magic numbers; promote to const or .tres data; document intent with short comments.

## Scene and script structure
- One script per scene; script/scene names match intent (e.g., EnemySpawner.gd/tscn).
- Keep node trees minimal; isolate responsibilities into components; avoid deep hierarchies.
- Connect signals via code in _ready() or via EventBus for cross-system decoupling; avoid tight coupling.
- Expose tunables via @export with types; avoid editor-only defaults going stale.

## Data and resources
- Store balance/data in .tres under data/*; do not hardcode in gameplay code.
- Load resources via typed properties or preload() for hot paths; ResourceLoader for dynamic.
- Keep reusable scripts in scripts/* with clear domain/resources/utils boundaries.

## Combat and damage conventions
- Route all damage via DamageService autoload (res://scripts/systems/damage_v2/DamageRegistry.gd); never call take_damage() directly.
- Use dictionary-based damage requests with keys {source, target, base_damage, tags}; apply crits/modifiers centrally in the service.
- Use string-based entity IDs ("enemy_15", "boss_ancient_lich", "player"); resolve via registry/services, not scene tree scans.
- Emit/handle EventBus signals: damage_requested, damage_applied, damage_taken; avoid cross-module method calls.
- Reconnect systems incrementally (Melee, Projectiles, Boss, Player) and test each independently.

## Logging and debugging
- Use Logger.gd autoload for info/warn/error; do not use print()/push_warning() directly in game code.
- Include concise context (system, entity id) in logs; guard debug logs behind flags when noisy.

## Performance basics
- Avoid per-frame allocations; reuse arrays/dicts; cache node refs.
- Disable _process/_physics_process when unused; prefer signals/timers for event-driven flow.
- Prefer Areas/Physics layers for filtering over manual checks; batch operations when feasible.
