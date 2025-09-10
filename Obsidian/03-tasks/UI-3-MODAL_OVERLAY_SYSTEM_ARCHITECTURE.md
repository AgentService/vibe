# Modal/Overlay System Architecture

**Status**: 📋 **Planning**  
**Priority**: High  
**Type**: UI Framework Core  
**Created**: 2025-09-10  
**Context**: Implement production-ready modal/overlay system for inventory, character screen, death screen, result screen, and other game overlays

## Overview

Create a robust, performant modal/overlay system using CanvasLayer architecture with centralized theme management. This system will handle all in-game overlays while maintaining separation from HUD elements and full-screen scenes.

## Research-Based Architecture Decisions

### Canvas Layer Strategy (Based on 2025 Best Practices)
```
Layer 0: Game World UI (enemy health bars)
Layer 1: Primary HUD (health, radar, abilities)  
Layer 5: Game Modals (inventory, character screen)
Layer 10: System Modals (pause, death screen, result screen)
Layer 50: Full Screen Overlays (main menu)
Layer 100: Debug/Development tools
```

### Performance Requirements
- Object pooling for frequently created/destroyed modals
- Background dimmer with interaction blocking
- Process mode management (PROCESS_MODE_ALWAYS for pause menus)
- Memory-efficient modal stacking system

## Implementation Plan

### Phase 1: Core Modal Framework
**Timeline**: Week 1-2

#### Modal Manager Autoload
- [ ] Create `UIManager` autoload singleton for modal coordination
- [ ] Implement modal stack management (Array[Control])
- [ ] Add modal state tracking and navigation history
- [ ] Create modal factory pattern for dynamic instantiation

```gdscript
# UIManager.gd - Autoload
extends Node

var modal_stack: Array[Control] = []
var background_dimmer: ColorRect = null
var modal_layer: CanvasLayer = null

func show_modal(modal_scene: PackedScene, data: Dictionary = {}) -> Control
func hide_current_modal() -> void
func hide_all_modals() -> void
func get_current_modal() -> Control
```

#### Base Modal Component
- [ ] Create `BaseModal.gd/.tscn` - foundation for all modals
- [ ] Implement backdrop click-to-close functionality
- [ ] Add ESC key handling with proper priority
- [ ] Include fade-in/fade-out animations using UIAnimator

#### Background Dimmer System
- [ ] Create reusable background dimmer (semi-transparent overlay)
- [ ] Implement click-through protection
- [ ] Add dimmer animation (fade in/out)
- [ ] Handle multiple modal layering

### Phase 2: Game-Specific Modals
**Timeline**: Week 3-4

#### Core Game Modals
- [ ] **InventoryModal.gd/.tscn** - Item management interface
  - Grid-based item display with drag-and-drop
  - Category filtering and search functionality
  - Item tooltips and detailed information panels
  
- [ ] **CharacterModal.gd/.tscn** - Character stats and equipment
  - Equipment slot visualization
  - Stat display with real-time calculations
  - Skill tree integration
  
- [ ] **DeathModal.gd/.tscn** - Death screen with run statistics
  - Run summary and statistics display
  - Restart/return to hideout options
  - Death reason and final wave information
  
- [ ] **ResultsModal.gd/.tscn** - Victory/completion screen
  - Experience gained and level progression
  - Loot summary and rewards
  - Performance metrics (time, damage dealt, etc.)

#### Modal Communication System
- [ ] Extend EventBus with modal-specific signals
- [ ] Create data binding system for modal content
- [ ] Implement modal-to-modal communication patterns

### Phase 3: Advanced Features
**Timeline**: Week 5-6

#### Keyboard Navigation
- [ ] Focus management system for modal navigation
- [ ] Tab order configuration for accessibility
- [ ] ESC key priority handling (close current modal vs pause game)
- [ ] Hotkey system for quick modal access (I for inventory, C for character)

#### Animation System Integration
- [ ] Integrate with UIAnimator for standardized transitions
- [ ] Create modal-specific animation presets:
  - `modal_slide_up()` - Slide in from bottom
  - `modal_fade_scale()` - Fade + scale animation
  - `modal_push()` - Push previous modal back slightly
- [ ] Performance-optimized animation batching

#### Responsive Design
- [ ] Implement responsive modal sizing for different screen resolutions
- [ ] Create breakpoint system (mobile, tablet, desktop)
- [ ] Add automatic content scrolling for small screens
- [ ] Test on various aspect ratios (16:9, 21:9, 4:3)

