# Scene Management System

## Current Implementation (UPDATED)

### Scene Flow with State Management
```
StateManager (Autoload) - Centralized state orchestration
├── SessionManager (Autoload) - Entity cleanup & session resets  
├── Main.tscn (Node2D) - Entry point
└── Arena (instance of Arena.tscn) - Game content
```

**Current Path**: `StateManager` → Scene States → `Arena.tscn`
**New Architecture**: Typed state transitions with validation and cleanup

## State Management Architecture

### StateManager - Typed Scene States
```gdscript
enum State {
    BOOT,           # Application startup
    MENU,           # Main menu (not implemented)
    CHARACTER_SELECT, # Character selection (not implemented)
    HIDEOUT,        # Hub area (not implemented)
    ARENA,          # Combat arena (current implementation)
    RESULTS,        # Run results screen (not implemented)
    EXIT            # Application shutdown
}
```

### Scene Transition API
```gdscript
# Typed transitions with context
StateManager.go_to_menu()
StateManager.go_to_hideout()
StateManager.start_run("arena_forest_1", {"difficulty": "normal"})
StateManager.end_run({"success": true, "wave_count": 15})
StateManager.return_to_menu("user_quit")
```

### SessionManager - Multi-Phase Cleanup
```gdscript
enum ResetReason {
    DEBUG_RESET,     # Manual reset
    PLAYER_DEATH,    # Player died (preserve enemies for results)
    MAP_TRANSITION,  # Between arenas/maps
    HIDEOUT_RETURN,  # Return to hub
    RUN_END,         # Run completed
    LEVEL_RESTART    # Restart same level
}
```

## Current Scene Structure

### Main.tscn Structure (Entry Point)
- **Type**: `Node2D`
- **Script**: `res://scenes/main/Main.gd` (14 lines)
- **Children**: Single `Arena` instance
- **New Role**: Bootstrap StateManager, minimal coordination
- **Future**: Will be replaced by GameManager pattern

### Arena.tscn Structure (Current Game Content)
- **Type**: `Node2D`  
- **Script**: `res://scenes/arena/Arena.gd` (378 lines)
- **Children**: 6x `MultiMeshInstance2D` nodes + UI layers
- **Responsibilities**: 
  - Game logic coordination
  - UI management via CanvasLayer structure
  - System initialization (9+ systems)
  - Input handling + debug controls
- **Integration**: Responds to StateManager signals

## Resolved Problems (NEW)

### ✅ 1. Scene Transition System Implemented
- **StateManager**: Centralized state orchestration with typed enums
- **Transition validation**: Invalid transitions are blocked and logged
- **Context passing**: Rich context data flows between states
- **Signal architecture**: Decoupled communication via EventBus

### ✅ 2. Entity Cleanup System Implemented  
- **SessionManager**: Multi-phase cleanup with different strategies
- **EntityClearingService**: Production-ready entity management
- **Context-aware cleanup**: Different reset types preserve different data
- **Player registration validation**: Ensures systems remain consistent

### ❌ 3. Missing Scene Types (Still Outstanding)
From original plan, still missing:
- `MainMenuScene` - Main menu interface
- `HideoutScene` - Hub/town area  
- `ResultsScene` - Run completion screen
- `CharacterSelectScene` - Character creation/selection

## Proposed Architecture (From Original Plan)

### Game Manager Pattern
```
GameManager (Main Scene Controller)
├── SceneContainer (Dynamic scene loading)
│   ├── MainMenuScene
│   ├── HideoutScene  
│   ├── ArenaScene (current Arena.tscn)
│   └── (future scenes)
└── UIManager ([[Canvas-Layer-Structure]])
```

### Benefits of Proposed System
- **Scalable**: Easy to add new scenes
- **Maintainable**: Separated responsibilities
- **Reusable**: UI components work across scenes
- **Future-proof**: Ready for hideout, main menu, etc.

## Implementation Priority

### Phase 1: Core Infrastructure
1. Create `GameManager` as main scene controller
2. Extract UI from Arena into [[UIManager-Autoload]]
3. Create `SceneContainer` for dynamic loading

### Phase 2: Scene Separation
1. Convert Arena to content-only scene
2. Move system initialization to appropriate managers
3. Create transition system

### Phase 3: New Scenes
1. Add main menu scene
2. Prepare hideout scene structure
3. Implement scene state management

## Related Systems

- [[UI-Architecture-Overview]]: Overall UI structure
- [[Canvas-Layer-Structure]]: UI layering within scenes
- [[EventBus-System]]: Inter-scene communication
- [[RunManager-System]]: Game state management across scenes