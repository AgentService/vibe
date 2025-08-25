# Comprehensive GameOrchestrator Refactor Plan

## Phase 1: Foundation

### 1.1 Create GameOrchestrator Autoload
**File:** `vibe/autoload/GameOrchestrator.gd`
```gdscript
extends Node
class_name GameOrchestrator

# Core orchestration events
signal systems_initialized()
signal world_ready()

# System references
var systems: Dictionary = {}
var initialization_phase: String = "idle"

func initialize_core_loop():
    # Phase 1: Core singletons (already loaded via autoload)
    # Phase 2: Initialize game systems
    # Phase 3: Setup world
    # Phase 4: Start gameplay
```

### 1.2 Update Project Settings
- Add GameOrchestrator to autoloads (load AFTER EventBus, BEFORE RunManager)
- Add "ui_cancel" input mapping for Escape key
- Keep existing autoload order for other systems

## Phase 2: System Migration (With User Testing Checkpoints)

### 2.1 System Initialization Order
Based on dependency analysis:
```
1. EnemyRegistry (no deps)
2. CardSystem (no deps)  
3. WaveDirector (needs EnemyRegistry)
4. AbilitySystem (no deps)
5. MeleeSystem (needs WaveDirector ref)
6. DamageSystem (needs AbilitySystem, WaveDirector refs)
7. ArenaSystem (no deps)
8. CameraSystem (no deps)
9. XpSystem (needs arena node - special case)
```

## MIGRATION PHASES WITH USER TESTING

### PHASE A: Foundation Setup
**Implementation:**
1. Create `vibe/autoload/GameOrchestrator.gd` with basic structure
2. Add to project.godot autoloads
3. Add "ui_cancel" input mapping for Escape key
4. Create backup of Arena.gd

**🧪 USER TEST A:**
- Run game with `../Godot_v4.4.1-stable_win64_console.exe --headless --quit-after 5`
- Verify game still starts normally
- Check that nothing is broken
- **✋ STOP - Wait for user confirmation before proceeding**

---

### PHASE B: First System (CardSystem)
**Implementation:**
1. Move CardSystem creation from Arena.gd to GameOrchestrator
2. Pass CardSystem reference to Arena via new method
3. Update Arena's card-related methods to use injected system

**🧪 USER TEST B:**
- Start game and reach level-up
- Verify card selection still appears
- Test card application works
- Check Logger output for card system messages
- **✋ STOP - Wait for user confirmation before proceeding**

---

### PHASE C: Non-Dependent Systems (EnemyRegistry, AbilitySystem, ArenaSystem, CameraSystem)
**Implementation:**
1. Move these 4 systems to GameOrchestrator (no dependencies)
2. Update Arena.gd to receive them
3. Maintain signal connections

**🧪 USER TEST C:**
- Verify camera follows player
- Check projectiles spawn (right-click)
- Ensure arena bounds work
- Test enemy registry loads enemy types
- **✋ STOP - Wait for user confirmation before proceeding**

---

### PHASE D: WaveDirector System
**Implementation:**
1. Move WaveDirector to GameOrchestrator
2. Pass EnemyRegistry reference to WaveDirector
3. Update Arena's enemy spawn methods

**🧪 USER TEST D:**
- Verify enemies spawn correctly
- Check wave progression works
- Test boss spawns (if applicable)
- Monitor enemy behavior
- **✋ STOP - Wait for user confirmation before proceeding**

---

### PHASE E: Combat Systems (MeleeSystem, DamageSystem)
**Implementation:**
1. Move MeleeSystem to GameOrchestrator
2. Set WaveDirector reference via setter
3. Move DamageSystem to GameOrchestrator  
4. Set AbilitySystem and WaveDirector references

**🧪 USER TEST E:**
- Test melee attacks (left-click)
- Verify damage numbers appear
- Check enemy death and XP drops
- Test projectile damage
- **✋ STOP - Wait for user confirmation before proceeding**

---

### PHASE F: Special Case - XpSystem
**Implementation:**
1. Keep XpSystem creation in Arena (needs arena node)
2. OR refactor to use EventBus for orb spawning
3. Maintain all XP/level functionality

**🧪 USER TEST F:**
- Collect XP orbs
- Verify level-up triggers
- Check XP bar updates
- Test card selection on level-up
- **✋ STOP - Wait for user confirmation before proceeding**

---

## Phase 3: Pause Menu Implementation

