# Systems Documentation

This folder contains comprehensive documentation of the game's UI and scene management architecture.

## Core UI Architecture Documents

### 📋 [[UI-Architecture-Overview]]
**Main reference document** - Current implementation status, strengths, and areas for improvement compared to the original plan.

### 🎬 [[Scene-Management-System]]  
Scene hierarchy, StateManager-based transitions, and current implementation status. Updated with new state management architecture.

### 🔄 [[Scene-Transition-System]]  
NEW: Comprehensive guide to StateManager and SessionManager. Covers typed state transitions, entity cleanup, and production scene management patterns.

### 🧹 [[Entity-Cleanup-System]]  
NEW: Deep dive into entity lifecycle management, cleanup strategies, and multi-phase reset sequences. Production-ready entity clearing patterns.

### 🖼️ [[Canvas-Layer-Structure]]
UI layering system, CanvasLayer setup, and the proposed multi-layer architecture for proper z-ordering.

### 🪟 [[Modal-Overlay-System]]
Modal dialogs like CardPicker, pause management, and the proposed generic modal system.

### 📡 [[EventBus-System]]
Signal-based communication patterns, UI updates via EventBus, and current signal architecture.

### 🧩 [[Component-Structure-Reference]]
Detailed breakdown of scene files, component dependencies, node structures, and lifecycle management.

### 📊 [[Data-Systems-Architecture]]
BalanceDB schema validation, RNG streams, hot-reload mechanisms, centralized Logger system, and data-driven configuration patterns.

### 🏰 [[Enemy-System-Architecture]]
Complete data-driven enemy system with JSON configuration, 4-tier visual classification, and MultiMesh batch rendering for thousands of enemies.

### 🎯 [[Enemy-Entity-Architecture]]
Typed EnemyEntity objects providing compile-time safety while maintaining Dictionary compatibility for performance-optimized rendering.

## Quick Navigation

### Current State Analysis (UPDATED)
- **Working Well**: [[EventBus-System]], [[Enemy-System-Architecture]] (typed objects), [[Data-Systems-Architecture]] (validation + hot-reload), [[Enemy-Entity-Architecture]] (type safety)
- **Recently Improved**: [[Component-Structure-Reference]] (typed enemy integration), [[Canvas-Layer-Structure]] (keybindings panel)
- **Needs Improvement**: [[Scene-Management-System]], [[Modal-Overlay-System]]
- **Major Refactor Needed**: Arena scene complexity (see [[Component-Structure-Reference]])

### Implementation Priorities
1. **Phase 1**: Extract UI from Arena → [[Canvas-Layer-Structure]] improvements
2. **Phase 2**: Create [[Scene-Management-System]] with GameManager  
3. **Phase 3**: Generic [[Modal-Overlay-System]] with proper layering

### Key Insights
- **Arena.gd is monolithic** (378 lines) - handles rendering, UI, systems, input, debug
- **UI properly separated** into CanvasLayer but lacks layer prioritization
- **EventBus communication works well** - good decoupling pattern
- **Missing core scenes** - no main menu, pause menu, options screen
- **Enemy system now .tres resource-driven** - Pure data-driven approach with 4-tier knight system

### Enemy System Workflow
**.tres Resources → Registry → Tiers → Rendering Pipeline**
1. `enemy_registry.json` → Lists knight types with spawn weights and .tres paths
2. `knight_*.tres` → Individual enemy resource definitions loaded by `EnemyRegistry`
3. `EnemyRenderTier` → Assigns visual tiers based on size (SWARM/REGULAR/ELITE/BOSS)
4. `MultiMesh` → Batch rendering with tier-specific colors/animations
5. **Visual Result**: Red/Green/Blue/Magenta enemies with distinct behaviors

## Architecture Comparison

### Current vs Proposed
| Aspect | Current | Proposed | Priority |
|--------|---------|----------|----------|
| Scene Flow | Main → Arena | GameManager → Multiple Scenes | High |
| UI Layers | Single CanvasLayer | Multi-layer system | Medium |
| Modals | CardPicker only | Generic modal system | High |
| Scene Transitions | Hard-coded | Transition manager | Low |
| UI State | No management | Centralized UI state | Medium |

## File Organization

The documentation follows the established patterns:
- **[[Link]]** syntax for cross-references
- **Code blocks** with file references and line numbers
- **✅❌** indicators for implementation status
- **Structured headings** for easy navigation

## Related Project Files

### Key Implementation Files (UPDATED)
- `scenes/arena/Arena.gd` (main scene, 378 lines) - processes Array[EnemyEntity] signals
- `scenes/ui/HUD.gd` (game UI, 31 lines)
- `scenes/ui/KeybindingsDisplay.gd` (controls reference, 87 lines)
- `scripts/domain/EnemyType.gd` (enemy definitions from JSON)
- `scripts/domain/EnemyEntity.gd` (typed entity wrapper) ⭐ NEW
- `scripts/systems/EnemyRegistry.gd` (JSON enemy resource loading, knight types)
- `scripts/systems/WaveDirector.gd` (Array[EnemyEntity] pool management) ⭐ UPDATED
- `scripts/systems/EnemyRenderTier.gd` (tier assignment + Dictionary conversion) ⭐ UPDATED
- `scripts/systems/DamageSystem.gd` (object identity collision detection) ⭐ UPDATED
- `scripts/systems/MeleeSystem.gd` (WaveDirector references for pool indexing) ⭐ UPDATED
- `autoload/EventBus.gd` (communication system with Array[EnemyEntity] signals) ⭐ UPDATED
- `autoload/BalanceDB.gd` (data validation + hot-reload)
- `autoload/RunManager.gd` (player stats management)
- `scenes/main/Main.gd` (entry point, 14 lines)

### Architecture Documents
- `ARCHITECTURE.md` - Overall project architecture
- `DECISIONS.md` - Technical decisions and reasoning
- `CLAUDE.md` - Development guidelines and patterns