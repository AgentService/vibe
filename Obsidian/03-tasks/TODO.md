## TODO — Architecture-First Roadmap (Obsidian)

    

#todo #architecture #vibe-coding #godot4

doublecheck changelogs\features\24_08_2025-DICTIONARY_TO_ENEMYENTITY_MIGRATION.md
escpecially dictionary for mesh and enemytypes for rest question?


Lock-free ring buffers ?? zero-allocation
  designs achieve million+ ops/sec throughput


combat log
dongerslider
brusthaarslider
gigachad
USE DASH AS A ABILITY to upgrade


Hotkey Setup
Escape Menu
Performance Testing to compare features
Card System enhancen
Menu from Godot or self?
soundeffect on xp gain, higher pitch closer to lvl up

<<<<<<< HEAD
review the abilty system\
  remove proectiles and its cards and all references.\
  review the melee attack.\
  make sure it matches  the curent enemy spawn behavior
  @changelogs\features\21_08_2025-ENEMY_RENDER_TIER_SYSTEM.md
  @changelogs\features\21_08_2025-MELEE_COMBAT_SYSTEM.md \
  \
  check if theses system work well togheter, i want to take 1 hit for small enemies, two for
  bigger and 3 for big etc.\
  \
  add more some more basic cards for melee only. base damage, attack speed, angle, range(how long      
  is cone)\
=======
each enemy needs its own (waves.json rules)


>>>>>>> fix-enemy-behavior
### Immediate — Architecture Assessment Priority Order

**Architecture State:** EventBus has comprehensive signals, RNG uses proper streams, BalanceDB has hot-reload + schema validation. Missing: enforcement layers for EventBus contracts and dependency boundaries. Core systems are now robust with validation bulletproofing in place.

- [x] **PRIORITY 1:** BalanceDB #schema-validation — foundational to all #data-driven systems, prevents runtime errors
  
  - Status: ✅ COMPLETED - Full schema validation with JSON type handling, range validation, nested structure validation
  - Files: autoload/BalanceDB.gd, data/balance/, data/ui/radar.json, tests/test_balance_validation.gd

- [x] **PRIORITY 2:** EventBus #typed-contracts — compile-time payload guarantees, enhance existing test
  
  - Status: Good signal coverage, test_signal_contracts.gd exists but needs enhancement
  - Files: autoload/EventBus.gd, tests/test_signal_contracts.gd

- [x] **PRIORITY 3:** #dependency-boundaries — automated enforcement to prevent #architecture violations
  
  - Status: No automated enforcement; critical for team/complexity scaling  
  - Files: DECISIONS.md

- [ ] **PRIORITY 4:** #determinism toolkit — record/replay for debugging non-deterministic issues
  
  - Status: RNG streams well-designed, needs debugging tools
  - Files: autoload/RNG.gd, tests/run_tests.gd, tests/balance_sims.gd

  

### Short-term

- [x] **MELEE AUTO-ATTACK:** Implement continuous melee attacking at cursor position without requiring clicks

  - Status: Melee system complete but requires manual clicking
  - Files: scripts/systems/MeleeSystem.gd, scenes/arena/Arena.gd
  - Implementation: Add timer-based auto-attack cycle following cursor position

- [x] **CONE SIZE SCALING:** Expand base cone size and ensure cone angle card scaling works properly 

  - Status: Cone angle multiplier exists but may need base size adjustment
  - Files: data/balance/melee.json, scripts/systems/MeleeSystem.gd, data/cards/card_pool.json
  - Implementation: Increase default cone_angle from 45° to 60°+, verify card scaling affects visual cone

- [ ] #enemy-behavior interface + baseline behaviors (#rusher, #shooter, #tank)

  - Files: scripts/systems/AbilitySystem.gd, scripts/systems/DamageSystem.gd

- [ ] #ability-system: Add #aoe, #beam-channel, #homing archetypes; introduce #damage-types/tags

  - Files: scripts/systems/AbilitySystem.gd, scripts/systems/DamageSystem.gd

- [ ] #wave-director: Move #scaling and compositions into data with #tiers/#mini-bosses

  - Files: scripts/systems/WaveDirector.gd, data/balance/waves.json

- [ ] #ci: Headless build + #tests + #balance snapshot checks (Windows + Linux)

  - Files: tests/run_tests.gd, run_tests.bat, tests/results/baseline.json

- [ ] #debug-overlay: frame budgets per system, #pool sizes, active counts, #rng stream names

  - Files: scenes/ui/HUD.gd, autoload/RunManager.gd

  

### Performance and Memory

- [ ] #pooling audit: enemies, projectiles, effects, UI (forbid per-frame allocs in #hot-paths)

  - Files: scenes/arena/Player.gd, scenes/arena/XPOrb.gd

- [ ] #rendering: Use #multimesh for crowds/decals, verify #culling and batched updates

  - Files: (systems removed - moving to TileMap approach)

- [ ] #scripting micro-opts: cache node refs, #typed-arrays, disable unused #process-callbacks

  - Files: scripts/systems/CameraSystem.gd, scripts/systems/ArenaSystem.gd

  

### UX/UI Enablement

- [ ] #radar polish and tuning from data (#animations, #lerp, #danger color-coding)

  - Files: scenes/ui/EnemyRadar.gd, data/ui/radar.json

- [ ] #card-picker: #rarity/#synergy/#mutual-exclusion support

  - Files: scenes/ui/CardPicker.gd, data/cards/card_pool.json, scripts/systems/CardSystem.gd

  

### Progression and Meta

- [ ] Expand #card-pool to 15–20 upgrades with clear tags (#offense/#defense/#utility/#economy)

  - Files: data/cards/card_pool.json, scripts/systems/CardSystem.gd

- [ ] #victory/#defeat: data-driven #wave targets, timers; add #win-lose screens

  - Files: scenes/arena/Arena.gd, scripts/systems/WaveDirector.gd, data/balance/waves.json

- [ ] #meta-progression (design doc first), then implement #unlocks/#achievements

  - Files: LESSONS_LEARNED.md, DECISIONS.md

  

### Acceptance Checklist (per PR)

- [ ] Compiles headless; unit + contract tests pass; balance sims within allowed drift

- [ ] No boundary violations (`autoload → systems → scenes/nodes`)

- [ ] No hot-path allocations; pools verified; frame-time budgets respected

- [ ] Data files validated; schema and version updated if needed

- [ ] Update DECISIONS/docs for #architectural changes; update CHANGELOG if user-facing

  

### Quick Links

- #radar data: data/ui/radar.json

- #combat tunables: data/balance/combat.json

- #waves: data/balance/waves.json

- Enemy radar feature log: changelogs/features/enemy-radar