### 3.1 Create PauseMenu Scene
**File:** `vibe/scenes/ui/PauseMenu.tscn`
- CanvasLayer root (layer 10)
- ColorRect background (semi-transparent black)
- CenterContainer → VBoxContainer:
  - Label "PAUSED"
  - Resume Button
  - Options Button (disabled/placeholder)
  - Quit Button

### 3.2 Create PauseMenu Script
**File:** `vibe/scenes/ui/PauseMenu.gd`
```gdscript
extends CanvasLayer
class_name PauseMenu

@onready var resume_button: Button = $CenterContainer/VBoxContainer/ResumeButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready():
    process_mode = Node.PROCESS_MODE_WHEN_PAUSED
    visible = false
    resume_button.pressed.connect(_on_resume_pressed)
    quit_button.pressed.connect(_on_quit_pressed)
    
func _unhandled_input(event):
    if event.is_action_pressed("ui_cancel"):
        toggle_pause()
        
func toggle_pause():
    visible = !visible
    PauseManager.pause_game(visible)
```

### 3.3 Integration
- Add PauseMenu to Arena or Main scene
- Remove F10 debug pause from Arena.gd

**🧪 USER TEST - PAUSE MENU:**
- Press Escape during gameplay
- Verify game pauses and menu appears
- Test Resume button
- Test Quit button
- Verify Escape toggles pause
- **✋ STOP - Wait for user confirmation before proceeding**

---

## Phase 4: Isolated Testing Scene

### 4.1 Create CoreLoop_Isolated.tscn
```
Node2D (root)
├─ Player (with movement script)
│  └─ Camera2D (current=true)
├─ UILayer (CanvasLayer)
│  ├─ HUD (minimal - HP/XP placeholders)
│  └─ PauseMenu
└─ TestOrchestrator (minimal system setup)
```

### 4.2 Isolated Scene Features
- Player WASD movement
- Camera follows player
- Basic HUD showing placeholder values
- Pause menu on Escape
- NO enemies, NO combat, NO progression

**🧪 USER TEST - ISOLATED SCENE:**
- Run with F6 or `--headless tests/CoreLoop_Isolated.tscn`
- Verify player moves with WASD
- Check camera follows
- Test pause menu
- Confirm no errors in console
- **✋ STOP - Wait for user confirmation**

---

## System Dependencies Resolution

### Direct System Calls to Address
Current Arena.gd has direct calls that need interface methods:
```gdscript
# Line 174, 400, 414: 
wave_director.get_alive_enemies()  # Add public method

# Line 298, 418:
melee_system.set_auto_attack_target()  # Already public
melee_system.perform_attack()  # Already public

# Line 430:
melee_system._get_effective_range()  # Make public (remove _)
```

### Signal Rewiring Plan
Connections to move from Arena to GameOrchestrator:
- `ability_system.projectiles_updated` → stays in Arena (rendering)
- `wave_director.enemies_updated` → stays in Arena (rendering)
- `arena_system.arena_loaded` → stays in Arena (bounds)
- `melee_system.melee_attack_started` → stays in Arena (effects)

## Safety Measures

### Before Starting:
1. Git commit current state
2. Create Arena.gd.backup
3. Document current working behavior

### Rollback Plan:
- Each phase is independently revertible
- Keep F10 debug pause as backup during transition
- Arena.gd.backup can restore original

### Testing Commands:
```bash
# Quick headless test
"../Godot_v4.4.1-stable_win64_console.exe" --headless --quit-after 5

# Run isolated scene
"../Godot_v4.4.1-stable_win64_console.exe" --headless tests/CoreLoop_Isolated.tscn

# Run main game
"../Godot_v4.4.1-stable_win64_console.exe" vibe/scenes/main/Main.tscn
```

## Success Criteria Per Phase

✅ **Phase A**: Game starts, no errors
✅ **Phase B**: Card system works identically  
✅ **Phase C**: All 4 systems function normally
✅ **Phase D**: Enemies spawn and behave correctly
✅ **Phase E**: Combat fully functional
✅ **Phase F**: XP/leveling works
✅ **Pause Menu**: Escape key pauses with UI
✅ **Isolated Scene**: Runs independently

## Final Notes

- Each phase should take 30-60 minutes
- User testing after EACH phase is critical
- Don't proceed if tests fail
- Keep changes minimal and focused
- Document any issues encountered

The refactor maintains all current functionality while enabling:
- Better system isolation
- Cleaner initialization flow
- Testable components
- Foundation for your PoE-style complexity