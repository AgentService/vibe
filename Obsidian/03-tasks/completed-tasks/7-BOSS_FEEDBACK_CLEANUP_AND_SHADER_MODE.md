# Boss Feedback Cleanup & Shader Mode Integration (Post-Unified Hit Feedback)

Status: In Progress — core code migrated; pending file deletions, tests, and docs
Owner: Solo (Indie)
Priority: High
Dependencies: BaseBoss.gd (damage visual mode), UnifiedHitFeedback.gd, Damage v2 (DamageRegistry/Service), WaveDirector.gd, Arena.gd, shaders/boss_flash_material.tres
Risk: Medium (removes legacy systems; references across Arena/WaveDirector/tests)
Complexity: 5/10

---

## Verification Summary (2025-08-29)

- Verified BaseBoss.gd:
  - DamageVisualMode enum with ANIMATION/SHADER exists.
  - Exports: damage_visual_mode, flash_duration, flash_intensity.
  - Shader flow loads res://shaders/boss_flash_material.tres and tweens flash_modifier; animation fallback plays damage_taken if present.
- Verified Arena.gd:
  - No BossHitFeedback variables/exports/instantiation present.
  - UnifiedHitFeedback is created and injected with MultiMesh + WaveDirector/EnemyRenderTier.
- Verified WaveDirector.gd:
  - No BossHitFeedback property/registration; boss visuals handled by BaseBoss.
  - Boss spawning via EnemyTemplate.boss_scene_path in _spawn_boss_scene().
- Verified UnifiedHitFeedback.gd:
  - Handles MultiMesh flash for pooled enemies.
  - Applies knockback to scene-based bosses; visuals delegated to BaseBoss.
- Outstanding cleanup:
  - scripts/systems/BossHitFeedback.gd file still exists (needs deletion).
  - tests/tools/test_complete_hit_feedback.gd references BossHitFeedback (needs update/removal).
  - EnemyHitFeedback/Enhanced/MultiMeshHitFeedbackFix still present; decision required whether to fully decommission or merge under UnifiedHitFeedback.

## Context & Motivation

We consolidated visual hit feedback and boss logic:
- Boss feedback should in BaseBoss with a selectable visual mode:
  - ANIMATION → plays `damage_taken` animation if present
  - SHADER → uses white flash shader `shaders/boss_flash_material.tres`
- Regular enemies keep MultiMesh visual feedback via UnifiedHitFeedback.
- Knockback should be provided by a single unified feedback path (UnifiedHitFeedback), not boss-specific scripts.

This task cleans up legacy systems (BossHitFeedback and redundant enemy feedback variants), removes references in Arena/WaveDirector, and locks in the BaseBoss-configurable shader/animation selection.

---

## Current Repo State (scan summary)

Found active references and files:
- BossHitFeedback (remove):
  - scripts/systems/BossHitFeedback.gd
  - scenes/arena/Arena.gd → exports and setup for boss_hit_feedback
  - scripts/systems/WaveDirector.gd → var boss_hit_feedback, register_boss() usage
  - tests/tools/test_complete_hit_feedback.gd → loads BossHitFeedback
  - .godot cache/global_script_class_cache entries (auto-refreshed by editor)
- EnemyHitFeedback family (candidates to remove after unification, if replaced):
  - scripts/systems/EnemyHitFeedback.gd
  - scripts/systems/EnhancedEnemyHitFeedback.gd
  - scripts/systems/MultiMeshHitFeedbackFix.gd
  - tests/EnemyHitFeedback_Isolated.gd/.tscn
  - scripts/systems/EnemyMultiMeshHitFeedback.gd (likely keep for MultiMesh path; verify replaced by UnifiedHitFeedback)
- UnifiedHitFeedback present:
  - scripts/systems/UnifiedHitFeedback.gd (keep, augment for knockback if not already)
- Shader assets (keep):
  - shaders/boss_flash_material.tres
  - shaders/boss_flash.gdshader
- BaseBoss already has mode support:
  - scripts/systems/BaseBoss.gd → enum DamageVisualMode, exported flash_duration/flash_intensity, shader setup and play

Key reference hotspots to edit:
- scenes/arena/Arena.gd: 
  - var boss_hit_feedback: BossHitFeedback
  - export props for boss_knockback_force/duration/hit_stop/velocity_decay + boss_flash_duration/intensity feeding boss_hit_feedback
  - creation/injection of BossHitFeedback instance, and passing into GameOrchestrator.wave_director
- scripts/systems/WaveDirector.gd:
  - var boss_hit_feedback: BossHitFeedback
  - registration hook in _spawn_boss_scene()

