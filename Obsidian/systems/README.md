# Systems Documentation

This folder contains comprehensive documentation of the game's UI and scene management architecture.

## Core UI Architecture Documents

### 📋 [[UI-Architecture-Overview]]
**Main reference document** - Current implementation status, strengths, and areas for improvement compared to the original plan.

### 🎬 [[Scene-Management-System]]  
Scene hierarchy, transitions, and the current Main → Arena flow. Includes proposed GameManager architecture.

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

## Quick Navigation

### Current State Analysis
- **Working Well**: [[EventBus-System]], [[Canvas-Layer-Structure]] (basic), [[Data-Systems-Architecture]] (validation + hot-reload)
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

### Key Implementation Files
- `vibe/scenes/arena/Arena.gd` (main scene, 378 lines)
- `vibe/scenes/ui/HUD.gd` (game UI, 31 lines)
- `vibe/scenes/ui/KeybindingsDisplay.gd` (controls reference, 87 lines)
- `vibe/scripts/domain/EnemyType.gd` (enemy definitions)
- `vibe/scripts/domain/EnemyEntity.gd` (entity wrapper)  
- `vibe/scripts/systems/EnemyRegistry.gd` (.tres enemy resource loading, knight types)
- `vibe/scripts/systems/EnemyBehaviorSystem.gd` (AI patterns)
- `vibe/autoload/EventBus.gd` (communication system)
- `vibe/autoload/BalanceDB.gd` (data validation + hot-reload)
- `vibe/autoload/RunManager.gd` (player stats management)
- `vibe/scenes/main/Main.gd` (entry point, 14 lines)

### Architecture Documents
- `ARCHITECTURE.md` - Overall project architecture
- `DECISIONS.md` - Technical decisions and reasoning
- `CLAUDE.md` - Development guidelines and patterns