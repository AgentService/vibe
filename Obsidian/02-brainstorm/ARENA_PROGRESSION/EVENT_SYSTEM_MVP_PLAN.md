# Event System MVP - PoE-Style Encounters
*Created: 2024 | Status: Planning Phase*

## Objective
Create event-based encounters (PoE league mechanic style) that provide strategic objectives, reward variety, and solve pack spawning overlap issues.

## Foundation: Leverage Existing Scaling System ✅

**Current SpawnDirector.gd capabilities:**
- Time-based and wave-based scaling (15% per wave)
- MapLevel integration with configurable multipliers
- Zone-based spawning with proximity filtering
- Pack spawning system with size scaling (5-10 base, up to 2.5x multiplier)

**Scaling Controls Available:**
- `MapConfig.base_spawn_scaling` - all parameters configurable
- `arena_scaling_overrides` - per-arena customization
- Dynamic difficulty via existing multiplier systems

## MVP Event System Design

### Event Types (PoE-Inspired)
1. **Breach-Style**: Activate portal, waves of enemies emerge over time
2. **Ritual-Style**: Defend altar while enemies attack from all sides
3. **Abyss-Style**: Follow moving crack/portal, fight enemies along path
4. **Pack Hunt**: Elite enemy pack with special composition/rewards

### Event Flow
```
1. Event Spawn → Visual indicator appears at zone location
2. Player Approach → Event becomes interactable
3. Event Activation → Player triggers encounter (optional choice)
4. Event Execution → Specific encounter mechanics
5. Event Completion → Rewards granted + next event timer starts
```

### Reward Structure
- **Event XP**: Superior to baseline wave farming
- **Event Currency**: Special tokens for meta progression
- **Build Resources**: Cards/points for in-run progression
- **Performance Scaling**: Better execution = better rewards

## Technical Implementation Plan

### Phase 1: Event Infrastructure (2-3 hours)
**Files to Create/Modify:**
- `scripts/systems/EventSystem.gd` - Event management and scheduling
- `scripts/resources/EventDefinition.gd` - Data-driven event configuration
- `data/content/events/breach_basic.tres` - First event type

**Core Features:**
- Event spawn timers (30-60s between events)
- Zone-based event placement (use existing spawn zones)
- Event activation triggers (player proximity/interaction)
- Reward distribution system

### Phase 2: Event Types (1-2 hours each)
**Breach Event:**
- Spawn portal at zone center
- Waves of enemies emerge over 30-45 seconds
- Player can leave anytime, better rewards for staying longer

**Pack Hunt Event:**
- Spawn 1 rare + 3-5 magic enemies at zone
- Use existing pack spawning with special composition
- Higher rewards than normal packs

### Phase 3: Integration Testing (1 hour)
- Test event scheduling doesn't interfere with baseline spawning
- Verify no-spawn zones work for events that need them
- Test event completion → reward → next event timer cycle

## Event System Architecture

### EventDefinition.gd
```gdscript
extends Resource
class_name EventDefinition

@export var id: StringName
@export var display_name: String
@export var event_type: StringName  # "breach", "pack_hunt", "ritual"
@export var duration: float = 30.0
@export var zone_requirement: StringName = ""  # Specific zone or "" for any
@export var rewards: Dictionary = {}
@export var enemy_config: Dictionary = {}
@export var visual_config: Dictionary = {}
```

### EventSystem.gd Integration
```gdscript
# Leverage existing SpawnDirector
extends Node

var spawn_director: SpawnDirector
var active_events: Array[EventInstance] = []
var event_timer: float = 0.0
var next_event_delay: float = 45.0  # 45s between events

func _on_event_trigger(event_def: EventDefinition, zone: Area2D):
    # Use SpawnDirector for enemy spawning within event
    # Apply event-specific scaling multipliers
    # Track event progress and completion
```

## Success Metrics

### Gameplay Feel
- Events feel more rewarding than baseline wave farming
- Clear strategic objectives motivate player movement
- Event variety prevents repetitive gameplay
- Time pressure creates engagement without frustration

### Technical Performance
- Events don't interfere with baseline spawning system
- Zone-based placement works with existing spawn zones
- Event completion → reward → timer cycle feels smooth
- No performance degradation from event system

## Integration with Broader Vision

### Connects To:
- **Dynamic Scaling**: Events can use existing scaling multipliers
- **Meta Progression**: Event rewards feed into meta progression system
- **Map Timer System**: Events provide variety within 15-minute map structure
- **Performance Rewards**: Event efficiency affects meta progression XP

### Future Extensions:
- Event chains (completing one unlocks special follow-up)
- Map tier specific events (higher tiers = more complex events)
- Event modifiers from meta progression
- Seasonal/rotating event types

## Next Steps
1. Create basic event infrastructure using existing spawn zones
2. Implement Breach-style event as proof of concept
3. Test event → reward → next event cycle
4. Add Pack Hunt event for variety
5. Integrate with meta progression system (when designed)

---

## Open Questions
- Should events override baseline spawning or add to it?
- How many simultaneous events should be possible?
- What's the optimal event frequency for sustained engagement?
- How should failed/abandoned events be handled?