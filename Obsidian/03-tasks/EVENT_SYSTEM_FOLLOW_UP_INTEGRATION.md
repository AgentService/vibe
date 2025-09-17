# Event System Follow-Up - Integration & Polish

**Status:** Ready for Implementation
**Priority:** High
**Estimated Time:** 8-12 hours (EXPANDED SCOPE)
**Created:** 2025-01-16
**Updated:** 2025-01-16 (Expanded with interactive event mechanics)
**Depends On:** Event System Core Implementation (COMPLETED)

## Context

The Event System core implementation is complete and successfully tested. All backend systems are functional:
- ✅ EventMasterySystem loading without errors
- ✅ Event definitions (.tres files) loading properly
- ✅ SpawnDirector integration working
- ✅ Signal architecture in place
- ✅ Resource-driven configuration functional

## Missing Components for Full Integration

### Critical - Scene & UI Integration
1. **MasteryTreeUI Scene File**: The script exists but needs actual .tscn scene with node hierarchy ⏳ IN PROGRESS
2. **Input Integration**: Connect mastery tree to game's input/menu system
3. **UI Accessibility**: Add hotkey or menu button to open mastery tree

### EXPANDED: Interactive Event Mechanics
1. **Scene-Based Event Markers**: Visual indicators on map showing active event locations
2. **Event Objective Entities**: Interactive objectives for each event type (defend, survive, collect)
3. **Breach Event Mechanics**: Portal defense with wave spawning and duration objectives
4. **Ritual Event Mechanics**: Circle defense with channeling mechanics and area protection
5. **Pack Hunt Mechanics**: Elite tracking system with rare spawn coordination
6. **Boss Event Mechanics**: Multi-phase encounters with elite guard spawning

### Important - Gameplay Testing
1. **Event Spawn Verification**: Confirm events actually spawn in gameplay
2. **Mastery Point Earning**: Verify points are awarded on event completion
3. **Passive Effect Testing**: Confirm allocated passives modify event behavior
4. **Performance Validation**: Ensure no regression in spawn performance
5. **Interactive Mechanics Testing**: Verify all event objectives work correctly

### Balance & Polish
1. **Event Frequency Tuning**: Adjust spawn intervals for good gameplay flow
2. **Reward Balancing**: Tune XP multipliers and mastery point costs
3. **Visual Feedback**: Add event start/completion notifications
4. **Player Communication**: Clear feedback when earning points/allocating passives
5. **Event Marker Polish**: Smooth animations and clear visual states

## Implementation Plan

### Phase 1: MasteryTreeUI Scene Creation ✅ COMPLETED

**Goal:** Create functional MasteryTreeUI scene that integrates with existing UI systems.

#### 1.1 Scene Structure Design - IMPLEMENTED
```
SkillTreeUI (Control) [1080x720 canvas, script: SkillTreeUI.gd]
├── Background (ColorRect) - Dark theme background
├── TreeContainer (Control) - Main layout container
│   ├── BreachTreeSection (Control) [540x360 - Top Left]
│   │   ├── NodeContainer (Control) - Organized node positioning
│   │   │   ├── BreachNode1, BreachNode2, BreachNode3 (SkillTreeNode instances)
│   │   ├── SectionLabel - "BREACH"
│   │   └── PointCounter - "0/0" format
│   ├── RitualTreeSection (Control) [540x360 - Top Right]
│   │   ├── NodeContainer (Control)
│   │   │   ├── RitualNode1, RitualNode2 (SkillTreeNode instances)
│   │   ├── SectionLabel - "RITUAL"
│   │   └── PointCounter - "0/0" format
│   ├── PackTreeSection (Control) [540x360 - Bottom Left]
│   │   ├── NodeContainer (Control)
│   │   │   ├── PackNode1 (SkillTreeNode instance)
│   │   ├── SectionLabel - "PACK HUNT"
│   │   └── PointCounter - "0/0" format
│   └── BossTreeSection (Control) [540x360 - Bottom Right]
│       ├── NodeContainer (Control)
│       │   ├── BossNode1 (SkillTreeNode instance)
│       ├── SectionLabel - "BOSS"
│       └── BossPointCounter - "0/0" format
├── UIPanel (Panel) - Close button container
└── TooltipContainer (Control) - Hover tooltip system
```

**Key Implementation Features:**
- ✅ 1080x720 optimal canvas size for UI overlay
- ✅ Perfect 2x2 quadrant layout (540x360 each)
- ✅ SkillTreeNode component architecture with visual states
- ✅ NodeContainer organization for easy positioning
- ✅ Connection point indicators (8x8 ColorRect, event-typed colors)
- ✅ Hover state management with proper restoration
- ✅ Camera-independent CanvasLayer rendering
- ✅ Event-type color coding (Breach=Purple, etc.)
- ✅ Scene-based design visible in Godot editor

