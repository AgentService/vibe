# Map-Based Progression Analysis
*Created: 2025-01-16 | Status: Refined Based on User Feedback*

## Executive Summary

This document presents a **simple, choice-driven event system** for a small-scale 2D top-down roguelike swarm game. Focus is on meaningful player decisions under time pressure, not complex tracking systems.

## Core Design Philosophy

**Simple Event Choice System** - Player agency through clear decisions
- 2-3 simultaneous events across different map locations
- Player chooses which event to tackle based on risk/reward assessment
- Time pressure creates urgency without overwhelming complexity
- Events provide immediate power progression during runs

## Event-Based Progression Model

### **Core Loop**
```
See Multiple Events → Choose Based on Risk/Reward → Complete Event → Get Power Increase →
New Events Spawn → Make Next Strategic Choice → Map Tier Progression Every 15 Minutes
```

### **Event Types (4 Core Types)**
1. **Strong Pack Defeat** - Elite enemy groups, high XP rewards
2. **Defend Objective** - Protect target under attack, steady rewards
3. **Collection/Activation** - Gather objectives under pressure, item rewards
4. **Mini-Boss Encounter** - Special boss mechanics, rare items

### **Event Choice Mechanics**
- **2-3 events active simultaneously** across different map locations
- **Visual indicators**: Color coding (Red=Combat, Blue=Defend, Yellow=Collect, Purple=Boss)
- **Risk display**: 1-5 skull icons show difficulty level
- **Reward preview**: "High XP", "Rare Items", "Equipment Upgrade"
- **Timer countdown**: Creates urgency, events expire if ignored
- **Player approaches to activate** - no automatic engagement

## Addressing Core Design Goals

### **Pack Spawning Overlap Solution**
- **Baseline continuous spawning** continues during events (hybrid approach)
- **Event-specific spawn control**: Some events can create "no-spawn zones" when needed
- **Pre-spawned pack system**: 1 rare + magic/normal monsters, avoid event locations
- **Flexible spawn behavior**: Event zones can override proximity rules as needed

### **Player Motivation & Power Progression**
**What drives engagement?**
- **Immediate power increases**: Cards/points/stat boosts right after event completion
- **Strategic choice satisfaction**: "I picked the right event for my situation"
- **Time pressure mastery**: Successfully managing multiple event priorities
- **Meta progression unlocks**: In-run events unlock post-run passive tree spending

**Current Card System Integration:**
- Events reward cards that provide immediate build enhancement
- Alternative: Point-based skill enhancement currency from events
- Meta progression slots activated during run, enhanced after run

### **Pacing & Rhythm (Time-Based Map Tiers)**
**15-minute map tier progression:**
- **Predictable escalation** every 15 minutes regardless of event performance
- **Events = superior rewards** compared to baseline wave farming
- **Fast completion = more events per tier** = more total rewards
- **Anti-gaming design**: No strategies to manipulate timing for advantage

**Baseline + Event Pressure:**
- **Continuous spawning** maintains constant pressure
- **Event spikes** provide intensity variation and choice moments
- **No full breathing room** - always some threat level present
- **Events spawn 30-60 seconds** after previous completion

## Technical Architecture

### **Simple Event Management**
```gdscript
# Event Types (No Complex States)
enum EventType {
    STRONG_PACK_DEFEAT,    # Combat focus
    DEFEND_OBJECTIVE,      # Defense focus
    COLLECTION_ACTIVATION, # Mobility focus
    MINI_BOSS_ENCOUNTER   # Boss mechanics
}

# Event Configuration
@export_group("Event System")
@export var event_spawn_locations: Array[Vector2] = []
@export var max_simultaneous_events: int = 3
@export var event_spawn_interval: Vector2 = Vector2(30, 60)  # 30-60 seconds
@export var event_expiry_time: float = 120.0  # 2 minutes to complete
```

### **Integration with Existing Systems**
- **SpawnDirector.gd**: Respect event no-spawn zones when needed per event type
- **MapConfig.gd**: Event definitions, reward scaling, map tier progression
- **EventBus**: Event completion signals, reward distribution
- **PlayerProgression.gd**: Card system integration, meta progression unlock tracking

## Mathematical Progression Framework

### **Map Tier Progression (15-Minute Intervals)**
```gdscript
# Time-Based Tier Advancement
current_map_tier = floor(run_time_minutes / 15.0) + 1
enemy_stat_multiplier = 1.0 + (current_map_tier - 1) * 0.3  # 30% per tier
reward_multiplier = 1.0 + (current_map_tier - 1) * 0.4     # 40% per tier
```

