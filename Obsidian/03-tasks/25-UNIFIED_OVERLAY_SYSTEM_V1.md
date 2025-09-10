# Unified Overlay System V1

**Status**: 📋 **Planning**  
**Priority**: High  
**Type**: UI Architecture Foundation  
**Created**: 2025-09-10  
**Context**: Build unified overlay system for all modal UIs (ResultsScreen, Inventory, CharScreen, Skill Tree, etc.)

## Overview

Create a production-ready unified overlay system that handles all modal/popup UIs with base classes, consistent theming, and standardized behavior. The ResultsScreen death overlay will serve as the first implementation test.

**Key Goal**: Replace ad-hoc modal implementations with a consistent, reusable overlay framework that works across the entire game.

## Current State Analysis

### ✅ **Existing Foundation (Good Starting Points)**
- **Modal-Overlay-System.md**: Comprehensive analysis of current CardPicker modal
- **UI-Architecture-Enhancement task**: Planned theme system and component library  
- **ResultsScreen**: Existing popup structure that needs conversion to overlay
- **EventBus patterns**: Working signal-based communication

### 🔧 **Current Problems**
- **ResultsScreen is scene transition**: Should be overlay preserving background game
- **No unified overlay manager**: Each modal handles own lifecycle
- **Inconsistent theming**: No base theme for overlays
- **No animation framework**: Manual tween code in each component
- **No overlay stack**: Can't handle multiple overlays properly

## Architecture Design

### Core Components

```gdscript
# Unified overlay management
class OverlayManager extends CanvasLayer:
    enum OverlayType {
        RESULTS_SCREEN,
        INVENTORY,
        CHARACTER_SCREEN,
        SKILL_TREE,
        CARD_PICKER,
        PAUSE_MENU,
        SETTINGS
    }
    
    var overlay_stack: Array[BaseOverlay] = []
    var active_overlay: BaseOverlay = null
    var background_dimmer: ColorRect
```

```gdscript
# Base class for all overlays
class BaseOverlay extends Control:
    @export var overlay_type: OverlayManager.OverlayType
    @export var dims_background: bool = true
    @export var pauses_game: bool = false
    @export var closeable_with_escape: bool = true
    
    signal overlay_opened()
    signal overlay_closed()
    
    func open_overlay(context: Dictionary = {}) -> void
    func close_overlay() -> void
    func on_escape_pressed() -> bool  # Return true if handled
```

### Theme System Foundation

```gdscript
# Base theme for all overlays
class OverlayTheme extends Resource:
    @export var background_color: Color = Color(0.2, 0.2, 0.2, 0.95)
    @export var dim_color: Color = Color(0.0, 0.0, 0.0, 0.7)
    @export var border_color: Color = Color(0.4, 0.4, 0.4)
    @export var text_color: Color = Color.WHITE
    @export var accent_color: Color = Color(0.3, 0.6, 1.0)
    @export var button_style: ButtonStyle
    @export var panel_style: PanelStyle
```

### Animation Framework

```gdscript
# Standardized overlay animations
class OverlayAnimator:
    static func fade_in_overlay(overlay: Control, duration: float = 0.3)
    static func scale_in_overlay(overlay: Control, from_scale: float = 0.8)
    static func slide_in_overlay(overlay: Control, from_direction: Vector2)
    static func dim_background(dimmer: ColorRect, target_alpha: float = 0.7)
```

## Cleanup & Migration Strategy

### Current UI Elements Analysis

#### 🗑️ **Elements to Remove/Replace**
```gdscript
# OLD: Scene-based ResultsScreen transition
# LOCATION: Player.gd _handle_death_sequence(), SceneTransitionManager.gd
StateManager.end_run(death_result)  # → REMOVE
SceneTransitionManager._load_scene_for_state(State.RESULTS)  # → REMOVE

# OLD: Individual modal implementations  
scenes/ui/CardPicker.tscn/.gd  # → MIGRATE to BaseOverlay
scenes/ui/overlays/PauseOverlay.tscn/.gd  # → MIGRATE to BaseOverlay

# OLD: Hardcoded styling scattered throughout
# LOCATIONS: ResultsScreen.gd, CardPicker.gd, HUD.gd, etc.
add_theme_color_override("panel", Color(0.2, 0.2, 0.2, 0.95))  # → REPLACE with theme
add_theme_font_size_override("font_size", 32)  # → REPLACE with theme
```

