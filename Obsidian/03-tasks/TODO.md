## TODO — Architecture-First Roadmap (Obsidian)

    

#todo #architecture #vibe-coding #godot4


combat log
dongerslider
brusthaarslider
gigachad

Hotkey Setup
Escape Menu
Performance Testing to compare features
Card System enhancen
Menu from Godot or self?

each enemy needs its own (waves.json rules)


### Immediate — Architecture Assessment Priority Order

**Architecture State:** EventBus has comprehensive signals, RNG uses proper streams, BalanceDB has hot-reload + schema validation. Missing: enforcement layers for EventBus contracts and dependency boundaries. Core systems are now robust with validation bulletproofing in place.

- [x] **PRIORITY 1:** BalanceDB #schema-validation — foundational to all #data-driven systems, prevents runtime errors
  
  - Status: ✅ COMPLETED - Full schema validation with JSON type handling, range validation, nested structure validation
  - Files: vibe/autoload/BalanceDB.gd, vibe/data/balance/, vibe/data/ui/radar.json, vibe/tests/test_balance_validation.gd

- [x] **PRIORITY 2:** EventBus #typed-contracts — compile-time payload guarantees, enhance existing test
  
  - Status: Good signal coverage, test_signal_contracts.gd exists but needs enhancement
  - Files: vibe/autoload/EventBus.gd, vibe/tests/test_signal_contracts.gd

- [x] **PRIORITY 3:** #dependency-boundaries — automated enforcement to prevent #architecture violations
  
  - Status: No automated enforcement; critical for team/complexity scaling  
  - Files: DECISIONS.md

- [ ] **PRIORITY 4:** #determinism toolkit — record/replay for debugging non-deterministic issues
  
  - Status: RNG streams well-designed, needs debugging tools
  - Files: vibe/autoload/RNG.gd, vibe/tests/run_tests.gd, vibe/tests/balance_sims.gd

  

### Short-term

- [x] **MELEE AUTO-ATTACK:** Implement continuous melee attacking at cursor position without requiring clicks

  - Status: Melee system complete but requires manual clicking
  - Files: vibe/scripts/systems/MeleeSystem.gd, vibe/scenes/arena/Arena.gd
  - Implementation: Add timer-based auto-attack cycle following cursor position

- [x] **CONE SIZE SCALING:** Expand base cone size and ensure cone angle card scaling works properly 

  - Status: Cone angle multiplier exists but may need base size adjustment
  - Files: vibe/data/balance/melee.json, vibe/scripts/systems/MeleeSystem.gd, vibe/data/cards/card_pool.json
  - Implementation: Increase default cone_angle from 45° to 60°+, verify card scaling affects visual cone

- [ ] #enemy-behavior interface + baseline behaviors (#rusher, #shooter, #tank)

  - Files: vibe/scripts/systems/AbilitySystem.gd, vibe/scripts/systems/DamageSystem.gd

- [ ] #ability-system: Add #aoe, #beam-channel, #homing archetypes; introduce #damage-types/tags

  - Files: vibe/scripts/systems/AbilitySystem.gd, vibe/scripts/systems/DamageSystem.gd

- [ ] #wave-director: Move #scaling and compositions into data with #tiers/#mini-bosses

  - Files: vibe/scripts/systems/WaveDirector.gd, vibe/data/balance/waves.json

- [ ] #ci: Headless build + #tests + #balance snapshot checks (Windows + Linux)

  - Files: vibe/tests/run_tests.gd, vibe/run_tests.bat, vibe/tests/results/baseline.json

- [ ] #debug-overlay: frame budgets per system, #pool sizes, active counts, #rng stream names

  - Files: vibe/scenes/ui/HUD.gd, vibe/autoload/RunManager.gd

  

### Performance and Memory

- [ ] #pooling audit: enemies, projectiles, effects, UI (forbid per-frame allocs in #hot-paths)

  - Files: vibe/scenes/arena/Player.gd, vibe/scenes/arena/XPOrb.gd

- [ ] #rendering: Use #multimesh for crowds/decals, verify #culling and batched updates

  - Files: vibe/scripts/systems/WallSystem.gd, vibe/scripts/systems/TerrainSystem.gd

- [ ] #scripting micro-opts: cache node refs, #typed-arrays, disable unused #process-callbacks

  - Files: vibe/scripts/systems/CameraSystem.gd, vibe/scripts/systems/ArenaSystem.gd

  

### UX/UI Enablement

- [ ] #radar polish and tuning from data (#animations, #lerp, #danger color-coding)

  - Files: vibe/scenes/ui/EnemyRadar.gd, vibe/data/ui/radar.json

- [ ] #card-picker: #rarity/#synergy/#mutual-exclusion support

  - Files: vibe/scenes/ui/CardPicker.gd, vibe/data/cards/card_pool.json, vibe/scripts/systems/CardSystem.gd

  

### Progression and Meta

- [ ] Expand #card-pool to 15–20 upgrades with clear tags (#offense/#defense/#utility/#economy)

  - Files: vibe/data/cards/card_pool.json, vibe/scripts/systems/CardSystem.gd

- [ ] #victory/#defeat: data-driven #wave targets, timers; add #win-lose screens

  - Files: vibe/scenes/arena/Arena.gd, vibe/scripts/systems/WaveDirector.gd, vibe/data/balance/waves.json

- [ ] #meta-progression (design doc first), then implement #unlocks/#achievements

  - Files: LESSONS_LEARNED.md, DECISIONS.md

  

### Acceptance Checklist (per PR)

- [ ] Compiles headless; unit + contract tests pass; balance sims within allowed drift

- [ ] No boundary violations (`autoload → systems → scenes/nodes`)

- [ ] No hot-path allocations; pools verified; frame-time budgets respected

- [ ] Data files validated; schema and version updated if needed

- [ ] Update DECISIONS/docs for #architectural changes; update CHANGELOG if user-facing

  

### Quick Links

- #radar data: vibe/data/ui/radar.json

- #combat tunables: vibe/data/balance/combat.json

- #waves: vibe/data/balance/waves.json

- Enemy radar feature log: changelogs/features/enemy-radar