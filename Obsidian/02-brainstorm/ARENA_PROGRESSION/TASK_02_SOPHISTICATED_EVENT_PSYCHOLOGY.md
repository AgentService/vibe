# TASK 02: Sophisticated Event Psychology & Multi-Event Choice System
*Created: 2025-01-19 | Status: Ready After Task 01*
*Depends On: TASK_01_CONSOLIDATED_EVENT_PROGRESSION_TASK.md (Breach MVP)*

## Overview
Enhance the basic event system with sophisticated engagement psychology that transforms it from "functional" to "exceptional" - implementing the multi-mind research insights for sustainable long-term engagement.

## Prerequisites
- ✅ Task 01 completed: Basic Breach event working end-to-end
- ✅ EventMasterySystem with modifier application
- ✅ Performance tracking foundation in place
- ✅ MapLevel timer-based progression working

## Core Enhancements

### Phase 1: Multi-Event Choice System (2-3 hours)
**Goal:** Transform from single events to strategic choice architecture

#### 1.1 Simultaneous Event Spawning
```gdscript
# SpawnDirector enhancement
var max_simultaneous_events: int = 3
var active_event_zones: Array[Area2D] = []

func _trigger_multiple_events():
    var available_zones = _get_available_spawn_zones()
    var event_count = min(max_simultaneous_events, available_zones.size())

    for i in event_count:
        var zone = available_zones[i]
        var event_type = _select_strategic_event_type(zone)
        _spawn_event_with_choice_indicators(event_type, zone)
```

#### 1.2 Risk/Reward Visual System
- **Difficulty Indicators**: 1-5 skull icons based on MapLevel scaling
- **Reward Preview**: "High XP", "Rare Items", "Build Cards" text indicators
- **Timer Display**: Countdown showing urgency (2-minute expiry)
- **Distance Assessment**: Clear path visualization to each event

#### 1.3 Strategic Choice Logic
- **Build Synergy Hints**: Events highlight if they suit current build
- **Performance History**: Recommend events based on past success patterns
- **Time Pressure**: Events expire if ignored, creating genuine urgency

### Phase 2: Event Mechanical Personalities (1-2 hours)
**Goal:** Each event type feels distinctly different and responds to builds

#### 2.1 Breach: Portal Cascade Personality
```gdscript
# Breach-specific mechanics
var breach_intensity_stages = ["Opening", "Flowing", "Surging", "Overflowing"]
var current_stage: int = 0

func _update_breach_personality(enemies_killed: int):
    if enemies_killed % 3 == 0:  # Every 3 kills
        current_stage = min(current_stage + 1, breach_intensity_stages.size() - 1)
        _apply_cascade_effects()
```
- **Escalating Intensity**: More enemies spawn as players kill efficiently
- **Cascade Mechanics**: Killing enemies extends duration or spawns more portals
- **Build Response**: High DPS builds trigger more intense cascades

#### 2.2 Ritual: Defensive Coordination Personality
- **Objective Health**: Players must balance offense with protection
- **Wave Patterns**: Predictable attack patterns reward positioning
- **Build Response**: Defensive builds get easier objectives, glass cannons get harder ones

#### 2.3 Pack Hunt: Elite Tactics Personality
- **Formation Intelligence**: Elite packs use tactical positioning
- **Adaptation**: Packs learn from player movement patterns within the event
- **Build Response**: Mobility builds face more coordinated enemies

### Phase 3: Near-Miss Psychology & Performance Scaling (1 hour)
**Goal:** Create "just one more run" motivation through sophisticated reward timing

#### 3.1 Near-Miss Reward System
```gdscript
# Performance tracking enhancement
func _track_near_miss_attempt(survival_time: float, events_completed: int):
    if survival_time >= 840.0:  # 14+ minutes of 15-minute run
        near_miss_bonus_points = calculate_near_miss_bonus(survival_time, events_completed)
        grant_bonus_progression(near_miss_bonus_points)
        show_near_miss_feedback()  # "So close! Try again for bonus!"
```

#### 3.2 Performance-Based Meta Progression
- **Skill Multipliers**: Better play = 2-3x faster meta progression
- **Catch-up Mechanics**: Struggling players get bonus XP for good performance
- **Arena Insights**: Failed runs unlock strategic knowledge about optimal builds
- **Performance Vectors**: Distance + events + efficiency = total XP multiplier

### Phase 4: Flow State Management (30 minutes)
**Goal:** Prevent fatigue through intelligent pacing

#### 4.1 Intensity Wave System
```gdscript
# MapLevel enhancement for flow management
func _calculate_intensity_wave(time_in_run: float) -> float:
    var wave_position = fmod(time_in_run, 180.0) / 180.0  # 3-minute cycles
    var intensity_curve = sin(wave_position * PI) * 0.3 + 0.7  # 0.4 to 1.0 range
    return intensity_curve
```

