# 💾 Conversation Summary — Context, Decisions, and Next Steps

**Status**: 📋 Planning Phase  
**Priority**: High  
**Created**: 2025-08-23  

## 1) Project Context & Vision

### Current Gameplay Core
- [x] Top-down "Survivors"-style prototype implemented
- [x] Player knight with cone melee attack
- [x] Enemy spawns including boss encounters
- [x] Simple HUD system
- [x] Base map structure
- [x] Multimesh rendering with animated frames

### Authoring Philosophy
- **Style**: "Vibe-coding" first approach
- **Goal**: Extensible, refactor-resistant architecture
- **Content Strategy**: Move toward ContentDB (JSON-based) + BalanceDB (tunables)

### Longer-term Aspirations
- [ ] PoE-inspired build depth (stats, more/mult modifiers, crafting systems)
- [ ] Optional PvP later (1v1 → possible 5v5) - only if architecture allows
- [ ] Campaign intro → Endgame/Endless mapping loop
- [ ] Class as start point → later Ascendancy-like specialization

## 2) Architecture Outcomes

### 2.1 ContentDB vs BalanceDB
- [ ] **ContentDB** (things you add): enemy/ability/item definitions, schemas, hot-reload (F5), fallback on invalid content
- [ ] **BalanceDB** (numbers you tweak): gameplay tunables (combat, waves, etc.)
- [ ] **Goal**: Clear mental model + shared loaders/validators for new content types

### 2.2 Event-Driven Gameplay Effects
- [ ] Use Event Bus/Signals as decoupling backbone
- [ ] Emit `OnHit(attacker, target, final_damage, tags, context)`
- [ ] Separate module subscriptions:
  - [ ] Floating damage text renderer
  - [ ] Hit-reaction/animation module (flash, shake, knockback)
- **Why**: FX systems stay independent of combat math → easy visual evolution

### 2.3 Damage & Stats Layering
- [ ] **Two-layer model**:
  - [ ] Computation pipeline (stats → modifiers → final number)
  - [ ] Presentation subscribers (numbers/FX/UI)
- [ ] **Near-term**: Add minimal "Stats/DamageService" stub (returns base damage)

### 2.4 Abilities & Heroes
- [ ] **Ability Library** (100+ skills possible) as content modules (JSON + script)
- [ ] **Hero as container** of ability references (IDs/names) + optional baselines
- [ ] **PoE-like option**: Global passive tree + class start node
- [ ] **Later**: Ascendancy unlock system
- [ ] **Run-upgrades**: Temporary vs **Passives**: Persistent

## 3) Progression & Game Flow

### Preferred Flow Structure
- [ ] Short intro campaign/tutorial (few zones/hubs, light quests)
- [ ] Unlock Endless/Endgame mode
- [ ] Retain SSF (Solo Self-Found) feel initially
- [ ] Later optional trading
- **Benefits**: Teach systems, give structure, then accelerate into core loop

## 4) Multiplayer & Trading

### Staged Implementation Plan
- [ ] **Phase A**: SSF only (no netcode)
- [ ] **Phase B**: Auction House (AH) backend (no co-play)
  - [ ] Central service + DB
  - [ ] Game acts as client
- [ ] **Phase C**: Social spaces/visits; co-op only if/when desired

**Implication**: No full MP design needed now. Prepare item/identity & search metadata for AH later.

## 5) Items & Auction House Readiness

### Item Model Essentials (Day One)
- [ ] `uid` (globally unique)
- [ ] `type`, `rarity`, `name_key`, `ilvl`
- [ ] `affixes[]` (each with id, tier, rolls)
- [ ] `sockets/links?`, `bound?`, `owner_id?`, `created_at`

### Searchable Facets for AH
- [ ] Item class, rarity
- [ ] Affix ids/tiers/values
- [ ] DPS/ehp aggregates
- [ ] Requirements, tags
- [ ] Deterministic serialization (JSON) + version field

### Local Collection/Filter UI (Now)
- [ ] Build same filters wanted online (type/rarity/affix ranges)
- [ ] Later point filters at AH results
- [ ] Reuse UI, swap data source