#### 🔄 **Elements to Update/Migrate**
```gdscript
# EXISTING: CardPicker modal system
# STATUS: Working but not using unified system
# MIGRATION: Convert to inherit from BaseOverlay

# EXISTING: PauseOverlay system  
# STATUS: Autoload-managed, needs integration
# MIGRATION: Update to use OverlayManager instead of direct PauseUI

# EXISTING: Debug panels and overlays
# STATUS: Custom implementations
# MIGRATION: Optionally convert to unified system (lower priority)
```

### Migration Timeline

#### Pre-Implementation Cleanup (Before Phase 1)
- [ ] **Audit existing overlays**: Document all current modal/popup implementations
- [ ] **Identify hardcoded styling**: Find all manual theme overrides to replace
- [ ] **Map dependencies**: Chart which systems use which UI elements
- [ ] **Create migration checklist**: Ensure no functionality is lost during conversion

#### Phase 1 Cleanup Tasks
- [ ] **Remove ResultsScreen scene transition logic**:
  - Remove `StateManager.end_run()` → overlay transition from Player death
  - Remove `"results"` case from `SceneTransitionManager._load_scene_for_state()`
  - Remove `GameOrchestrator._load_scene_for_state(State.RESULTS)`
- [ ] **Clean up unused scene files**:
  - Keep `ResultsScreen.tscn` but convert to overlay structure
  - Remove any ResultsScreen-specific transition code
- [ ] **Update Player death sequence**:
  - Replace `StateManager.end_run()` with `OverlayManager.show_overlay()`
  - Ensure proper context passing to overlay system

## Implementation Plan

### Phase 1: Core Foundation + Cleanup (Week 1)  
**Goal**: Create base overlay system, convert ResultsScreen, clean up old implementations

#### 1.1 Create OverlayManager System
- [ ] `autoload/OverlayManager.gd` - Main overlay coordinator
- [ ] `scripts/ui_framework/BaseOverlay.gd` - Base class for all overlays
- [ ] `themes/overlay_theme.tres` - Base theme resource
- [ ] Basic overlay stack management with proper z-ordering

#### 1.2 Convert ResultsScreen to Overlay
- [ ] Inherit ResultsScreen from BaseOverlay instead of Control
- [ ] Remove scene transition logic from Player death sequence
- [ ] Add ResultsScreen as overlay to Arena scene instead of separate scene
- [ ] Preserve game background with stopped enemies (greyed out)
- [ ] Test: Death shows popup over arena, buttons work for scene transitions

#### 1.3 Animation & Polish Foundation
- [ ] `scripts/ui_framework/OverlayAnimator.gd` - Animation utilities
- [ ] Fade-in/scale-in animations for overlay appearance
- [ ] Background dimming with smooth transition
- [ ] Test: ResultsScreen appears/disappears with smooth animations

### Phase 2: Theme Integration + Style Cleanup (Week 2)
**Goal**: Consistent visual styling across all overlays, eliminate hardcoded styling

#### 2.1 Base Theme System
- [ ] Create comprehensive `OverlayTheme` resource class
- [ ] Define color palette, typography, spacing standards
- [ ] Button/Panel/Label style presets
- [ ] Test: ResultsScreen uses theme instead of hardcoded colors

#### 2.2 Hardcoded Style Cleanup
- [ ] **Audit and replace hardcoded colors**:
  ```gdscript
  # FIND & REPLACE across codebase:
  add_theme_color_override("panel", Color(...))  # → apply_overlay_theme()
  add_theme_font_size_override("font_size", 32)  # → theme.title_font_size
  Color(0.2, 0.2, 0.2, 0.95)  # → theme.background_color
  ```
- [ ] **Create theme migration helper**:
  ```gdscript
  # Helper function to convert old styling
  func migrate_hardcoded_styling(control: Control, theme: OverlayTheme)
  ```
- [ ] **Update existing UI files**:
  - `scenes/ui/ResultsScreen.gd` - Remove manual color overrides
  - `scenes/ui/CardPicker.gd` - Convert to theme system
  - `scenes/ui/HUD.gd` - Update debug overlay styling
  - `scenes/debug/DebugPanel.gd` - Optional theme integration

#### 2.3 Theme Application Framework
- [ ] Theme manager for hot-swapping overlay themes
- [ ] Helper functions for applying themes to controls
- [ ] Inspector-friendly theme configuration
- [ ] Test: Can change overlay appearance by editing theme resource

### Phase 3: Overlay Stack & Legacy Migration (Week 3)
**Goal**: Handle multiple overlays, proper input routing, migrate existing modals