#### 1.2 Theme Integration
- **Use existing theme**: Apply `res://data/themes/card_selection_theme.tres`
- **Button styling**: Follow existing UI button patterns
- **Color coding**: Different colors per event type (Breach=Purple, Ritual=Green, etc.)
- **Responsive layout**: Handle different screen sizes

#### 1.3 Node Path Verification
- **Match script expectations**: Ensure @onready paths in MasteryTreeUI.gd match scene structure
- **Button connections**: Verify all passive buttons can be found by script
- **Label references**: Confirm points labels are correctly referenced

### Phase 2: UI Integration & Input (45 minutes)

**Goal:** Make mastery tree accessible from gameplay.

#### 2.1 Input Mapping
```gdscript
# Add to project.godot input map
mastery_tree_toggle={
"deadzone": 0.5,
"events": [Object(InputEventKey,"keycode":4194328,"physical_keycode":4194328)]  # F9 key
}
```

#### 2.2 HUD Integration Options
**Option A: Add to Pause Menu**
- Add "Mastery Tree" button to existing pause menu
- Opens MasteryTreeUI as modal overlay

**Option B: Direct Hotkey Access**
- F9 key toggles mastery tree during gameplay
- Can be opened/closed anytime (even during combat)

**Option C: Both**
- F9 hotkey + pause menu button for discoverability

#### 2.3 Modal Behavior
- **Pause game**: Mastery tree should pause gameplay when open
- **Input capture**: ESC key closes mastery tree
- **Z-index**: Ensure mastery tree appears above all other UI

### Phase 3: Integration Testing & Validation (1 hour)

**Goal:** Verify complete event system functionality in actual gameplay.

#### 3.1 Event Spawn Testing
```bash
# Test event spawning in arena
"./Godot_v4.4.1-stable_win64_console.exe" scenes/arena/UnderworldArena.tscn
```

**Test Checklist:**
- [ ] Events spawn every 45-60 seconds
- [ ] Events use different spawn zones
- [ ] Zone cooldowns prevent spam spawning
- [ ] Events respect player proximity ranges
- [ ] Different event types spawn (Breach, Ritual, Pack Hunt, Boss)

