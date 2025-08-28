# Product Context

Why this project exists, who it serves, how it should work, and the experience goals that guide decisions.

## Why This Project Exists
- Create a mechanics-first, PoE-style buildcraft roguelike with deterministic, data-driven systems.
- Prove a scalable, testable Godot architecture (layers + signals) for rapid iteration and performance.
- Enable fast balance/content tuning via typed .tres resources and hot-reload.

## Problems It Solves
- Architectural decay: enforce clear scene/system/domain boundaries with automated checks.
- Coupling/fragility: replace direct references with EventBus + typed payloads.
- Iteration friction: eliminate hardcoded tunables; drive from .tres with live hot-reload.
- Performance ceilings: batch rendering (MultiMesh), pooling, and deterministic loops to scale enemy counts.
- Inconsistent damage paths: unify all entities through Damage v2 Service/Registry.

## How It Should Work (Core Loop)
1. RunManager emits a fixed 30 Hz combat step (deterministic).
2. Systems update on `combat_step(dt)` (abilities, damage, waves, XP).
3. Enemies spawn via WaveDirector:
   - Pooled enemies for bulk waves.
   - Scene-based bosses for complex encounters (hybrid spawning).
4. Player gains XP orbs, levels up, and picks cards (modal overlay pauses combat).
5. Damage pipeline: `damage_requested -> damage_applied -> damage_taken`, central registry updates entity state and emits `entity_killed`.
6. UI shows radar, keybindings, and HUD; F1 opens Limbo Console for dev commands.

## User Experience Goals
- Immediate, responsive feel with deterministic outcomes (no frame-rate drift).
- Clear visual hierarchy:
  - Enemy radar in top-right; always-visible keybindings panel.
  - Tiered enemy visuals (SWARM/REGULAR/ELITE/BOSS).
- Smooth difficulty: close spawns, melee-first, projectiles unlock via card.
- Fast iteration: tweak .tres values in-editor and see live updates.
- Minimal clutter: Arena gameplay focus, clean overlays, consistent logging.

## Player Flow
- Start → Main/Arena loads with default data-driven configs.
- Move (WASD), melee auto-attacks toward cursor; cards on level-up.
- Survive waves; hybrid bosses appear; death or victory ends run.

## Content & Balance Principles
- All tunables live in `data/*` as typed .tres (e.g., balance, XP curves, UI configs).
- Resources validated on load; safe fallbacks when missing/malformed.
- Enemy/content definitions are registry-driven; adding content requires no code changes.

## Non-Goals
- Networking and leagues in MVP.
- Heavy UI/scene complexity before core loop polish.

## Acceptance Criteria (Product)
- Deterministic combat with stable feel across machines.
- Clean architecture matrix (no forbidden edges) at all times.
- Damage V2 is the single source of truth for entity health/life cycle.
- Thousands of enemies render smoothly; bosses integrate seamlessly.
- Live-tunable game via .tres and console with minimal restart friction.