### Server Shape (Later)
- [ ] Small service (HTTP/WS) + DB (Postgres/SQLite initially)
- [ ] Endpoints: list/search, post, buy/cancel, price histories
- [ ] Integrity: signature or server-computed item hashes

## 6) Maps, World, and Tools

### Authoring Options
- [ ] **Tiled** for tile maps (import via JSON/TSX/TMX)
- [ ] **Separate Godot project** as Map Kit
- [ ] **Data-driven maps** (JSON descriptors) for runtime instantiation

### Integration Standards
- [ ] Standardize layer names:
  - [ ] `Collision`
  - [ ] `Spawns_Enemy`
  - [ ] `Spawns_Player`
  - [ ] `Navmesh/Navigation`
- [ ] Use object layers/tile custom properties for spawns, blockers, triggers, portals
- [ ] Decouple spawn system from map assets

## 7) Concrete To-Dos (Short, Actionable)

### 🎯 Immediate Implementation Tasks

#### Stats/DamageService (Stub)
- [ ] API shape: `compute_damage(context)`
- [ ] Return base damage for now
- [ ] Emit `OnDamageResolved` signal

#### Hit FX Modules
- [ ] `DamageNumbers.gd` subscriber
- [ ] `HitReaction.gd` subscriber (tint/knock, brief i-frames optional)

#### Ability Library Contract
- [ ] JSON schema definition
- [ ] Base script interface: `can_cast`, `on_cast`, `tick`, `spawn_vfx`, `tags`

#### Hero as Ability Container
- [ ] Hero JSON lists ability ids
- [ ] Content-driven assignment system

#### Item Schema v0 (AH-Ready)
- [ ] Include `uid`, `type`, `rarity`, `affixes[]`, `tags[]`, `ver`
- [ ] Implement local inventory filters mirroring AH filters

#### Map Pipeline Choice
- [ ] Pick Tiled implementation
- [ ] Define layer names & metadata
- [ ] Implement importer → spawner uses markers

#### Event-Bus Visual Review
- [ ] Sketch nodes/signals for Hit/Damage/Death/Drop/XP
- [ ] Design subscribers (FX/UI/logging)

#### ContentDB Hot-Reload
- [ ] F5: reload content
- [ ] Emit `content_reloaded` signal
- [ ] Listeners refresh caches safely

## 8) Risk Notes & Mitigations

### Identified Risks
- [ ] **Refactor risk from vibe-coding** → Mitigate with interfaces first (small stubs, clear signals)
- [ ] **Performance with many JSON files** → Cache parsed assets; lazy-load heavy content
- [ ] **Content breakage on hot-reload** → Schema validation + fallbacks; log diffs & errors clearly
- [ ] **Future MP creep** → Keep net-agnostic boundaries (services for items/combat)

## 9) Open Questions (For Later Decisions)

### Technical Decisions Pending
- [ ] **Ability runtime**: Purely data-driven vs hybrid (data + script behaviors)?
- [ ] **Exact stat taxonomy**: Base vs increased vs more; additive vs multiplicative order
- [ ] **Extent of crafting**: Affix pools, tiers, currency sinks
- [ ] **Ascendancy timing & scope**: Within campaign → endgame?
- [ ] **AH economics**: Soft currency only? Taxes? Listing fees? Bind rules?

## Next Actions

### Priority 1 (This Week)
- [ ] Implement Stats/DamageService stub
- [ ] Create Hit FX module structure
- [ ] Design Event-Bus visual architecture

### Priority 2 (Next Sprint)
- [ ] Ability library JSON schema
- [ ] Hero-ability container system
- [ ] Item schema v0 implementation

### Priority 3 (Future Sprints)
- [ ] Map pipeline selection and implementation
- [ ] ContentDB hot-reload system
- [ ] Local inventory filter UI

---

## Related Documents
- [[Data-Systems-Architecture]] - Current data system implementation
- [[EventBus-System]] - Signal architecture reference
- [[Enemy-System-Architecture]] - Current enemy system structure

## Notes
This summary captures the comprehensive architectural vision and immediate actionable steps from the conversation. Focus on Priority 1 items to establish the foundation for the more complex systems outlined in Priority 2 and 3.
