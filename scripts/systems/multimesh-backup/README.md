# MultiMesh Systems - Backup Archive

## Purpose
This folder contains MultiMesh rendering systems that have been archived after the decision to use scene-based enemies only and clean slate approach for projectiles.

## Archived Systems

### Core MultiMesh System
- `MultiMeshManager.gd` - Complete MultiMesh rendering and management system (500+ lines)

### Hit Feedback Systems
- `EnemyMultiMeshHitFeedback.gd` - Complete 500+ line hit feedback system for MultiMesh enemies
- `EnhancedEnemyHitFeedback.gd` - Alternative MultiMesh hit feedback system
- `MultiMeshHitFeedbackFix.gd` - Debug/fix system for MultiMesh feedback
- `AlternativeVisualFeedback.gd` - Alternative visual feedback utilities for MultiMesh

### Animation Systems
- `EnemyAnimationSystem.gd` - MultiMesh animation frame management (moved from main systems)

### Investigation & Test Tools
- `test_multimesh_investigation.gd` - Investigation script for MultiMesh rendering tests
- `test_performance_500_enemies.gd` - Comprehensive performance testing for MultiMesh vs Scene enemies
- `AbilitySystem_Isolated.gd` - Isolated test for MultiMesh projectile system

## Current Architecture (September 2025)
- **Enemies**: Scene-based only (ancient_lich, banana_lord, dragon_lord)
- **Projectiles**: Clean slate - no current projectile system
- **MultiMeshManager**: Archived in place with deprecation warnings

## Detailed Removal Map - What Was Removed & Why

### SessionManager.gd
**Removed**: `_find_multimesh_projectiles()` function and projectile clearing logic
**Location**: Lines 320-326 (clearing call), Lines 366-373 (function)
**Purpose**: Cleared MultiMesh projectile instances during session resets to prevent visual artifacts
**Why Needed**: MultiMesh projectiles persist in GPU memory and need manual clearing between sessions
**Restoration**: Add back projectile clearing logic in `_clear_temporary_objects()`

### Arena.gd 
**Removed**: Complete MultiMesh infrastructure
**Locations & Purposes**:
- **Lines 25-30**: MultiMeshInstance2D node references (`@onready var mm_projectiles`, `mm_enemies_*`)
  - **Purpose**: Direct references to scene nodes for MultiMesh rendering
- **Line 16**: MultiMeshManagerScript import 
  - **Purpose**: Class reference for MultiMeshManager instantiation
- **Line 36**: MultiMeshManager variable declaration
  - **Purpose**: Instance variable to hold the MultiMesh rendering system
- **Lines 140-142**: MultiMeshManager instantiation and setup
  - **Purpose**: Creates and configures MultiMesh system with all tier references
- **Lines 215-217**: VisualEffectsManager MultiMesh setup call
  - **Purpose**: Configures hit feedback systems with MultiMesh references
- **Lines 230-237**: EnemyAnimationSystem MultiMesh setup
  - **Purpose**: Provides MultiMesh references for enemy animation updates
- **Lines 447-448**: MultiMesh signal disconnections in teardown
  - **Purpose**: Prevents memory leaks by properly disconnecting MultiMesh update signals

### SystemInjectionManager.gd
**Removed**: `enemies_updated` signal connection
**Location**: Line 70
**Purpose**: Connected WaveDirector's enemy position updates to MultiMeshManager for rendering
**Why Needed**: MultiMesh instances need position updates from the enemy pool for visual synchronization
**Restoration**: Add back `injected_wave_director.enemies_updated.connect(arena_ref.multimesh_manager.update_enemies)`

### DebugConfig.gd
**Removed**: MultiMesh performance flags group
**Location**: Lines 14-18
**Flags Removed**:
- `multimesh_use_colors`: Controlled per-instance color data for performance
- `multimesh_update_30hz`: Enabled 30Hz update decimation vs 60Hz
- `multimesh_shrink_interval_sec`: Buffer shrinking interval for memory management
**Purpose**: Runtime performance tuning for MultiMesh rendering systems
**Restoration**: Add back `@export_group("MultiMesh Rendering")` section

### VisualEffectsManager.gd
**Removed**: MultiMesh enemy feedback system
**Locations & Purposes**:
- **Line 7**: `EnemyMultiMeshHitFeedback` variable declaration
- **Lines 20-21**: EnemyMultiMeshHitFeedback instantiation
- **Lines 36-39**: `setup_enemy_feedback_references()` function - configured MultiMesh references for hit effects
- **Lines 42-47**: Enemy feedback dependency injection (EnemyRenderTier, WaveDirector)
- **Lines 52-53**: `get_enemy_hit_feedback()` accessor function
**Purpose**: Applied visual hit effects (flash, knockback) to MultiMesh enemy instances
**Why Complex**: MultiMesh enemies don't have individual scene nodes, requiring index-based effect application

### EnemyAnimationSystem.gd
**Status**: Moved to backup (September 11, 2025) - obsolete after MultiMesh removal
**Original Purpose**: 
- Managed sprite frame animations for MultiMesh enemies
- Applied texture region updates across MultiMesh instances
- Synchronized animation timing across enemy tiers
**Why Needed**: MultiMesh instances share single texture, requiring coordinated animation updates
**Current State**: Scene-based enemies handle their own animations through AnimationPlayer nodes
**Restoration**: Restore original animation frame management and texture region logic if MultiMesh enemies reactivated

### EntitySelector.gd (Debug System)
**Removed**: MultiMesh visual offset compensation
**Locations**:
- **Lines 327-334**: `_get_visual_position()` MultiMesh offset logic  
- **Lines 336-341**: `_get_entity_visual_offset()` function
- **Lines 362-378**: MultiMesh-specific functions (`_is_multimesh_entity`, `_apply_multimesh_sprite_effect`, etc.)
**Purpose**: Compensated for rendering offset differences between MultiMesh instances and stored positions
**Why Needed**: MultiMesh rendering positions didn't always match logical entity positions, requiring visual correction for debug tools

## Reactivation Requirements
Only reactivate if >2000 simultaneous entities are needed:

1. **Restore Arena Infrastructure**:
   - Add MultiMeshInstance2D nodes back to Arena.tscn
   - Restore MultiMeshManager instantiation and setup in Arena.gd
   - Restore signal connections in SystemInjectionManager

2. **Restore Code Files**:
   - Move files from this backup folder back to `scripts/systems/`
   - Restore EnemyAnimationSystem MultiMesh functionality
   - Restore VisualEffectsManager MultiMesh setup functions

3. **Restore WaveDirector Signals**:
   - Re-enable `enemies_updated.emit()` calls in WaveDirector
   - Restore MultiMesh enemy spawning logic

4. **Testing**:
   - Verify performance benefits with >2000 entities
   - Test all MultiMesh hit feedback systems
   - Validate entity registration and cleanup

## Performance Baseline
- Scene-based enemies handle 500-700 instances adequately
- MultiMesh benefits only apparent at very high entity counts (>2000)
- Clean slate projectile approach allows for optimal future design

## Archive Date
September 11, 2025 - Complete MultiMesh cleanup and backup