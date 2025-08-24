# CURSOR.md
**Purpose:** Guardrails for Cursor when editing this Godot 4 project.

## Golden Rules
- **Typed GDScript** everywhere; functions <40 lines.
- **Data-driven** gameplay: .tres resources in `/vibe/data`; type-safe configuration.
- Use **Signals** + `EventBus` for cross-system events; no `get_node("../../..")` spaghetti.
- **Determinism**:
  - Fixed-step **30 Hz** combat accumulator in `RunManager`.
  - Single RNG with **named streams**: `crit`, `loot`, `waves`, `ai`, `craft`.
- **Performance**: pools + MultiMeshInstance2D for high-count visuals.

## Boundaries
- **Scenes** = view layer; UI connections only; call systems, never domain directly.
- **Systems** = rules/logic; emit/consume EventBus signals; import domain + autoloads.
- **Domain** = pure data models; no scene refs, no signal wiring, typed classes only.
- **Autoloads** = global coordination; RunManager, EventBus, RNG, BalanceDB singletons.

```gdscript
# ✓ Scene → System → Domain
scene.call_system_method()
system.process_domain_model(model)

# ✗ Scene → Domain (skip system)
scene.directly_modify_domain_data()
```

## Checklists

### Feature PR Checklist
- [ ] **Resource class** created in `scripts/domain/` + .tres files created
- [ ] **System logic** in `scripts/systems/*`; signals wired via `EventBus`
- [ ] **Headless sim** added/updated; DPS/TTK deltas <±10% noted in commit
- [ ] **RNG compliance**: No `randi()`; uses `RNG.stream(name)`
- [ ] **Performance**: MultiMesh per visual variant, pools for logic
- [ ] **Typed GDScript**: Functions <40 lines, explicit types everywhere
- [ ] **Fixed-step**: Combat logic subscribes to `combat_step` signal

### Content Addition Checklist
- [ ] Add .tres resource under `/vibe/data/<category>/`
- [ ] Update `/vibe/data/README.md` with resource class documentation
- [ ] Test hot-reload with F5 key in-game
- [ ] Verify schema matches existing content structure
- [ ] Run headless test: `"../Godot_v4.4.1-stable_win64_console.exe" --headless --script tests/run_tests.gd`

### System Implementation Checklist
- [ ] Emit signals via `EventBus`, never direct node references
- [ ] Connect to `EventBus.combat_step` for deterministic timing
- [ ] Use `RNG.stream("system_name")` for all randomness
- [ ] Implement `_exit_tree()` for signal cleanup
- [ ] Keep functions under 40 lines with explicit return types
