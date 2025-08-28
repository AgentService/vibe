# Component Structure Reference

## Scene File Organization

### UI Components Location
```
scenes/ui/
├── CardPicker.tscn/.gd       - Modal card selection overlay
├── EnemyRadar.gd             - Radar component (no .tscn, embedded in HUD)
├── KeybindingsDisplay.gd     - Controls reference panel (embedded in HUD)
└── HUD.tscn/.gd             - Main game UI container
```

### Game Scene Components
```
scenes/arena/
├── Arena.tscn/.gd        - Main game scene (378 lines)
├── Player.tscn/.gd       - Player entity
└── XPOrb.tscn/.gd        - XP pickup objects
```

### Entry Point
```
scenes/main/
└── Main.tscn/.gd         - Application entry point (14 lines)
```

## Component Dependencies

### HUD Component Breakdown
**File**: `HUD.tscn` → **Script**: `HUD.gd` (31 lines)

**Node Structure**:
```
HUD (Control - fullscreen anchoring)
├── FPSLabel (bottom-left performance)
├── VBoxContainer (bottom-left positioning)  
│   ├── LevelLabel (text display)
│   └── XPBar (ProgressBar widget)
├── EnemyRadar (Panel - top-right)
└── KeybindingsDisplay (Panel - below radar)
```

**Dependencies**:
- **EventBus**: `xp_changed`, `level_up` signals
- **EnemyRadar**: Embedded component (script-only)
- **KeybindingsDisplay**: Static reference panel (no external dependencies)

### CardPicker Component
**File**: `CardPicker.tscn` → **Script**: `CardPicker.gd`

**Responsibilities**:
- Modal card selection on level up
- Game pause integration via [[RunManager-System]]
- Triggered by `EventBus.level_up`

### KeybindingsDisplay Component
**File**: `KeybindingsDisplay.gd` (87 lines) → Embedded in `HUD.tscn`

**Node Structure**:
```
KeybindingsDisplay (Panel - styled)
└── VBoxContainer (margins for content)
    ├── Title Label ("[Controls]")
    ├── Spacer (vertical spacing)
    └── GridContainer (2-column table)
        ├── Action Labels (left column)
        └── Key Labels (right column)
```

**Responsibilities**:
- Display current control bindings in always-visible format
- Static reference panel (no signal dependencies)
- Self-contained styling with radar-theme consistency
- Table-formatted display using [[GridContainer]]

**Styling Features**:
- **Radar-Style Theme**: Dark background (0.0, 0.0, 0.0, 0.7) with gray borders
- **Border Styling**: 2px gray border with 4px corner radius
- **Typography**: White text for keys, gray for actions
- **Layout**: Two-column grid with proper spacing (8px h-separation, 2px v-separation)

**Current Bindings Displayed**:
- Movement: WASD
- Attack: Left Click  
- System: F10 (Pause), F12 (FPS), T (Theme)
- Arena switching: 1-5

**Integration**:
- Positioned below [[EnemyRadar-Component]] in top-right corner
- Uses same anchoring strategy (`anchors_preset = 1`)
- No external dependencies or signal connections

### Arena Component (Complex) - UPDATED Architecture
**File**: `Arena.tscn` → **Script**: `Arena.gd` (378 lines)  
**Key Changes**: Now processes typed Array[EnemyEntity] instead of Dictionary arrays

**Node Children** (UPDATED for Typed Enemy System):
```
Arena (Node2D)
├── MM_Projectiles (MultiMeshInstance2D)
├── MM_Enemies_Swarm (MultiMeshInstance2D)     # EnemyEntity → Dict conversion
├── MM_Enemies_Regular (MultiMeshInstance2D)   # Tier-based routing via EnemyRenderTier
├── MM_Enemies_Elite (MultiMeshInstance2D)     # Objects grouped by visual tier
├── MM_Enemies_Boss (MultiMeshInstance2D)      # Dictionary arrays for GPU batching
├── MM_Walls (MultiMeshInstance2D)
├── MM_Terrain (MultiMeshInstance2D)
├── MM_Obstacles (MultiMeshInstance2D)
└── MM_Interactables (MultiMeshInstance2D)
```

**System Dependencies** (13 systems):
- `AbilitySystem` - Combat abilities with projectile pool management
- `WaveDirector` - Typed enemy pool management with Array[EnemyEntity] ⭐ UPDATED
- `DamageSystem` - Combat damage with object identity collision detection ⭐ UPDATED  
- `EnemyRenderTier` - Converts EnemyEntity objects to Dictionary arrays for MultiMesh ⭐ UPDATED
- `ArenaSystem` - Level loading and arena configuration
- `CameraSystem` - Camera control and zoom management
- `XpSystem` - Experience management with kill event integration
- `MeleeSystem` - Melee combat with WaveDirector reference for pool indexing ⭐ UPDATED

**UI Management**:
- Creates `UILayer` (CanvasLayer)
- Instantiates `HUD` and `CardPicker`
- Handles modal triggering

## Component Communication Patterns

### Input Flow
```
User Input → Arena._input() → Arena System Methods → EventBus → UI Updates
```

### Enemy System Flow (UPDATED)
```
WaveDirector (Array[EnemyEntity]) → enemies_updated signal → Arena._on_enemies_updated()
    ↓
EnemyRenderTier.group_enemies_by_tier() → Dictionary arrays by tier
    ↓  
MultiMeshInstance2D updates (per-tier GPU batching)
```

### Combat System Flow (UPDATED)
```
DamageSystem collision detection → WaveDirector.damage_enemy(index)
    ↓
EnemyEntity.hp -= damage → EventBus.enemy_killed → XpSystem
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
- **FPSLabel**: Bottom-left corner above VBoxContainer
  - `anchors_preset = 2` (bottom-left)
  - `offset_left = 10, offset_top = -80` (margins)
- **VBoxContainer**: Bottom-left corner with margins
  - `anchors_preset = 2` (bottom-left)
  - `offset_left = 10, offset_top = -60` (margins)
- **EnemyRadar**: Top-right corner  
  - `anchors_preset = 1` (top-right)
  - Fixed size `150x150` with margins
- **KeybindingsDisplay**: Below radar, top-right
  - `anchors_preset = 1` (top-right)
  - Position: `offset_top = 180` (below radar)
  - Fixed size `150x140` with matching margins

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
- **KeybindingsDisplay**: 87 lines - self-contained UI reference panel
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

### ✅ Recently Implemented UI Components
- **KeybindingsDisplay**: Always-visible controls reference panel (COMPLETED)

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