#### 4.2 Build-Responsive Pacing
- **Aggressive Builds**: Higher baseline intensity with sharper spikes
- **Defensive Builds**: Lower baseline with longer buildup periods
- **Adaptive System**: Learns player preferences over multiple runs

## Advanced Features (Future Phases)

### Phase 5: Transparent Synergy Mathematics (Future)
**Goal:** Players see exact power calculations before making choices

#### 5.1 Passive Preview System
- Show exact multipliers before allocation
- "This passive will increase your breach DPS by 23%"
- Clear cause-and-effect between choices and outcomes

#### 5.2 Build Identity Formation
- Track player build preferences across runs
- Recommend passives based on playstyle patterns
- Create narrative identity around player choices

### Phase 6: Arena Intelligence System (Future)
**Goal:** Failed runs teach concrete strategic knowledge

#### 6.1 Strategic Knowledge Unlocks
- "Elite packs vulnerable to AoE during formation phase"
- "Breach cascades trigger every 3rd kill in this zone"
- "Ritual objectives take 50% less damage from ranged attacks"

#### 6.2 Build Assessment Feedback
- "Your build excels at single-target but struggles with swarms"
- "Consider allocating pack density passives for better efficiency"
- "Your defensive build is optimal for ritual events"

## Technical Implementation Notes

### Event Choice Architecture
```gdscript
# EventChoiceManager.gd - NEW system for managing simultaneous events
extends Node

var pending_events: Array[EventChoice] = []
var max_pending: int = 3

class EventChoice:
    var event_def: EventDefinition
    var zone: Area2D
    var difficulty_rating: int  # 1-5 skulls
    var reward_tier: String    # "High XP", "Rare Items", etc.
    var expiry_time: float     # 2 minutes from spawn
    var build_synergy: float   # 0.0-1.0 compatibility with current build
```

### Performance Analytics
```gdscript
# Enhanced PerformanceTracker for sophisticated metrics
class_name PerformanceTracker extends Node

var near_miss_attempts: int = 0
var build_efficiency_history: Array[float] = []
var event_completion_patterns: Dictionary = {}  # event_type -> success_rate

func calculate_skill_multiplier() -> float:
    var base_multiplier = 1.0
    var efficiency_trend = _calculate_efficiency_trend()
    var near_miss_bonus = min(near_miss_attempts * 0.1, 0.5)  # Up to 50% bonus
    return base_multiplier * (1.0 + efficiency_trend + near_miss_bonus)
```

## Success Criteria

### Core Experience Enhancement
- [ ] 2-3 simultaneous events create meaningful strategic choices
- [ ] Each event type feels mechanically distinct and responsive
- [ ] Near-miss attempts (14+ minutes) create strong motivation to retry
- [ ] Performance-based scaling rewards skilled play with faster progression
- [ ] 3-minute intensity cycles prevent fatigue while maintaining challenge

### Player Psychology Targets
- [ ] Choice satisfaction: "I picked the right event for my situation"
- [ ] Build synergy: "This event suits my build perfectly"
- [ ] Near-miss motivation: "I was so close! One more try..."
- [ ] Skill progression: "I'm getting noticeably better at this"
- [ ] Strategic depth: "I understand the optimal approaches now"

### Technical Integration
- [ ] No performance regression from multiple simultaneous events
- [ ] Event choice UI integrates cleanly with existing HUD
- [ ] Performance tracking feeds into existing meta progression
- [ ] Flow state management works with existing MapLevel scaling

## Files to Create/Modify

### New Files (Minimal)
- `scripts/systems/EventChoiceManager.gd` - Simultaneous event coordination
- `scripts/systems/ArenaIntelligence.gd` - Strategic knowledge tracking
- `scenes/ui/EventChoiceIndicator.tscn` - Risk/reward visual display

### Enhanced Files
- `scripts/systems/SpawnDirector.gd` - Multi-event spawning logic
- `scripts/systems/PerformanceTracker.gd` - Near-miss and skill tracking
- `autoload/MapLevel.gd` - Flow state intensity wave calculations
- `scripts/systems/EventMasterySystem.gd` - Build synergy assessment

## What This Adds Beyond Task 01

### Engagement Psychology
- **Strategic Decision-Making**: Choice between multiple simultaneous events
- **Near-Miss Motivation**: Sophisticated reward timing for retention
- **Performance Recognition**: Skill-based progression acceleration
- **Flow State Optimization**: Intelligent pacing prevents fatigue

### Mechanical Depth
- **Event Personalities**: Each event type behaves distinctly
- **Build Responsiveness**: Events adapt to player build choices
- **Arena Intelligence**: Strategic knowledge accumulation
- **Transparent Mathematics**: Clear cause-and-effect relationships

This transforms the basic event system into a sophisticated engagement engine that creates sustainable long-term motivation through psychological design rather than just mechanical complexity.