### Phase 4: Integration & Testing
**Timeline**: Week 7

#### System Integration
- [ ] Connect modals to existing game systems:
  - Inventory system integration
  - Character progression system
  - Death/restart flow
  - Results/reward systems
- [ ] Update existing HUD to trigger modal opening
- [ ] Ensure proper separation from full-screen scenes

#### Testing & Optimization
- [ ] Performance testing with multiple open modals
- [ ] Memory leak testing (modal creation/destruction cycles)
- [ ] Input handling edge case testing
- [ ] Animation performance optimization

## Technical Architecture

### File Structure
```
scenes/ui/
├── modals/
│   ├── base/
│   │   ├── BaseModal.gd/.tscn       # Foundation modal class
│   │   ├── ModalBackground.gd/.tscn  # Reusable backdrop
│   │   └── ModalContainer.gd        # Content container
│   ├── game/
│   │   ├── InventoryModal.gd/.tscn
│   │   ├── CharacterModal.gd/.tscn
│   │   ├── DeathModal.gd/.tscn
│   │   └── ResultsModal.gd/.tscn
│   └── system/
│       ├── PauseModal.gd/.tscn
│       └── SettingsModal.gd/.tscn

autoload/
├── UIManager.gd                     # Modal management singleton

scripts/systems/
├── ui_framework/
│   ├── ModalFactory.gd              # Dynamic modal creation
│   ├── ModalState.gd                # Modal state management
│   └── KeyboardNavigation.gd        # Focus and navigation
```

### EventBus Extensions
```gdscript
# New modal-specific signals
signal modal_requested(modal_type: String, data: Dictionary)
signal modal_opened(modal: Control)
signal modal_closed(modal: Control)
signal modal_stack_changed(stack_size: int)

# Data synchronization signals
signal inventory_data_changed(items: Array)
signal character_stats_changed(stats: Dictionary)
signal death_data_available(death_info: Dictionary)
```

## Performance Considerations

### Memory Management
- **Modal Pooling**: Cache frequently used modals (inventory, character)
- **Resource Cleanup**: Proper disposal of modal content when closed
- **Texture Management**: Use texture atlases for modal UI elements

### Animation Performance
- **Animation Budget**: Maximum 3 simultaneous modal animations
- **GPU Optimization**: Use CanvasLayer instead of multiple viewports
- **Tween Pooling**: Reuse Tween instances to reduce allocation

### Input Handling Optimization
- **Event Propagation**: Proper input event consumption to prevent conflicts
- **Focus Management**: Efficient focus traversal without excessive processing
- **Input Buffering**: Queue input during modal transitions

## Success Criteria

### Functional Requirements
- [ ] All game modals (inventory, character, death, results) implemented
- [ ] Smooth animations with 60+ FPS performance
- [ ] Proper modal stacking with intuitive navigation
- [ ] Keyboard accessibility with full navigation support

### Performance Requirements
- [ ] Modal open/close < 100ms response time
- [ ] Memory usage stable during modal cycling (no leaks)
- [ ] No frame drops during modal animations
- [ ] Support for 5+ simultaneous modals without performance impact

### User Experience Requirements
- [ ] Consistent visual design using centralized theme system
- [ ] Intuitive keyboard shortcuts (ESC, I, C, etc.)
- [ ] Responsive design working on 1080p, 1440p, and 4K displays
- [ ] Smooth transitions that enhance rather than interrupt gameplay

## Dependencies

### Required Systems
- **UIManager** (new autoload)
- **Theme System** (from task 11-UI_SYSTEM_ARCHITECTURE_ENHANCEMENT)
- **UIAnimator** (animation framework)
- **EventBus** (signal extensions)

### Integration Points
- **InventorySystem** - data synchronization
- **CharacterManager** - stats and progression data
- **GameStateManager** - death/restart flows
- **InputManager** - keyboard navigation

## Risk Mitigation

### High Risk: Performance Impact
- **Mitigation**: Implement modal pooling and strict animation budget
- **Testing**: Continuous performance monitoring during development

### Medium Risk: Complex Modal Stacking
- **Mitigation**: Clear modal hierarchy rules and comprehensive testing
- **Testing**: Edge case testing with rapid modal opening/closing

### Medium Risk: Input Conflicts
- **Mitigation**: Proper input event consumption and priority system
- **Testing**: Input stress testing with multiple simultaneous inputs

This modal system will provide the foundation for all in-game overlays while maintaining optimal performance and user experience.