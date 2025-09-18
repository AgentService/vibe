# Event System Follow-Up - Atlas Tree Integration

**Status:** Ready for Implementation
**Priority:** High
**Estimated Time:** 5-6 hours (REVISED SCOPE - Atlas Focus)
**Created:** 2025-01-16
**Updated:** 2025-01-18 (Redesigned as PoE-style atlas tree system)
**Depends On:** Event System Core Implementation (COMPLETED), Breach Skill Tree POC (COMPLETED)

## Context & New Direction

The Event System backend is complete and the breach skill tree POC provides an excellent foundation. **New approach**: Create a unified **atlas-style skill tree system** (like Path of Exile) that integrates all event types into a cohesive progression experience.

**Current Assets:**
- ✅ EventMasterySystem with 16 passives across 4 event types
- ✅ Working breach skill tree at `res://scenes/ui/skill_tree/skill_tree.tscn`
- ✅ Reusable SkillNode components with visual states and prerequisite logic
- ✅ Event definitions and SpawnDirector integration

**Architecture Decision:** Convert the complex MasteryTreeUI approach into a unified atlas tree that reuses the proven breach tree components.

## Atlas Tree Design

### **Tabbed Interface Approach** (MVP)
```
[Breach] [Ritual] [Pack Hunt] [Boss]
+--------------------------------+
|     Current Tree Display       |
|                               |
|    ○──○──○                    |
|    │     │                    |
|    ○     ○──○                 |
+--------------------------------+
[Points: Breach 5/12] [Reset All]
```

**Benefits:**
- **Reuses existing breach tree** as foundation
- **Clear separation** between event types
- **Familiar tabbed UX** for players
- **Scalable** - easy to add new event types

### **Component Architecture**
```gdscript
AtlasTreeUI (Control)
├── TabContainer
│   ├── BreachTree (EventSkillTree) - Existing tree converted
│   ├── RitualTree (EventSkillTree) - New circular layout
│   ├── PackHuntTree (EventSkillTree) - New web layout
│   └── BossTree (EventSkillTree) - New hierarchical layout
├── PointsPanel - Unified point display per event type
└── EventMasterySystem integration
```

## Implementation Plan

### Phase 1: Component Extraction (1 hour)
**Goal:** Convert existing breach tree into reusable EventSkillTree component

#### 1.1 EventSkillTree Component Creation
- [ ] Extract `skill_tree.tscn` into generic `EventSkillTree.tscn` component
- [ ] Create `EventSkillTree.gd` script with data-driven initialization
- [ ] Add skill definition loading from `.tres` resources
- [ ] Preserve existing SkillNode architecture and visual feedback

#### 1.2 Breach Tree Data Extraction
- [ ] Create `breach_skills.tres` definition file
- [ ] Define skill IDs, names, descriptions, prerequisites
- [ ] Map existing breach tree layout to data structure
- [ ] Test data-driven breach tree loads correctly

### Phase 2: Atlas Container Creation (1.5 hours)
**Goal:** Create unified atlas interface with tabbed navigation

#### 2.1 AtlasTreeUI Scene Structure
- [ ] Create `AtlasTreeUI.tscn` with TabContainer layout
- [ ] Add tabs for each event type (Breach, Ritual, Pack Hunt, Boss)
- [ ] Implement unified points display per event type
- [ ] Add global and per-tree reset functionality

#### 2.2 Navigation & Input Integration
- [ ] Add F9 hotkey for atlas access
- [ ] Implement modal behavior (pause game, ESC to close)
- [ ] Connect tab switching with proper tree loading
- [ ] Test accessibility from gameplay

### Phase 3: Event Tree Expansion (2 hours)
**Goal:** Create specialized skill trees for each event type

#### 3.1 Skill Definition Creation
- [ ] Create `ritual_skills.tres` - circular/radial layout focus
- [ ] Create `pack_hunt_skills.tres` - web/interconnected layout
- [ ] Create `boss_skills.tres` - hierarchical/pyramid layout
- [ ] Define unique skill progression paths per event type

#### 3.2 Visual Specialization
- [ ] Implement event-specific connection line patterns
- [ ] Add event-themed visual styling (colors, backgrounds)
- [ ] Create unique node layouts reflecting event mechanics
- [ ] Test all trees load and display correctly

### Phase 4: Backend Integration (1 hour)
**Goal:** Connect AtlasTreeUI to existing EventMasterySystem