Tests referencing legacy:
- tests/tools/test_complete_hit_feedback.gd (loads BossHitFeedback)
- tests/EnemyHitFeedback_Isolated.* (if EnemyHitFeedback is to be superseded)
- VisualFeedback_Debug.g/tools tests refer to flash_duration/flash_intensity fields in configs (keep; adjust expectations if needed)

---

## Goals & Acceptance Criteria

- Remove legacy boss-specific feedback:
  - [ ] Delete BossHitFeedback.gd and all references across code and tests
  - [x] Remove boss-specific export props in Arena that only fed BossHitFeedback
- Keep shader option for bosses:
  - [x] BaseBoss exposes `damage_visual_mode` (ANIMATION/SHADER) via inspector
  - [x] Shader flash uses `boss_flash_material.tres`; parameters controlled by BaseBoss exports
- Single hit feedback system:
  - [x] UnifiedHitFeedback remains the only external feedback system (MultiMesh path)
  - [x] Knockback is handled via UnifiedHitFeedback for enemies; bosses handle visuals internally (no BossHitFeedback)
- Arena/WaveDirector cleanup:
  - [x] Arena: remove BossHitFeedback creation/config/injection
  - [x] WaveDirector: remove BossHitFeedback property/registration; bosses need no registration
- Tests/docs:
  - [ ] Update/remove tests tied to BossHitFeedback; add a BaseBoss shader/animation mode test
  - [ ] Update CHANGELOG and docs with cleanup notes

---

## Implementation Plan

### Phase 1 — Keep Shader Option in BaseBoss (verify/)
- [x] Confirm BaseBoss provides:
  - enum DamageVisualMode { ANIMATION, SHADER }
  - @export var damage_visual_mode: DamageVisualMode = ANIMATION
  - @export_group for shader settings with `flash_duration` and `flash_intensity`
  - Shader setup calls `res://shaders/boss_flash_material.tres` and animates a `flash_modifier` param
- [x] Ensure mode selection triggers:
  - ANIMATION → `_play_animation_feedback()` for `damage_taken`
  - SHADER → `_play_shader_feedback()` tweening intensity then restoring material
- [ ] Document in BaseBoss script header for editor workflow.

Notes: scripts/systems/BaseBoss.gd already contains these; only adjust if names/parameters drift.

### Phase 2 — Decommission BossHitFeedback
- [ ] Delete file: `scripts/systems/BossHitFeedback.gd`
- [ ] Remove references:
  - scenes/arena/Arena.gd:
    - Delete `var boss_hit_feedback: BossHitFeedback`
    - Remove exports solely for BossHitFeedback:
      - boss_knockback_force, boss_knockback_duration, boss_hit_stop_duration,
        boss_velocity_decay, boss_flash_duration, boss_flash_intensity
    - Remove instantiation/config:
      - `boss_hit_feedback = BossHitFeedback.new()` and property assignments
      - `add_child(boss_hit)`
      - injection into GameOrchestrator.wave_director
  - scripts/systems/WaveDirector.gd:
    - Remove `var boss_hit_feedback: BossHitFeedback`
    - In `_spawn_boss_scene()`, delete boss_hit_feedback registration block
- [ ] Let Godot reindex `.godot` caches automatically on next editor open

### Phase 3 — Consolidate to UnifiedHitFeedback
- [x] Verify `scripts/systems/UnifiedHitFeedback.gd` handles:
  - MultiMesh enemies visual flash (keep)
  - Knockback application on enemies (add/confirm)
- [x] Ensure Arena uses only this hit feedback for pooled enemies:
  - `var enemy_hit_feedback` now points to UnifiedHitFeedback or EnemyMultiMeshHitFeedback if Unified already composes it
  - If `EnemyMultiMeshHitFeedback.gd` is fully replaced, remove legacy EnemyHitFeedback variants:
    - scripts/systems/EnemyHitFeedback.gd
    - scripts/systems/EnhancedEnemyHitFeedback.gd
    - scripts/systems/MultiMeshHitFeedbackFix.gd
    - Their isolated tests (or migrate to UnifiedHitFeedback tests)
- [ ] If keeping `EnemyMultiMeshHitFeedback.gd` for now, ensure UnifiedHitFeedback is the orchestrator and there’s no duplication.

Decision gate: If UnifiedHitFeedback supersedes EnemyHitFeedback family, proceed with removal; else, mark separate task to merge.

### Phase 4 — WaveDirector/Arena final pass
- [x] Arena.gd:
  - Use unified feedback setter(s) only for MultiMesh
  - Remove any residual boss feedback wiring
- [x] WaveDirector.gd:
  - Ensure boss visuals come solely from BaseBoss
  - No boss registration code for feedback systems

### Phase 5 — Tests and Validation
- [ ] Remove/replace tests referencing BossHitFeedback:
  - tests/tools/test_complete_hit_feedback.gd → drop BossHitFeedback path; add BaseBoss mode tests
