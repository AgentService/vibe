# ContentDB Architecture Enhancement

**Priority**: Medium  
**Type**: Architecture Improvement  
**Epic**: Data Systems Consolidation  

> **✅ DESIGN APPROVED - SIMPLIFIED APPROACH**
> 
> **Current Status**: Structure established, ready for phased implementation
> 
> **Key Decisions Made:**
> - Proceed with simplified ContentDB that builds on existing BalanceDB patterns
> - Set up intended directory structure now to clarify architectural intent
> - Implement incrementally starting with EnemyRegistry extraction
> - Defer complex features until proven necessary
> 
> **Implementation Strategy:**
> - **Phase 1**: Extract existing EnemyRegistry logic to ContentDB (low-risk migration)
> - **Phase 2**: Add new content types (abilities, items) as features are developed  
> - **Phase 3**: Advanced features (modding, networking) only when needed
> 
> **Content Structure Established:**
> ```
> /data/content/           # Things you add (ContentDB)
> ├── enemies/            # ✅ Moved from /data/enemies/
> ├── abilities/          # 📋 Ready for future implementation
> ├── items/             # 📋 Ready for future implementation  
> ├── heroes/            # 📋 Ready for future implementation
> └── maps/              # 📋 Ready for future implementation
> 
> /data/balance/          # Numbers you tweak (BalanceDB)
> ```
> 
> **Decision Rationale**: Clear architectural intent + incremental implementation = reduced risk with preserved flexibility

## 📋 Overview

Create a unified ContentDB system to manage all game content (enemies, abilities, items) with validation, hot-reload, and fallback support, separating it from BalanceDB which handles gameplay tunables.

## 🎯 Goals

### Primary Objectives
- **Unified Content Management** - Single system for all content definitions
- **Schema Validation** - Type safety and error prevention for all content JSON
- **Hot-Reload Support** - F5 key reloads content changes instantly
- **Clean Separation** - BalanceDB for tunables, ContentDB for content definitions

### Success Criteria
- All enemy JSONs validated on load with helpful error messages
- Hot-reload works for enemies, abilities, and future content types
- Clear mental model: BalanceDB = numbers you tweak, ContentDB = things you add
- Easy to add new content types without duplicating loading logic

## 🏗️ Technical Design

### ContentDB Autoload Structure
```gdscript
# ContentDB.gd - New autoload
extends Node

signal content_reloaded()

var enemies: Dictionary = {}     # EnemyType objects by ID
var abilities: Dictionary = {}   # Future: AbilityType objects
var items: Dictionary = {}       # Future: ItemType objects

func _ready():
    load_all_content()
    # F5 hot-reload support
    
func load_all_content():
    load_enemies()
    load_abilities()  # Future
    load_items()      # Future
    content_reloaded.emit()
```

### Schema Validation System
```gdscript
# Similar to BalanceDB validation but for content
var _content_schemas = {
    "enemy": {
        "required": {
            "id": TYPE_STRING,
            "health": TYPE_FLOAT,
            "speed": TYPE_FLOAT,
            "size": TYPE_DICTIONARY
        },
        "ranges": {
            "health": {"min": 0.1, "max": 10000.0}
        }
    }
}
```

### Migration Path
```
Phase 1: Create ContentDB with enemy support
├── Move EnemyRegistry logic to ContentDB
├── Add validation schemas for enemies
└── Implement hot-reload (F5)

Phase 2: Expand to other content types  
├── Add ability definitions support
├── Add item definitions support
└── Create unified content editor tools

Phase 3: Advanced features
├── Content versioning and migration
├── Modding support with override system
└── Network synchronization for multiplayer
```

## 🔧 Implementation Tasks

### Core Infrastructure
- [ ] Create `ContentDB.gd` autoload
- [ ] Implement JSON loading with validation
- [ ] Add F5 hot-reload support
- [ ] Create fallback system for broken content

### Enemy System Migration
- [ ] Move enemy loading from EnemyRegistry to ContentDB
- [ ] Add enemy schema validation
- [ ] Update WaveDirector to use ContentDB
- [ ] Remove duplicate loading logic

### Future Content Support
- [ ] Design ability definition schema
- [ ] Design item definition schema  
- [ ] Create content type registration system
- [ ] Add editor integration tools

