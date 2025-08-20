# Component Structure Reference

## Scene File Organization

### UI Components Location
```
vibe/scenes/ui/
├── CardPicker.tscn/.gd    - Modal card selection overlay
├── EnemyRadar.gd          - Radar component (no .tscn, embedded in HUD)
└── HUD.tscn/.gd          - Main game UI container
```

### Game Scene Components
```
vibe/scenes/arena/
├── Arena.tscn/.gd        - Main game scene (378 lines)
├── Player.tscn/.gd       - Player entity
└── XPOrb.tscn/.gd        - XP pickup objects
```

### Entry Point
```
vibe/scenes/main/
└── Main.tscn/.gd         - Application entry point (14 lines)
```

## Component Dependencies

### HUD Component Breakdown
**File**: `HUD.tscn` → **Script**: `HUD.gd` (31 lines)

**Node Structure**:
```
HUD (Control - fullscreen anchoring)
├── VBoxContainer (bottom-left positioning)  
│   ├── LevelLabel (text display)
│   └── XPBar (ProgressBar widget)
└── EnemyRadar (Panel - top-right)
```

**Dependencies**:
- **EventBus**: `xp_changed`, `level_up` signals
- **EnemyRadar**: Embedded component (script-only)

### CardPicker Component
**File**: `CardPicker.tscn` → **Script**: `CardPicker.gd`

**Responsibilities**:
- Modal card selection on level up
- Game pause integration via [[RunManager-System]]
- Triggered by `EventBus.level_up`

### Arena Component (Complex)
**File**: `Arena.tscn` → **Script**: `Arena.gd` (378 lines)

**Node Children**:
```
Arena (Node2D)
├── MM_Projectiles (MultiMeshInstance2D)
├── MM_Enemies (MultiMeshInstance2D)  
├── MM_Walls (MultiMeshInstance2D)
├── MM_Terrain (MultiMeshInstance2D)
├── MM_Obstacles (MultiMeshInstance2D)
└── MM_Interactables (MultiMeshInstance2D)
```

**System Dependencies** (9 systems):
- `AbilitySystem` - Combat abilities
- `WaveDirector` - Enemy spawning  
- `DamageSystem` - Combat damage
- `ArenaSystem` - Level loading
- `TextureThemeSystem` - Visual themes
- `CameraSystem` - Camera control
- `XpSystem` - Experience management
- `TerrainSystem` - Ground rendering
- `ObstacleSystem` - Environment objects

**UI Management**:
- Creates `UILayer` (CanvasLayer)
- Instantiates `HUD` and `CardPicker`
- Handles modal triggering

## Component Communication Patterns

### Input Flow
```
User Input → Arena._input() → Arena System Methods → EventBus → UI Updates
```

### UI Update Flow  
```
System Logic → EventBus.signal → HUD._on_signal() → UI Visual Update
```

### Modal Flow
```
Level Up → EventBus.level_up → Arena._on_level_up() → CardPicker.open()
```

## Component Sizing & Positioning

### HUD Positioning Strategy
- **VBoxContainer**: Bottom-left corner with margins
  - `anchors_preset = 2` (bottom-left)
  - `offset_left = 10, offset_top = -60` (margins)
- **EnemyRadar**: Top-right corner  
  - `anchors_preset = 1` (top-right)
  - Fixed size `150x150` with margins

### Responsive Issues
- **Fixed Offsets**: Hard-coded pixel positions
- **No Scaling**: Doesn't adapt to screen resolution
- **No Safe Areas**: No mobile/aspect ratio considerations

## Component Lifecycle

### Initialization Order (Arena)
1. **System Creation**: Lines 23-28 (AbilitySystem, WaveDirector, etc.)
2. **System Addition**: Lines 39-44 (`add_child()` for systems)
3. **Player Setup**: Lines 50, 200-207
4. **UI Setup**: Lines 52, 213-223
5. **Signal Connections**: Lines 57-66
6. **MultiMesh Setup**: Lines 69-77
7. **Arena Loading**: Line 77

### Cleanup (Arena._exit_tree)
- **Signal Disconnection**: Lines 363-367 (EventBus signals)
- **System Signal Cleanup**: Lines 370-377 (subsystem signals)

## Component Complexity Analysis

### Simple Components (Good)
- **Main**: 14 lines - minimal coordination
- **HUD**: 31 lines - focused UI updates
- **Player**: (not analyzed) - likely focused entity

### Complex Components (Needs Refactoring)
- **Arena**: 378 lines - too many responsibilities
  - Rendering setup (79-168)
  - UI management (213-224)  
  - System coordination (38-77)
  - Input handling (178-199)
  - Debug functionality (255-282)

## Missing Components (From Original Plan)

### Reusable UI Components
- **AbilityBar**: Skill/ability display
- **HealthBar**: Player health display
- **Minimap**: Arena overview map
- **OptionsMenu**: Settings configuration
- **PauseMenu**: Game pause interface

### Scene Controllers
- **MainMenuController**: Main menu logic
- **ArenaController**: Arena-specific logic (separate from Arena scene)
- **HideoutController**: Future hideout scene

## Component Refactoring Recommendations

### Arena Scene Splitting
```
Current: Arena.gd (378 lines)

Proposed Split:
├── Arena.tscn (rendering only)
├── ArenaController.gd (game logic)
├── RenderingManager.gd (MultiMesh setup)
└── SystemCoordinator.gd (system initialization)
```

### UI Component Extraction
```
Current: HUD embedded in Arena

Proposed:
├── GameHUD.tscn (level, XP, health)
├── AbilityBar.tscn (skill buttons)
├── Minimap.tscn (radar + overview)
└── StatusEffects.tscn (buffs/debuffs)
```

## Related Systems

- [[Scene-Management-System]]: How components fit in scene hierarchy
- [[Canvas-Layer-Structure]]: UI component layering
- [[EventBus-System]]: Component communication patterns
- [[UI-Architecture-Overview]]: Overall component organization