### **Event Reward Scaling**
```gdscript
# Events Always Better Than Wave Farming
baseline_xp_per_minute = 100 * map_tier_multiplier
event_xp_bonus = baseline_xp_per_minute * 1.5  # 50% more than farming
fast_completion_bonus = max(1.0, (time_limit - completion_time) / time_limit * 0.5)
```

**Anti-Gaming Measures:**
- Event rewards scale with map tier, not completion speed
- Missing events = missed opportunities, not penalties
- No strategies to manipulate tier progression timing

## Player Engagement Psychology

### **The Core Choice Moment**
**What creates engagement:**
- **Visual assessment**: Player sees 2-3 events with clear risk/reward indicators
- **Mental evaluation**: "Which event suits my current build/situation?"
- **Time pressure**: "That boss event expires in 90 seconds, can I make it?"
- **Strategic thinking**: "Do I need XP or items more right now?"

### **Decision Satisfaction Loop**
1. **See choices** - Clear visual event indicators with risk/reward preview
2. **Make assessment** - Player uses intuition about their build strengths
3. **Commit to choice** - Approach event to activate
4. **Execute under pressure** - Complete event with baseline spawning continuing
5. **Get immediate power** - Cards/points/stat boosts right away
6. **New choices appear** - Cycle continues with escalating challenge

## Progression Systems Integration

### **In-Run Progression (Immediate Power)**
- **Current card system** works perfectly for event rewards
- **Point-based skill enhancement** as alternative to cards
- **Stat boosts** provide immediate power feedback
- **No temporary items** - avoided complexity as planned

### **Meta Progression (Between Runs)**
- **Permanent passive tree** (PoE-style) unlocked by in-run event completion
- **Equipment unlocks** through map tier progression
- **Character-wide passive advancement** separate from abilities
- **Meta progression slots** activated during run, enhanced after

## Implementation Priority

### **Phase 1: Core Event Choice System** (Week 1-2)
1. **Event visual indicators** - Color coding and risk/reward display
2. **Multiple simultaneous events** - 2-3 active at different locations
3. **Timer-based expiry** - Events disappear after 2 minutes
4. **Approach-to-activate** - Player choice to engage
5. **Basic reward integration** - Cards/XP through existing systems

### **Phase 2: Spawn System Integration** (Week 3-4)
1. **Baseline continuous spawning** during events
2. **Event-specific spawn control** - No-spawn zones where needed
3. **Pre-spawned pack avoidance** - Packs avoid event locations
4. **Map tier progression** - 15-minute automatic advancement

### **Phase 3: Polish & Meta-Progression** (Month 2+)
1. **Enhanced visual feedback** - Better event indicators
2. **Meta progression integration** - Passive tree unlocks
3. **Balance iteration** - Based on actual play data

## Success Metrics

### **Engagement Indicators**
- **Choice satisfaction**: Players feel good about event selection decisions
- **Time pressure balance**: Urgency without overwhelming stress
- **Power progression feel**: Immediate strength increases after events
- **Strategic depth**: Multiple valid approaches to event priority

### **Technical Targets**
- **Simple implementation**: No complex state tracking
- **Performance**: Minimal overhead on existing systems
- **Integration**: Works with current card/progression systems

## Visual Design Requirements

### **Clear Event Communication**
- **Color coding**: Red (Combat), Blue (Defend), Yellow (Collect), Purple (Boss)
- **Risk indicators**: 1-5 skull icons for difficulty
- **Reward preview**: Text showing "High XP", "Equipment", "Cards"
- **Timer display**: Countdown showing urgency
- **Distance/path clarity**: Player can quickly assess travel time

## Key Design Principles

### **Simplicity Over Complexity**
- **No build tracking** - Player intuition handles build synergy
- **No performance analytics** - Focus on immediate choice satisfaction
- **No adaptive systems** - Consistent, predictable event behavior
- **No chains or dependencies** - Each event stands alone

### **Player Agency Focus**
- **Clear choices** with visible consequences
- **Time pressure** creates engagement without stress
- **Strategic thinking** rewarded through better outcomes
- **Build variety** supported through different event types

This system creates engagement through **meaningful choice under time pressure**, exactly matching the PoE league mechanic style without overcomplicating the implementation.