## 📁 File Structure Changes

### Previous Structure
```
/data/
├── balance/          # BalanceDB - gameplay tunables
│   ├── combat.json   # Damage, rates, speeds
│   └── waves.json    # Spawn mechanics
└── enemies/          # Direct file loading (OLD)
    ├── config/
    └── knight_*.json
```

### Current Structure (✅ Implemented)
```
/data/
├── balance/          # BalanceDB - gameplay tunables
│   ├── combat.json   # Numbers you tweak for game feel
│   └── waves.json    # Spawn rates, arena mechanics
├── content/          # ContentDB - things you add
│   ├── README.md     # ContentDB documentation
│   ├── enemies/      # ✅ Enemy type definitions (moved)
│   │   ├── README.md # Enemy schema documentation
│   │   ├── config/   # Enemy configuration
│   │   └── knight_*.json
│   ├── abilities/    # 📋 Skill definitions (future)
│   │   ├── README.md # Ability schema documentation
│   │   └── .gitkeep
│   ├── items/        # 📋 Item definitions (future)
│   │   ├── README.md # Item schema documentation
│   │   └── .gitkeep
│   ├── heroes/       # 📋 Hero/class definitions (future)
│   │   ├── README.md # Hero schema documentation
│   │   └── .gitkeep
│   └── maps/         # 📋 Map definitions (future)
│       ├── README.md # Map schema documentation
│       └── .gitkeep
└── schemas/          # 📋 Validation schemas (future)
    └── README.md     # Schema documentation
```

## 💡 Benefits

### For Developers
- **Faster Iteration** - Hot-reload eliminates restart cycle
- **Error Prevention** - Schema validation catches typos immediately  
- **Consistent Patterns** - Same loading system for all content
- **Better Debugging** - Centralized logging and error handling

### For Content Creators
- **Immediate Feedback** - See changes instantly with F5
- **Clear Documentation** - Schema defines exactly what's valid
- **Safe Experimentation** - Fallback values prevent crashes
- **Unified Workflow** - Same process for enemies, abilities, items

### For Architecture
- **Single Responsibility** - Each system has clear purpose
- **Future-Proof** - Easy to add new content types
- **Modding Ready** - Foundation for external content support
- **Network Compatible** - Structured for multiplayer content sync

## ⚠️ Risks & Mitigations

### Technical Risks
- **Performance Impact** - Loading/validating many files
  - *Mitigation*: Lazy loading and caching strategies
- **Memory Usage** - All content loaded at startup  
  - *Mitigation*: Content streaming for large games
- **Complexity Growth** - Another system to maintain
  - *Mitigation*: Clean interfaces and good documentation

### Migration Risks  
- **Breaking Changes** - Existing systems depend on current structure
  - *Mitigation*: Gradual migration with backward compatibility
- **Data Loss** - File reorganization might lose content
  - *Mitigation*: Automated migration scripts and backups

## 🗓️ Timeline Estimate

**Phase 1 (Enemy Migration)**: ~1-2 weeks
- ContentDB creation and basic enemy support
- Schema validation implementation
- Hot-reload integration

**Phase 2 (Content Expansion)**: ~2-3 weeks  
- Ability and item definition support
- Advanced validation features
- Editor integration tools

**Phase 3 (Advanced Features)**: ~3-4 weeks
- Modding support framework
- Network synchronization
- Performance optimization

## 📊 Success Metrics

### Quantitative Metrics
- **Hot-reload time**: < 200ms for content changes
- **Validation coverage**: 100% of required fields checked
- **Error reduction**: 90% fewer JSON-related crashes
- **Development speed**: 50% faster content iteration

### Qualitative Metrics
- Developer satisfaction with content workflow
- Code maintainability and clarity
- System flexibility for future content types
- Ease of onboarding new content creators

---

**Next Actions:**
1. Review current EnemyRegistry implementation for extraction patterns
2. Design ContentDB interface contracts
3. Create proof-of-concept with single enemy type
4. Plan migration strategy for existing enemy JSON files

**Related Tasks:**
- [[BalanceDB-ContentDB-Separation]] - Define clear boundaries
- [[Content-Validation-Framework]] - Reusable validation system  
- [[Hot-Reload-Performance]] - Optimize reload performance
- [[Modding-Support-Foundation]] - External content loading