#### 3.1 Advanced Overlay Management
- [ ] Multi-overlay stack with proper Z-ordering
- [ ] Input event routing to active overlay only
- [ ] Escape key handling with configurable behavior per overlay
- [ ] Pause management integration (some overlays pause, others don't)

#### 3.2 Legacy Modal Migration
- [ ] **Migrate CardPicker to BaseOverlay**:
  ```gdscript
  # OLD: scenes/ui/CardPicker.gd extends Control
  # NEW: extends BaseOverlay with OverlayManager integration
  ```
  - Update `Arena.gd _on_level_up()` to use OverlayManager
  - Remove direct pause management (handled by overlay system)
  - Test: Card selection works with new overlay system

- [ ] **Migrate PauseOverlay to unified system**:
  ```gdscript
  # OLD: PauseUI autoload manages scenes/ui/overlays/PauseOverlay.tscn
  # NEW: OverlayManager handles pause overlay like any other overlay
  ```
  - Update `GameOrchestrator._try_toggle_pause()` to use OverlayManager
  - Preserve existing pause behavior and button functionality
  - Test: ESC key toggle works with unified system

#### 3.3 Context-Aware Overlays & Cleanup
- [ ] Context passing system for overlay data
- [ ] Overlay state preservation across game state changes
- [ ] **Memory management and lifecycle cleanup**:
  - Auto-cleanup of overlay instances when not needed
  - Proper signal disconnection on overlay close
  - Memory leak prevention for overlay stack
- [ ] Test: Can open inventory while results screen is showing (if needed)

### Phase 4: Component Library + Final Cleanup (Week 4)
**Goal**: Reusable UI components, eliminate remaining legacy code

#### 4.1 Core Overlay Components
- [ ] `OverlayButton.gd/.tscn` - Themed button with hover/press states
- [ ] `OverlayPanel.gd/.tscn` - Base panel with theme integration
- [ ] `OverlayHeader.gd/.tscn` - Standard overlay title/close button
- [ ] `OverlayFooter.gd/.tscn` - Standard button row layout

#### 4.2 Specialized Components
- [ ] `StatsDisplay.gd/.tscn` - Formatted stats panel (for ResultsScreen)
- [ ] `ButtonRow.gd/.tscn` - Horizontal button layout with spacing
- [ ] `IconButton.gd/.tscn` - Button with icon + text
- [ ] Test: ResultsScreen rebuilt using component library

#### 4.3 Final Legacy Cleanup
- [ ] **Remove obsolete scene transition code**:
  ```gdscript
  # FILES TO UPDATE:
  # - SceneTransitionManager.gd: Remove "results" case
  # - GameOrchestrator.gd: Remove State.RESULTS handling
  # - StateManager.gd: Update end_run() to not trigger scene transition
  ```

- [ ] **Clean up unused files and references**:
  - Remove any unused modal implementation files
  - Clean up imports/references to old modal systems
  - Update documentation to reflect new overlay system

- [ ] **Backward compatibility layer** (optional):
  ```gdscript
  # For gradual migration, create wrapper functions
  # that redirect old modal calls to new overlay system
  func show_modal_legacy(modal_name: String) -> void:
      OverlayManager.show_overlay(convert_legacy_name(modal_name))
  ```

- [ ] **Performance validation**:
  - Memory usage comparison (before/after overlay system)
  - Frame rate impact assessment during overlay transitions
  - Cleanup verification (no memory leaks, proper signal disconnection)

## File Structure

```
autoload/
├── OverlayManager.gd          # Main overlay coordinator

scripts/ui_framework/
├── BaseOverlay.gd             # Base class for all overlays
├── OverlayAnimator.gd         # Animation utilities  
├── OverlayTheme.gd            # Theme resource class
└── components/
    ├── OverlayButton.gd/.tscn
    ├── OverlayPanel.gd/.tscn
    └── OverlayHeader.gd/.tscn

scenes/ui/overlays/
├── ResultsScreen.gd/.tscn     # CONVERTED: Now inherits BaseOverlay
├── InventoryScreen.gd/.tscn   # FUTURE: Inventory overlay
├── CharacterScreen.gd/.tscn   # FUTURE: Character sheet overlay
└── SkillTreeScreen.gd/.tscn   # FUTURE: Skill tree overlay

themes/
├── overlay_theme.tres         # Base overlay theme
├── dark_theme.tres           # Dark mode variant
└── component_styles.tres     # Component-specific styles
```

## First Implementation: ResultsScreen Overlay

### Current Issue Analysis
**Problem**: ResultsScreen currently triggers `StateManager.end_run()` → separate scene transition → no background visible

**Solution**: Show ResultsScreen as overlay on Arena scene → preserve background with stopped enemies → scene transition only on button press

### Implementation Steps

#### Step 1: Modify Player Death Sequence
```gdscript
# In Player.gd _handle_death_sequence()
# OLD: StateManager.end_run(death_result)
# NEW: OverlayManager.show_overlay(OverlayManager.OverlayType.RESULTS_SCREEN, death_result)
```

#### Step 2: Convert ResultsScreen Structure
```gdscript
# ResultsScreen.gd - Convert from Control to BaseOverlay
extends BaseOverlay

@export var overlay_type: OverlayManager.OverlayType = OverlayManager.OverlayType.RESULTS_SCREEN
@export var dims_background: bool = true
@export var pauses_game: bool = false  # Enemies already stopped on death
@export var closeable_with_escape: bool = false  # Force user choice
```

#### Step 3: Arena Integration
- Arena keeps running with stopped enemies in background
- OverlayManager dims the arena with semi-transparent overlay  
- ResultsScreen appears centered over the dimmed arena
- Button presses trigger scene transitions via StateManager

### Success Criteria

#### Visual Requirements
- [ ] ResultsScreen appears as centered popup over arena
- [ ] Arena background remains visible but dimmed (70% dark overlay)
- [ ] Stopped enemies visible behind results popup (greyed out)
- [ ] Smooth fade-in animation when results appear
- [ ] Proper button styling with hover states

#### Functional Requirements  
- [ ] Death triggers overlay display (not scene transition)
- [ ] Buttons work for scene transitions (Restart/Hideout/Menu)
- [ ] Revive button placeholder present and disabled
- [ ] Escape key handling (configurable - disabled for results)
- [ ] No memory leaks or dangling references

#### Integration Requirements
- [ ] Works with existing StateManager scene transitions
- [ ] Compatible with pause system (results don't pause, but game already stopped)
- [ ] EventBus integration maintained
- [ ] Performance: No frame drops during overlay animations

## Future Overlays (Post-V1)

### Planned Overlay Implementations
1. **Inventory Screen** - Item management with drag/drop
2. **Character Screen** - Stats, equipment, progression  
3. **Skill Tree** - Ability upgrades and talent paths
4. **Settings/Options** - Game configuration
5. **Pause Menu** - Game pause with quick actions
6. **Card Selection** - Convert existing CardPicker to new system

### Advanced Features (Future)
- **Multi-overlay support** - Stack multiple overlays (e.g., inventory + tooltip)
- **Responsive layouts** - Adapt to different screen sizes
- **Accessibility** - Keyboard navigation and screen reader support  
- **Sound integration** - Audio feedback for overlay open/close
- **Save/restore state** - Preserve overlay state across sessions

## Dependencies

### Required Before Starting
- [ ] Review existing Modal-Overlay-System.md documentation
- [ ] Understand current CardPicker modal implementation  
- [ ] Analyze ResultsScreen current structure and integration points

### Systems to Integrate With
- **StateManager** - Scene transitions triggered by overlay buttons
- **SessionManager** - Entity cleanup and reset coordination
- **EventBus** - Overlay events and state communication
- **PauseManager** - Pause integration for certain overlays

### Related Tasks
- **[[11-UI_SYSTEM_ARCHITECTURE_ENHANCEMENT]]** - Broader UI framework (complements this)
- **[[Modal-Overlay-System]]** - Current modal analysis and architecture

## Risk Assessment

### High Risk
- **Performance impact** - Overlays running on top of active game scene
- **Input event conflicts** - Ensuring proper input routing between game/overlay
- **Memory management** - Overlay lifecycle and cleanup

### Medium Risk  
- **Theme system complexity** - Getting reusable theming right
- **Animation synchronization** - Smooth overlay transitions
- **Multi-platform compatibility** - Overlay behavior on different devices

### Mitigation Strategies
- **Start simple** - Basic overlay system first, then add features incrementally
- **Performance monitoring** - Track frame rates during overlay operations
- **Extensive testing** - Test overlay system with various game states and scenarios
- **Fallback mechanisms** - Graceful degradation if overlay system fails

## Cleanup Checklist

### 📋 **Files to Remove Completely**
- [ ] None initially - keep all files but remove obsolete code sections

### 📝 **Files to Migrate/Update**

#### Core System Files  
- [ ] `scenes/arena/Player.gd` - Replace `StateManager.end_run()` with overlay call
- [ ] `autoload/StateManager.gd` - Update `end_run()` to not trigger scene transition  
- [ ] `autoload/GameOrchestrator.gd` - Remove `State.RESULTS` scene loading logic
- [ ] `scripts/systems/SceneTransitionManager.gd` - Remove "results" case mapping

#### UI Files to Migrate
- [ ] `scenes/ui/ResultsScreen.gd/.tscn` - Convert from Control to BaseOverlay
- [ ] `scenes/ui/CardPicker.gd/.tscn` - Migrate to BaseOverlay system
- [ ] `scenes/ui/overlays/PauseOverlay.gd/.tscn` - Integrate with OverlayManager
- [ ] `scenes/ui/HUD.gd` - Remove hardcoded overlay styling

#### Debug/Optional Files
- [ ] `scenes/debug/DebugPanel.gd` - Optional theme integration
- [ ] Various UI files - Replace hardcoded `add_theme_*_override()` calls

### 🧹 **Code Patterns to Clean Up**

#### Hardcoded Styling (Global Find & Replace)
```gdscript
# FIND THESE PATTERNS:
add_theme_color_override("panel", Color(0.2, 0.2, 0.2, 0.95))
add_theme_font_size_override("font_size", 32)
add_theme_color_override("font_color", Color.WHITE)
modulate = Color(1.0, 0.4, 0.4)  # Manual color changes

# REPLACE WITH:
apply_overlay_theme(overlay_theme)
# OR: theme.panel_color, theme.title_font_size, etc.
```

#### Manual Pause Management  
```gdscript
# FIND:
PauseManager.pause_game(true)   # In modal open
PauseManager.pause_game(false)  # In modal close

# REPLACE WITH:
# Handled automatically by OverlayManager based on overlay.pauses_game property
```

#### Direct Scene References
```gdscript
# FIND:
get_tree().change_scene_to_file("res://scenes/ui/ResultsScreen.tscn")

# REPLACE WITH:
OverlayManager.show_overlay(OverlayManager.OverlayType.RESULTS_SCREEN, context)
```

### ✅ **Cleanup Validation Tests**

#### Memory & Performance
- [ ] **Memory leak test**: Open/close overlay 100 times, check memory usage
- [ ] **Signal cleanup test**: Verify all signals properly disconnected on overlay close
- [ ] **Frame rate test**: Ensure no performance degradation during overlay transitions
- [ ] **Stack overflow test**: Test multiple overlay stacking scenarios

#### Functionality Preservation  
- [ ] **Death results test**: Player death shows overlay over arena background
- [ ] **Card selection test**: Level up card selection works with new system
- [ ] **Pause menu test**: ESC key pause functionality preserved
- [ ] **Button actions test**: All overlay buttons trigger correct scene transitions

#### Integration Tests
- [ ] **StateManager integration**: Scene transitions still work from overlay buttons
- [ ] **EventBus integration**: Overlay events properly trigger game systems
- [ ] **Theme consistency**: All overlays use consistent visual styling
- [ ] **Input handling**: Proper input routing between game and overlay

## Migration Safety Measures

### 🔒 **Backward Compatibility During Migration**
```gdscript
# Create temporary wrapper to avoid breaking existing code
class_name LegacyModalSupport

static func show_results_screen(data: Dictionary) -> void:
    # OLD APPROACH (temporary fallback)
    if not OverlayManager:
        StateManager.end_run(data)  # Fallback to old system
        return
    
    # NEW APPROACH  
    OverlayManager.show_overlay(OverlayManager.OverlayType.RESULTS_SCREEN, data)
```

### 🔄 **Gradual Migration Strategy**
1. **Phase 1**: Implement base system + ResultsScreen (validate core functionality)
2. **Phase 2**: Add theme system (visual consistency)
3. **Phase 3**: Migrate CardPicker and PauseOverlay (prove system scalability) 
4. **Phase 4**: Complete cleanup and component library (production ready)

### 📊 **Success Metrics**
- [ ] **Code reduction**: 50% reduction in modal-related code duplication
- [ ] **Consistency**: All overlays use unified theme system
- [ ] **Performance**: No frame rate impact during overlay operations
- [ ] **Maintainability**: New overlays can be created in <1 hour using components

This unified overlay system will provide a solid foundation for all modal UIs in the game while ensuring consistent user experience, maintainable code architecture, and proper cleanup of legacy implementations.