#### 4.1 System Connection
- [ ] Connect AtlasTreeUI to EventMasterySystem for point management
- [ ] Sync skill allocation between UI and backend
- [ ] Implement save/load state across all trees
- [ ] Connect to EventBus for real-time updates

#### 4.2 Gameplay Integration Testing
- [ ] Test complete flow: spawn events → earn points → allocate skills
- [ ] Verify passive effects modify event behavior across all types
- [ ] Test point persistence between sessions
- [ ] Validate no performance regression

### Phase 5: Polish & Balance (30 minutes)
**Goal:** Final polish and balance adjustments

#### 5.1 Visual Feedback
- [ ] Add point earning notifications
- [ ] Implement skill allocation confirmation feedback
- [ ] Polish tab transitions and tree animations
- [ ] Add tooltip system for skill descriptions

#### 5.2 Balance Validation
- [ ] Test skill costs feel appropriate for progression curve
- [ ] Verify meaningful choices exist within each tree
- [ ] Ensure trees complement each other without overlap
- [ ] Document any balance adjustments needed

## Success Criteria

### Functional Requirements:
- [ ] AtlasTreeUI opens/closes properly with F9 hotkey
- [ ] All event type trees (Breach, Ritual, Pack Hunt, Boss) load correctly
- [ ] Events spawn, award points, and complete correctly in gameplay
- [ ] Skill allocation affects event behavior visibly through passives
- [ ] Point earning and spending syncs between UI and EventMasterySystem
- [ ] Save/load state persists across game sessions

### User Experience Requirements:
- [ ] Clear progression feedback (points earned, skills allocated)
- [ ] Intuitive tabbed navigation between event trees
- [ ] Appropriate challenge/reward balance across all trees
- [ ] Visual feedback confirms skill allocation and point spending
- [ ] Each event tree feels unique and specialized

### Technical Requirements:
- [ ] No compilation errors or runtime crashes
- [ ] Proper resource loading for all skill definitions
- [ ] Signal-based architecture maintained
- [ ] Performance targets met (no regression)
- [ ] Code follows project conventions

## Future Expansion Options

### **Option B: Large Navigable Canvas** (Future)
For when the tabbed approach becomes limiting:
```
+--------------------------------+
| [Mini-map]    Breach Area      |
|  ┌─┐                          |
|  │B│R         ○──○──○          |
|  │P│B         │     │          |
|  └─┘          ○     ○──○       |
|                                |
| Ritual Area     Pack Hunt Area |
+--------------------------------+
```

### **Cross-Tree Synergies** (Future)
- Keystone skills that require points in multiple trees
- Atlas bonus objectives for completing multiple tree paths
- Meta-progression rewards for total points across all trees

## Related Files

**Core Implementation (COMPLETED):**
- `scripts/systems/EventMasterySystem.gd` - Backend system with 16 passives
- `scripts/resources/EventMasteryTree.gd` - Point tracking and persistence
- `scripts/resources/EventDefinition.gd` - Event configuration
- `data/content/events/*.tres` - Event definitions

**Current Assets (FOUNDATION):**
- `scenes/ui/skill_tree/skill_tree.tscn` - Working breach tree POC
- `scenes/ui/skill_tree/skill_tree.gd` - SimpleSkillTree container
- `scenes/ui/skill_tree/skill_button.tscn` - Reusable SkillNode component

**To Be Created:**
- `scenes/ui/skill_tree/EventSkillTree.tscn` - Generic tree component
- `scenes/ui/atlas/AtlasTreeUI.tscn` - Main atlas interface
- `data/content/skills/breach_skills.tres` - Breach tree data definition
- `data/content/skills/ritual_skills.tres` - Ritual tree data definition
- `data/content/skills/pack_hunt_skills.tres` - Pack hunt tree data
- `data/content/skills/boss_skills.tres` - Boss tree data definition

## Notes

**Architecture Philosophy:** The atlas approach provides the best of both worlds - reuses proven components while creating a unified progression experience that scales to multiple event types.

**Implementation Priority:** Focus on getting the basic tabbed interface working first. The large navigable canvas and cross-tree synergies can be added later when the foundation is solid.

**Balance Considerations:** Each tree should feel distinct and specialized while contributing to overall event mastery progression. Avoid overlap between trees but ensure they complement each other.