- [ ] Add/Update:
  - tests/BossSystem_Isolated.tscnd:
    - Instantiate a BaseBoss scene
    - Set `damage_visual_mode = DamageVisualMode.ANIMATION`, trigger damage → assert animation played
    - Set `damage_visual_mode = DamageVisualMode.SHADER`, trigger damage → assert shader param tweens and resets
  - tests/WaveDirector_Isolated.gd:
    - Ensure boss spawn path works without BossHitFeedback registration
- [ ] Keep VisualFeedback_Debug.gd and config tests that assert `flash_duration` and `flash_intensity` (they now bind to BaseBoss for bosses, UnifiedHitFeedback for pooled)

### Phase 6 — Documentation & CHANGELOG
- [ ] CHANGELOG.md:
  - Add “Removed BossHitFeedback; BaseBoss now controls boss visual feedback via ANIMATION/SHADER mode; UnifiedHitFeedback handles pooled enemies”
- [ ] Add feature entry:
  - `changelogs/features/YYYY_MM_DD-boss-feedback-cleanup.md`
- [ ] Docs:
  - Update `docs/ARCHITECTURE_QUICK_REFERENCE.md` and `docs/ARCHITECTURES.md`:
    - Boss feedback selection via BaseBoss inspector
    - UnifiedHitFeedback as single external feedback component
    - No boss feedback registration in WaveDirector

---

## File Touch List

Remove:
- scripts/systems/BossHitFeedback.gd
- (If superseded) scripts/systems/EnemyHitFeedback.gd
- (If superseded) scripts/systems/EnhancedEnemyHitFeedback.gd
- (If superseded) scripts/systems/MultiMeshHitFeedbackFix.gd
- tests/tools/test_complete_hit_feedback.gd (BossHitFeedback part)

Keep:
- shaders/boss_flash_material.tres
- shaders/boss_flash.gdshader

Edit:
- scripts/systems/BaseBoss.gd (verify/align names comments)
- scenes/arena/Arena.gd (remove boss_hit_feedback, exports, wiring)
- scripts/systems/WaveDirector.gd (remove boss_hit_feedback property and registrations)
- scripts/s/UnifiedHitFeedback.gd (ensure knockback for enemies; no boss visuals)
- tests/BossSystem_Isolated.gd/.tscn (add BaseBoss shader/anim mode assertions)
- tests/WaveDirector_Isolated.gd/.tscn (ensure no boss feedback registration needed)
- CHANGELOG.md, docs/ARCHITECTURE_*.md, new feature entry

Godot cache files under .godot/ will update automatically after edits; do not hand-edit.

---

## Acceptance Criteria

- Boss scenes display damage feedback via BaseBoss with selectable mode in inspector
- No references to BossHitFeedback remain; project compiles and runs
- Arena/WaveDirector have no boss feedback wiring/exports
- Pooled enemies continue to flash via UnifiedHitFeedback; knockback handled in unified path
- Tests pass:
  - BossSystem_Isolated validates both visual modes
  - WaveDirector_Isolated spawns bosses without BossHitFeedback
- Docs and CHANGELOG reflect the new architecture

---

## Validation Steps

1) Compile and run tests:
   godot --headless --script res://tests/cli_test_runner.gd

2) Manual:
- Spawn a boss with ANIMATION mode and verify `damage_taken` plays
- Switch to SHADER mode and verify white flash tween and reset
- Attack pooled enemies and verify flash/knockback via UnifiedHitFeedback
- Ensure no logs warn about missing BossHitFeedback or registrations

---

## Rollback Plan

- If issues arise, restore BossHitFeedback references from VCS temporarily
- Keep shader flash in BaseBoss regardless; legacy system can be restored only if needed while issues are fixed
- Re-run isolated tests before reattempting cleanup

---

## Risks & Mitigations

- Risk: Knockback behavior regression
  - Mitigation: Add focused test asserting velocity/stop behavior after damage; implement in UnifiedHitFeedback
- Risk: Missing test coverage for SHADER mode
  - Mitigation: Add BaseBoss visual mode tests
- Risk: Arena editor export removals break inspector setups
  - Mitigation: Note in CHANGELOG; migrate settings into UnifiedHitFeedback or BaseBoss as needed

---

## Checklist

- [x] Verify BaseBoss shader/animation mode properties and methods
- [ ] Remove BossHitFeedback.gd and all references (Arena/WaveDirector/tests)
- [x] Consolidate to UnifiedHitFeedback; provide knockback there
- [x] Clean Arena and WaveDirector of boss feedback wiring
- [ ] Update tests (remove legacy; add BaseBoss mode tests)
- [ ] Update docs and CHANGELOG
- [ ] Validate via headless test runner and manual sanity checks
