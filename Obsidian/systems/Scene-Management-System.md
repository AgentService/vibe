# Scene Management System

## Current Implementation

### Scene Flow
```
Main.tscn (Node2D)
├── Script: Main.gd (14 lines - minimal)
└── Arena (instance of Arena.tscn)
```

**Current Path**: `Main.tscn` → `Arena.tscn` (direct instantiation)

## Scene Hierarchy Detail

### Main.tscn Structure
- **Type**: `Node2D`
- **Script**: `res://scenes/main/Main.gd`
- **Children**: Single `Arena` instance
- **Responsibilities**: 
  - Combat step signal connection (debugging)
  - Minimal game state management

### Arena.tscn Structure  
- **Type**: `Node2D`
- **Script**: `res://scenes/arena/Arena.gd` (378 lines)
- **Children**: 6x `MultiMeshInstance2D` nodes for rendering
- **Responsibilities**: 
  - Game logic coordination
  - UI management via [[Canvas-Layer-Structure]]
  - System initialization (9 different systems)
  - Input handling (arena switching, debug controls)

## Current Problems

### 1. Monolithic Arena Scene
The Arena scene handles too many responsibilities:
- Rendering setup (lines 79-168 in Arena.gd)
- UI management (lines 213-224)
- System coordination (lines 38-77)
- Input handling (lines 178-199)
- Debug functionality (lines 255-282)

### 2. No Scene Transition System
- Hard-coded scene loading
- No transition animations
- No scene state preservation
- No back/forward navigation

### 3. Missing Scene Types
From original plan, missing:
- `MainMenuScene`
- `HideoutScene`
- Scene transition management
- Loading screens

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