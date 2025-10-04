# Changelog

## [Current Week - In Progress]

### Changelog Reorganization (2025-10-04)

**Simplified Structure:**
- ✅ Removed `/changelogs/` weekly folder structure
- ✅ Archived old CHANGELOG.md → `CHANGELOG_2025-10-04.md` (full history preserved)
- ✅ Created fresh CHANGELOG.md for current work only
- ✅ Moved 24 feature changelogs to `/Obsidian/03-tasks/completed-tasks/` organized by category:
  - **architecture/** (5 files) - Signals refactor, Arena architecture, MCP integration, Memory leak fixes
  - **combat/** (5 files) - Unified damage system, Melee combat, Enemy rendering, Hit feedback, Radar
  - **data/** (6 files) - Balance system, tres migration, ContentDB, JSON cleanup
  - **systems/** (3 files) - Hideout, Arena expansion, Logging
  - **ui/** (4 files) - Character system, Sprite improvements, Camera, Card system

**Rationale:** Single CHANGELOG.md easier to maintain, historical features archived by category for reference

### Ability System - Visual Effects POC Task (2025-10-04)

**Created Task 2e**: Visual Effects POC (3-4 hours)
- **Position**: Between Phase 4 (Tome Validation) and Phase 6 (Ability Library expansion)
- **Branch**: Separate `visual-effects-poc` for throwaway testing code
- **Purpose**: Test 3 visual effect methods before expanding ability library to determine best approach for scalable visual effects
- **Testing Focus:**
  - Method A: Sprite2D + Shader (glow effects with runtime customization)
  - Method B: GPUParticles2D (high-performance particle systems with emission shape scaling)
  - Method C: Line2D (procedural geometry for lightning/arcs)
- **Scope**: Projectiles and AOE/aura attacks (scalability requirement - no pre-rendered sprites)
- **Testing Strategy:**
  - Scalability test: 3 AOE sizes (150px, 300px, 500px) per method
  - Performance test: 100 simultaneous effects stress test
  - Color customization test
- **Architecture Foundation**: All methods support runtime AOE/size scaling via item modifiers (no sprite sheet dependencies)
- **Deliverable**: POC_FINDINGS.md documenting method selection for Phase 6 implementation
- **Cross-References:**
  - Updated parent task `2_ABILITIES_system_implementation.md` Phase 2e section
  - Updated migration guide `ability-system-melee-migration-guide.md` visual timeline
  - Task file: `Obsidian/03-tasks/2e_ABILITIES_visual_effects_poc.md` (6 subtasks)

---

## Archive

Previous changelog archived to `CHANGELOG_2025-10-04.md`