#### 3.2 Mastery Point Testing
**Test Scenarios:**
- [ ] Kill enemies in event zones → mastery points awarded
- [ ] Points shown correctly in UI for each event type
- [ ] Points persist between sessions (saved to user://mastery_tree.tres)
- [ ] Point earning logged properly in console

#### 3.3 Passive Effect Testing
**Passive Modifier Verification:**
- [ ] Breach Density I: 25% more monsters in breach events
- [ ] Breach Duration I: +5 seconds duration
- [ ] Ritual Area I: 50% larger ritual circles
- [ ] Pack Density I: +1 rare companion in pack hunts
- [ ] Allocation/deallocation works correctly
- [ ] Button states update (Green=allocated, White=available, Gray=locked)

#### 3.4 Performance Testing
- [ ] No FPS drop when events spawn
- [ ] Memory usage remains stable
- [ ] No increase in entity update overhead
- [ ] Zone management performance unchanged

### Phase 4: Balance & Polish (1 hour)

**Goal:** Tune event system for optimal gameplay experience.

#### 4.1 Event Frequency Balancing
**Current Settings (may need adjustment):**
- Event spawn interval: 45 seconds (too fast/slow?)
- Zone cooldown: 15 seconds (adequate?)
- Event duration: 20-45 seconds depending on type

**Testing Questions:**
- Do events feel appropriately spaced?
- Is there enough variety in event types?
- Do events interfere with normal gameplay flow?

#### 4.2 Passive Cost Balancing
**Current Costs (may need adjustment):**
- Low-impact passives: 2-3 points
- Medium-impact passives: 4-5 points
- High-impact passives: 6+ points

**Balancing Goals:**
- First passive unlocked after 2-3 events
- Meaningful choices (can't unlock everything quickly)
- Clear progression curve

#### 4.3 Visual & Audio Feedback
**Event Start Feedback:**
- Visual indicator when event spawns (screen flash, UI notification)
- Audio cue for event start
- Zone highlighting or visual effect

**Mastery Point Feedback:**
- Floating text when points earned
- UI notification in mastery tree
- Audio feedback for point earning

**Passive Allocation Feedback:**
- Confirmation sound when passive allocated
- Visual feedback showing effect applied
- Clear indication of what changed

### Phase 5: Event-Specific Skill Tree Expansion (PLANNED)

**Goal:** Develop individualized skill trees for each event type with custom layouts and connection logic.

#### 5.1 Individual Tree Architecture Planning
**Current Foundation:** The base SkillTreeNode component and NodeContainer system provide excellent scaffolding for event-specific customization.

**Planned Event-Specific Trees:**

**Breach Trees - Portal Mastery Focus:**
- Linear progression: Portal Defense → Portal Enhancement → Portal Mastery
- Connection logic: Vertical tree with branching specializations
- Unique passives: Portal health, breach duration, monster density, portal rewards

**Ritual Trees - Circle Mastery Focus:**
- Circular/radial layout: Center ritual improvements radiating outward
- Connection logic: Hub-and-spoke pattern from central ritual node
- Unique passives: Circle area, ritual speed, protection strength, channeling bonuses

**Pack Hunt Trees - Tracking Mastery Focus:**
- Horizontal web layout: Interconnected tracking and coordination nodes
- Connection logic: Multiple paths with cross-connections between specializations
- Unique passives: Elite tracking, pack coordination, rare spawn chances, hunt rewards

**Boss Trees - Combat Mastery Focus:**
- Hierarchical pyramid: Foundation combat → Advanced tactics → Boss specialization
- Connection logic: Prerequisite-based vertical progression with lateral specializations
- Unique passives: Boss damage, phase management, elite guard bonuses, encounter rewards

#### 5.2 Technical Implementation Strategy
**Base Component Reuse:**
- ✅ SkillTreeNode.tscn serves as universal building block
- ✅ NodeContainer system enables flexible positioning per event type
- ✅ Connection point system supports custom line drawing between nodes
- ✅ Event-type color coding already implemented

**Custom Tree Layouts:**
- Each event type gets specialized node positioning within its NodeContainer
- Custom connection line drawing logic per event type (straight, curved, radial)
- Event-specific passive definitions with unique mechanical effects
- Tailored progression paths reflecting each event type's gameplay identity

**Future Development Path:**
1. Design individual tree layouts for each event type
2. Implement custom connection line rendering per tree style
3. Expand passive definitions with event-specific mechanics
4. Add tree-specific animations and visual effects
5. Create event-themed skill tree backgrounds and styling

### Phase 6: Future Architecture Planning (30 minutes)

**Goal:** Document technical debt and future improvements.

#### 5.1 SpawnDirector Refactoring Assessment
**Current Status:**
- SpawnDirector: ~1600 lines (approaching complexity limit)
- Event logic: ~300 lines added to SpawnDirector
- Maintainability: Still manageable but approaching refactor threshold

**Refactoring Trigger Points:**
- File exceeds 1800 lines
- Additional spawn systems needed (sieges, raids, etc.)
- Performance issues in spawn coordination
- Team development conflicts

#### 5.2 System Expansion Planning
**Potential Future Event Types:**
- **Siege Events**: Large-scale defensive scenarios
- **Raid Events**: Multi-phase boss encounters
- **Environmental Events**: Weather/terrain-based challenges
- **Player-Triggered Events**: Events activated by player actions

**Architecture Extensions:**
- Event chaining (events that trigger other events)
- Cross-event bonuses (complete different event types for rewards)
- Event-specific loot tables
- Seasonal/timed events

## Implementation Checklist

### Phase 1 - Scene Creation: ✅ COMPLETED
- [x] Create SkillTreeUI.tscn with proper node hierarchy (1080x720, 2x2 quadrants)
- [x] Apply theme styling to all UI elements (dark background, event colors)
- [x] Verify @onready node paths match script expectations
- [x] Test scene loading without errors
- [x] Add color coding for different event types (Breach=Purple, etc.)
- [x] Implement SkillTreeNode component architecture with visual states
- [x] Add NodeContainer organization for flexible positioning
- [x] Create visible connection point indicators
- [x] Fix hover state management with proper restoration
- [x] Ensure camera-independent rendering via CanvasLayer

### Phase 2 - Input Integration:
- [ ] Add mastery_tree_toggle input action to project
- [ ] Choose integration approach (hotkey/menu/both)
- [ ] Implement modal behavior with game pause
- [ ] Add ESC key handling for closing UI
- [ ] Test accessibility from gameplay

### Phase 3 - Integration Testing:
- [ ] Verify events spawn in actual gameplay
- [ ] Confirm mastery points are earned and saved
- [ ] Test all passive effects modify event behavior
- [ ] Validate no performance regression
- [ ] Test UI state synchronization

### Phase 4 - Balance & Polish:
- [ ] Tune event spawn frequencies based on gameplay feel
- [ ] Adjust passive costs for good progression curve
- [ ] Add visual feedback for event start/completion
- [ ] Implement mastery point earning notifications
- [ ] Add passive allocation confirmation feedback

### Phase 5 - Documentation:
- [ ] Update CHANGELOG.md with integration completion
- [ ] Document balance parameters for future tuning
- [ ] Note any technical debt or future improvements needed
- [ ] Create player-facing documentation if needed

### Phase 6 - Scene-Based Event Markers (2 hours):
- [ ] Create EventMarker.tscn scene with visual states (spawning, active, completing)
- [ ] Implement EventMarker.gd script with animation and state management
- [ ] Design marker visuals per event type (Breach=Purple pulse, Ritual=Green circle, etc.)
- [ ] Add markers to SpawnDirector event spawning logic
- [ ] Test marker placement and visibility during gameplay

### Phase 7 - Event Objective Entities (3 hours):
- [ ] Create BaseEventObjective.gd abstract class for event mechanics
- [ ] Implement BreachPortal.tscn (defend portal, wave spawning mechanics)
- [ ] Implement RitualCircle.tscn (channeling protection, area defense)
- [ ] Implement PackHuntTracker.tscn (elite coordination, rare spawn logic)
- [ ] Implement BossEncounter.tscn (phase management, elite guard spawning)
- [ ] Add objective completion signals to EventBus

### Phase 8 - Interactive Event Mechanics (4 hours):
- [ ] Breach mechanics: Portal health, wave defense, duration objectives
- [ ] Ritual mechanics: Circle protection, channeling interruption, area control
- [ ] Pack Hunt mechanics: Elite tracking, rare companion coordination
- [ ] Boss mechanics: Phase transitions, elite guard management, special attacks
- [ ] Event objective completion logic and mastery point awarding
- [ ] Visual feedback for objective progress (health bars, timers, completion effects)

### Phase 9 - Integration & Polish (1 hour):
- [ ] Connect event objectives to SpawnDirector event spawning
- [ ] Test complete event lifecycle (spawn → objectives → completion → rewards)
- [ ] Polish marker animations and objective visual feedback
- [ ] Verify mastery passive effects apply to new mechanics
- [ ] Performance testing with multiple simultaneous events

## Success Criteria

### Functional Requirements:
- [ ] MasteryTreeUI opens/closes properly from gameplay
- [ ] Events spawn, award points, and complete correctly
- [ ] Passive allocation affects event behavior visibly
- [ ] All UI states update correctly in real-time
- [ ] System performs without regression
- [ ] Event markers appear and update correctly during gameplay
- [ ] Event objectives spawn and function properly for all event types
- [ ] Interactive mechanics respond to player actions appropriately

### User Experience Requirements:
- [ ] Clear progression feedback (points earned, effects applied)
- [ ] Intuitive UI navigation and passive allocation
- [ ] Appropriate challenge/reward balance
- [ ] Events feel integrated with core gameplay
- [ ] System enhances rather than disrupts gameplay flow
- [ ] Event markers provide clear visual guidance to active events
- [ ] Event objectives are clearly communicated and achievable
- [ ] Interactive mechanics create engaging mini-challenges within combat

### Technical Requirements:
- [ ] No compilation errors or runtime crashes
- [ ] Proper resource loading and saving
- [ ] Signal-based architecture maintained
- [ ] Performance targets met
- [ ] Code follows project conventions

## Related Files

**Core Implementation (COMPLETED):**
- `scripts/resources/EventMasteryTree.gd`
- `scripts/resources/EventDefinition.gd`
- `scripts/systems/EventMasterySystem.gd`
- `scripts/ui/MasteryTreeUI.gd`
- `data/content/events/*.tres`

**To Be Created:**
- `scenes/ui/MasteryTreeUI.tscn` - Main UI scene ⏳ IN PROGRESS
- Input action in `project.godot`
- Integration with pause menu or HUD
- `scenes/events/EventMarker.tscn` - Visual event indicators
- `scripts/events/EventMarker.gd` - Marker behavior and animation
- `scripts/events/BaseEventObjective.gd` - Abstract base for event mechanics
- `scenes/events/objectives/BreachPortal.tscn` - Breach event portal defense
- `scenes/events/objectives/RitualCircle.tscn` - Ritual circle protection
- `scenes/events/objectives/PackHuntTracker.tscn` - Pack hunt coordination
- `scenes/events/objectives/BossEncounter.tscn` - Boss phase management

**To Be Modified:**
- Arena scenes for UI integration
- Input handling systems
- Possibly HUD/menu systems for accessibility

## Notes

**Architecture Decision:** The current approach of building events into SpawnDirector is appropriate for the MVP. The refactoring extraction documented in `SPAWN_DIRECTOR_REFACTORING_EVENT_EXTRACTION.md` should be implemented when the system grows beyond current complexity.

**Balance Philosophy:** Events should enhance gameplay variety without disrupting core combat flow. They should feel like meaningful bonuses rather than required optimization.

**Performance Priority:** Event system should maintain the game's 30Hz fixed-step deterministic performance. Any framerate impact is unacceptable.

**Player Agency:** Mastery system should provide meaningful choices rather than obvious optimal paths. Different passive builds should support different playstyles.