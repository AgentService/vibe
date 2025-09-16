# MAP_PROGRESSION_AND_EVENTS_V1 - Integrated Dynamic Map System

Status: Ready to Start
Owner: Solo (Indie)
Priority: High
Type: System Integration
Dependencies: SpawnDirector (✅ working), MapConfig (✅ working), MapLevel (✅ working)
Risk: Medium-Low (builds on proven foundations)
Complexity: MVP=3/10, Full=6/10

---

## Overview

Create an integrated map progression system with PoE-style events that delivers the core gameflow vision: **15-minute map cycles with dynamic scaling, strategic events, and performance-based progression.**

**Foundation:** Leverages existing SpawnDirector, MapConfig, and MapLevel systems that are already working well.

**Vision Integration:** Combines map tier progression with event-driven encounters to create the "frantically dodging swarms while growing powerful" experience with clear objectives and rewards.

**Enhancement Strategy:** Based on comprehensive multi-specialist analysis (see `Obsidian/02-brainstorm/MULTI_MIND_ENHANCEMENT_STRATEGY_2025.md`), this system integrates proven 2024-2025 engagement patterns while respecting existing architecture.

---

## Core Design Principles (From Brainstorming)

### Gameflow Vision
- **15-minute map cycles** with time-based tier progression
- **PoE-style events** (Breach, Pack Hunt, Ritual) as strategic objectives
- **Performance-based rewards** - skill creates faster meta progression
- **Expected failure progression** - maps scale beyond player power, failure drives meta advancement
- **Event superiority** - events always more rewarding than baseline wave farming

### Progression Philosophy
- **Dual progression**: In-run power (cards/points) + meta advancement (between runs)
- **Dynamic scaling**: Same map, difficulty scales with meta progression
- **Performance multipliers**: Better play = more XP/faster meta progression
- **Anti-gaming**: No exploitable timing strategies, events drive optimal play

### Enhancement Principles (Multi-Mind Analysis)
- **Event Mastery System**: PoE Atlas-style passive tree where players earn points from completing events
- **Transparent Synergy Systems**: Players see exact power multipliers before selection
- **Activity-Based Development**: Zone mastery through actual play patterns
- **Failure-Forward Design**: Near-miss psychology creates "just one more run" engagement
- **Flow State Management**: 3-minute intensity cycles prevent fatigue while maintaining challenge

---

## Current Foundation (✅ Working)

### Existing Infrastructure
- **SpawnDirector**: Zone-based spawning with proximity filtering, pack formation support
- **MapLevel**: Time-based progression system with scaling multipliers
- **MapConfig**: Data-driven arena configuration with scaling parameters
- **Zone System**: Scene-based Area2D spawn zones with proper geometry detection
- **Dynamic Scaling**: Multiple scaling factors (time, wave, level, density)

### Scaling Capabilities Already Working
```gdscript
// From MapConfig.gd - fully configurable
base_spawn_scaling = {
    "time_scaling_rate": 0.1,        // 10% per minute
    "wave_scaling_rate": 0.15,       // 15% per wave
    "pack_base_size_min": 5,
    "pack_base_size_max": 10,
    "max_scaling_multiplier": 2.5
}

// From SpawnDirector.gd - working scaling integration
var level_multiplier = MapLevel.get_pack_size_scaling()
var wave_multiplier = 1.0 + (current_wave_level - 1) * wave_scaling
var final_multiplier = level_multiplier * wave_multiplier // + other factors
```

---

## Implementation Phases

### Phase 1: Core Event System with Mastery Foundation (2-3 hours) 🎯 Immediate Priority

**Goal:** Create PoE-style events using existing SpawnDirector infrastructure with mastery point foundation

**Event Types:**
1. **Breach**: Portal-style waves of enemies emerging over time
2. **Ritual**: Defend objective while enemies attack from all sides
3. **Pack Hunt**: Elite pack (1 rare + 3-5 magic enemies) with superior rewards
4. **Boss Encounter**: Special boss mechanics with unique rewards

**Event Mastery System Foundation:**
```gdscript
# EventMasteryTree.gd - NEW Resource
extends Resource
class_name EventMasteryTree

@export var breach_points: int = 0
@export var ritual_points: int = 0
@export var pack_hunt_points: int = 0
@export var boss_points: int = 0

@export var allocated_passives: Dictionary = {}  # passive_id -> allocated

func is_passive_allocated(passive_id: StringName) -> bool:
    return allocated_passives.get(passive_id, false)

func can_allocate_passive(passive_id: StringName, passive_def: PassiveDefinition) -> bool:
    var required_points = passive_def.get_required_points_for_type()
    var available_points = get_points_for_event_type(passive_def.event_type)
    return available_points >= required_points and not is_passive_allocated(passive_id)
```

**Technical Approach:**
```gdscript
# EventMasterySystem.gd - NEW System for applying mastery modifiers
extends Node

var mastery_tree: EventMasteryTree
var active_modifiers: Dictionary = {}

func apply_event_modifiers(event_type: StringName, base_config: Dictionary) -> Dictionary:
    var modified_config = base_config.duplicate()

    match event_type:
        "breach":
            if mastery_tree.is_passive_allocated("breach_density_1"):
                modified_config["monster_count"] *= 1.25  # +25% monsters
            if mastery_tree.is_passive_allocated("breach_duration_1"):
                modified_config["duration"] += 3.0  # +3 seconds

        "ritual":
            if mastery_tree.is_passive_allocated("ritual_area_1"):
                modified_config["circle_radius"] *= 1.5  # +50% area
            if mastery_tree.is_passive_allocated("ritual_spawn_rate_1"):
                modified_config["spawn_interval"] -= 15.0  # -15s between spawns

        "pack_hunt":
            if mastery_tree.is_passive_allocated("pack_density_1"):
                modified_config["rare_companions"] += 1  # +1 magic enemy
            if mastery_tree.is_passive_allocated("pack_rewards_1"):
                modified_config["xp_multiplier"] *= 1.3  # +30% XP

    return modified_config

func _on_event_completed(event_type: StringName):
    # Award mastery points
    match event_type:
        "breach": mastery_tree.breach_points += 1
        "ritual": mastery_tree.ritual_points += 1
        "pack_hunt": mastery_tree.pack_hunt_points += 1
        "boss": mastery_tree.boss_points += 1

    EventBus.mastery_points_earned.emit(event_type, 1)
```

**Event Mastery Passive Examples (PoE Atlas Style):**
- **Breach Density**: "Breaches spawn 25%/50% more monsters"
- **Breach Duration**: "Breaches last 3/5 seconds longer"
- **Ritual Area**: "Ritual circles are 50%/100% larger"
- **Pack Hunt Efficiency**: "Elite packs spawn 15/30 seconds faster"
- **Boss Rewards**: "Boss encounters grant 50%/100% more XP"

**Files to Create:**
- `scripts/resources/EventMasteryTree.gd` - NEW: Mastery point tracking and passive allocation
- `scripts/systems/EventMasterySystem.gd` - NEW: Apply mastery modifiers to events
- `scripts/resources/EventDefinition.gd` - NEW: Data-driven event configuration
- `scripts/resources/PassiveDefinition.gd` - NEW: Configurable passive effects
- `data/content/events/breach_basic.tres` - NEW: Portal-style event type
- `data/content/events/ritual_basic.tres` - NEW: Defend objective event type
- `data/content/events/pack_hunt_basic.tres` - NEW: Elite pack event type
- `data/content/events/boss_basic.tres` - NEW: Boss encounter event type
- `data/content/masteries/breach_masteries.tres` - NEW: Breach passive tree
- `data/content/masteries/ritual_masteries.tres` - NEW: Ritual passive tree

**Files to Modify:**
- `scripts/systems/SpawnDirector.gd` - Add event spawning with mastery modifier integration
- `scripts/resources/MapConfig.gd` - Add event system configuration options
- `autoload/EventBus.gd` - Add mastery point earning and allocation signals

### Phase 1.5: Event Mastery Tree UI (1-2 hours)

**Goal:** Create simple UI for viewing mastery points and allocating passives

**Mastery Tree UI System:**
```gdscript
# scenes/ui/MasteryTreeUI.gd - Simple passive allocation interface
class_name MasteryTreeUI extends Control

@export var mastery_tree: EventMasteryTree
var available_passives: Array[PassiveDefinition] = []

func _ready():
    load_available_passives()
    refresh_ui()

func _on_passive_button_pressed(passive_id: StringName):
    if mastery_tree.can_allocate_passive(passive_id, get_passive_def(passive_id)):
        mastery_tree.allocate_passive(passive_id)
        EventBus.passive_allocated.emit(passive_id)
        refresh_ui()

func refresh_ui():
    # Update point displays per event type
    # Update passive button states (available/allocated/locked)
    # Show passive descriptions with current effects
```

**UI Features:**
- **Simple tab interface**: One tab per event type (Breach, Ritual, Pack Hunt, Boss)
- **Point display**: Shows earned/spent points per event type
- **Passive previews**: Clear description of what each passive does
- **Visual feedback**: Allocated passives show as active, locked ones grayed out
- **Respec option**: Allow reallocation for testing/experimentation

### Phase 2: Map Tier Progression with Flow Management (1-2 weeks)

**Goal:** Implement 15-minute map cycles with dynamic difficulty scaling and intensity wave management

**Map Tier System:**
```gdscript
// Enhanced MapLevel.gd
class_name MapLevel extends Node

var current_tier: int = 1
var tier_duration: float = 900.0  // 15 minutes per tier
var tier_timer: float = 0.0

signal tier_advanced(new_tier: int, old_tier: int)
signal tier_scaling_updated(scaling_multiplier: float)

func _ready():
    tier_advanced.connect(_on_tier_advanced)

func _on_tier_advanced(new_tier: int, old_tier: int):
    // Immediate scaling update for all enemies
    var new_scaling = calculate_tier_scaling(new_tier)
    tier_scaling_updated.emit(new_scaling)

    // Trigger tier progression rewards
    EventBus.tier_progression_rewards.emit(new_tier)

# Add intensity wave management
func _calculate_intensity_wave(time_in_run: float) -> float:
    # 3-minute intensity cycles for flow state management
    var wave_position = fmod(time_in_run, 180.0) / 180.0
    var intensity_curve = sin(wave_position * PI) * 0.3 + 0.7  # 0.4 to 1.0 range
    return intensity_curve
```

**Enhanced Dynamic Scaling Features:**
- **Auto-scaling**: Each tier increases enemy stats by configurable percentage
- **New enemy types**: Higher tiers unlock different enemy varieties
- **Better rewards**: Each tier improves drop tables and XP rates
- **Event scaling**: Events become more challenging and rewarding
- **Intensity wave management**: 3-minute cycles prevent fatigue while maintaining challenge
- **Build-responsive pacing**: Different intensity patterns for aggressive vs defensive builds

**Same Map, Scaling Difficulty:**
- **Implementation efficiency**: No need for multiple map assets
- **Consistent experience**: Players learn map layout, focus on scaling challenge
- **Data-driven scaling**: All difficulty curves configurable via MapConfig

### Phase 3: Map Selection & Tier System (1 week)

**Goal:** Implement map selection UI and tier progression infrastructure

**MapDevice UI System:**
```gdscript
// scenes/ui/MapDevice.gd - Hideout map selection interface
class_name MapDevice extends Control

@export var available_maps: Array[MapDefinition] = []
var current_tier: int = 1
var selected_modifiers: Array[String] = []

signal map_run_requested(map_id: StringName, tier: int, modifiers: Array[String])

func _on_launch_button_pressed():
    // Validate tier access via meta progression
    // Create MapInstance with selected configuration
    // Emit map_run_requested for ArenaLoader
```

**ArenaLoader Integration:**
```gdscript
// scripts/systems/ArenaLoader.gd - Scene management and transitions
class_name ArenaLoader extends RefCounted

static func run_map(map_id: StringName, tier: int, modifiers: Array[String]) -> void:
    // Create MapInstance from parameters
    // Handle scene transitions with proper cleanup
    // Apply tier scaling and modifiers
    // Emit EventBus signals for progression tracking
```

**Key Features:**
- **Map Selection**: Choose from unlocked arena themes
- **Tier Selection**: Access tiers based on meta progression
- **Modifier Selection**: Apply difficulty/reward modifiers
- **Scene Management**: Clean transitions between hideout and arenas

### Phase 4: Enhanced Performance-Based Progression with Failure-Forward Design (1 week)

**Goal:** Reward skilled play with faster meta progression and implement near-miss psychology

**Performance Metrics:**
```gdscript
// Performance tracking during map run
class_name PerformanceTracker extends Node

var events_completed: int = 0
var events_available: int = 0
var damage_dealt: float = 0.0
var damage_taken: float = 0.0
var survival_time: float = 0.0
var tier_reached: int = 1

func calculate_performance_multiplier() -> float:
    var base_multiplier = 1.0

    // Event completion efficiency
    var event_efficiency = float(events_completed) / float(events_available) if events_available > 0 else 1.0
    base_multiplier *= (1.0 + event_efficiency * 0.5)  // Up to 50% bonus

    // Survival performance
    var expected_survival = tier_reached * 900.0  // 15 minutes per tier
    var survival_bonus = survival_time / expected_survival
    base_multiplier *= survival_bonus

    // Damage efficiency (dealt vs taken ratio)
    var damage_efficiency = damage_dealt / max(damage_taken, 1.0)
    base_multiplier *= (1.0 + min(damage_efficiency * 0.1, 0.3))  // Up to 30% bonus

    return min(base_multiplier, 3.0)  // Cap at 3x multiplier

# Add near-miss psychology tracking
func record_near_miss_attempt(survival_time: float, tier_reached: int) -> void:
    if survival_time >= 840.0:  # 14+ minutes of 15-minute run
        near_miss_count += 1
        grant_near_miss_bonus(survival_time, tier_reached)
```

**Enhanced Meta Progression Integration:**
- **XP Multipliers**: Performance directly affects meta progression speed
- **Catch-up Mechanics**: Players with low meta progression get bonus XP for good performance
- **Skill Rewards**: Advanced players progress faster even without meta upgrades
- **Near-Miss Psychology**: 14+ minute runs grant special progression bonuses
- **Failure-Forward Design**: Each death teaches concrete strategic knowledge
- **Arena Insights**: Failed runs unlock knowledge about optimal event prioritization

### Phase 5: Meta Progression System (Future - Separate Design)

**Goal:** Design hideout progression that connects to map performance

**Core Concepts:**
- **Between-run progression**: Passive tree, equipment unlocks, character upgrades
- **Performance connection**: Map performance determines meta progression currency
- **Expected failure cycle**: Maps scale beyond current power, failure drives advancement

**Design Requirements:**
- **Failure as progression**: Never feel punitive, always advancing
- **Clear milestones**: Visible progress toward next unlock/upgrade
- **Build enablers**: Meta progression unlocks new in-run build options

---

## Integration with Existing Systems

### SpawnDirector Integration
```gdscript
// Event spawning builds on existing pack spawning
func spawn_event_pack(event_def: EventDefinition, zone_area: Area2D):
    // Use existing proximity filtering
    // Use existing formation patterns
    // Use existing enemy selection weights
    // Add event-specific rewards and timing
```

### MapConfig Enhancement
```gdscript
// Add event configuration to existing MapConfig
@export_group("Event System")
@export var event_spawn_enabled: bool = true
@export var event_spawn_interval: float = 45.0
@export var available_events: Array[StringName] = ["breach", "pack_hunt", "ritual"]
@export var event_reward_multiplier: float = 3.0
```

### Zone System Leverage
- **Use existing Area2D zones** for event placement
- **Leverage proximity filtering** (300px auto, 500px pack, configurable for events)
- **Build on formation patterns** (circle, line, cluster) for event enemy placement

---

## Technical Architecture

### Event System Design
```gdscript
// EventDefinition.gd - Data-driven event configuration
extends Resource
class_name EventDefinition

@export var id: StringName
@export var display_name: String
@export var event_type: StringName  // "breach", "pack_hunt", "ritual"
@export var duration: float = 30.0
@export var enemy_config: Dictionary = {}  // Uses existing enemy selection
@export var reward_config: Dictionary = {}
@export var visual_config: Dictionary = {}  // Portal effects, UI indicators
```

### Progression Integration
```gdscript
// MapProgressionService.gd - Connects performance to meta advancement
class_name MapProgressionService extends RefCounted

static func calculate_run_rewards(performance: PerformanceTracker) -> Dictionary:
    var base_xp = performance.tier_reached * 100
    var multiplier = performance.calculate_performance_multiplier()
    var total_xp = base_xp * multiplier

    return {
        "meta_xp": total_xp,
        "event_tokens": performance.events_completed,
        "tier_bonus": performance.tier_reached * 10
    }
```

---

## Success Metrics

### Phase 1 Success (Core Event System with Mastery Foundation)
- [ ] 4 event types working with basic functionality (Breach, Ritual, Pack Hunt, Boss)
- [ ] Events spawn every 30-60 seconds using existing zones
- [ ] Mastery points earned (1 per event completion) and tracked correctly
- [ ] EventMasteryTree resource saves/loads mastery progression correctly
- [ ] Events provide 3x XP compared to baseline wave farming
- [ ] Event completion feels more rewarding than wave farming
- [ ] No interference with existing auto/pack spawning

### Phase 1.5 Success (Event Mastery Tree UI)
- [ ] Simple mastery tree UI shows earned points per event type
- [ ] Players can allocate/deallocate passives using available points
- [ ] Passive descriptions clearly explain effects before allocation
- [ ] Visual feedback shows allocated vs available vs locked passives
- [ ] Respec functionality works for testing different builds

### Phase 2 Success (Map Tier Progression with Flow Management)
- [ ] 15-minute tier cycles with automatic progression
- [ ] Dynamic scaling applies to all enemies (current + new spawns)
- [ ] Tier progression feels meaningful (noticeable difficulty increase)
- [ ] Same map supports multiple difficulty tiers
- [ ] 3-minute intensity wave cycles prevent fatigue while maintaining challenge
- [ ] Event mastery modifiers visibly affect event behavior (density, duration, rewards)
- [ ] Performance differences between players visible in progression

### Phase 3 Success (Map Selection & Tier System)
- [ ] MapDevice UI allows selection of unlocked maps and tiers
- [ ] ArenaLoader handles clean scene transitions without memory leaks
- [ ] Tier gating works based on meta progression unlocks
- [ ] Map modifiers apply correctly and affect gameplay
- [ ] Scene management integrates properly with existing arena systems

### Phase 4 Success (Enhanced Performance-Based Progression with Failure-Forward Design)
- [ ] Skilled players progress 2-3x faster than average players
- [ ] Performance metrics accurately reflect player skill
- [ ] Catch-up mechanics help lower-skill players progress
- [ ] Near-miss psychology provides special bonuses for 14+ minute survival
- [ ] Failure-forward design makes each death feel like meaningful progression
- [ ] Arena insights unlock strategic knowledge through failed attempts
- [ ] No exploitable strategies for inflating performance metrics

---

## File Touch List

### New Files
**Event Mastery System:**
- `scripts/resources/EventMasteryTree.gd` - Mastery point tracking and passive allocation
- `scripts/systems/EventMasterySystem.gd` - Apply mastery modifiers to events
- `scripts/resources/EventDefinition.gd` - Data-driven event configuration
- `scripts/resources/PassiveDefinition.gd` - Configurable passive effects
- `scripts/systems/PerformanceTracker.gd` - Enhanced with near-miss psychology tracking
- `scripts/systems/MapProgressionService.gd` - Failure-forward design integration
- `data/content/events/breach_basic.tres` - Portal-style event type
- `data/content/events/ritual_basic.tres` - Defend objective event type
- `data/content/events/pack_hunt_basic.tres` - Elite pack event type
- `data/content/events/boss_basic.tres` - Boss encounter event type
- `data/content/masteries/breach_masteries.tres` - Breach passive tree
- `data/content/masteries/ritual_masteries.tres` - Ritual passive tree
- `data/content/masteries/pack_hunt_masteries.tres` - Pack Hunt passive tree
- `data/content/masteries/boss_masteries.tres` - Boss passive tree

**UI Systems:**
- `scenes/ui/MasteryTreeUI.tscn` - Mastery tree interface
- `scripts/ui/MasteryTreeUI.gd` - Mastery tree UI logic

**Map Selection & Infrastructure:**
- `scripts/systems/ArenaLoader.gd`
- `scenes/ui/MapDevice.tscn`
- `scripts/ui/MapDevice.gd`
- `scripts/resources/MapDefinition.gd`

### Modified Files
**Core Systems:**
- `scripts/systems/SpawnDirector.gd` - Add event spawning with mastery modifier integration and intensity management
- `autoload/MapLevel.gd` - Add tier progression, scaling, and intensity wave calculations
- `scripts/resources/MapConfig.gd` - Add event system configuration options
- `scripts/resources/CardResource.gd` - Add synergy calculation and transparent preview systems
- `autoload/EventBus.gd` - Add tier progression, event signals, and mastery point events
- `autoload/PlayerProgression.gd` - Add failure-forward tracking and near-miss psychology

**Integration:**
- `scenes/arena/UnderworldArena.tscn` - Event visual indicators
- `data/content/maps/underworld_config.tres` - Event configuration

### Testing
- `tests/EventSystem_Integration.tscn/.gd` - Event spawning and rewards
- `tests/TierProgression_Test.gd` - Tier scaling and performance tracking

---

## Risk Assessment & Mitigations

### Medium-Low Risk - System Integration
- **Risk**: Event system might interfere with existing spawning
- **Mitigation**: Build on existing SpawnDirector, use same zone system
- **Validation**: Extensive testing with existing auto/pack spawning

### Low Risk - Performance Impact
- **Risk**: Additional systems might impact performance
- **Mitigation**: Leverage existing systems, avoid new allocations
- **Validation**: Performance testing ensures no regression

### Low Risk - Balance Issues
- **Risk**: Events might be over/under-rewarding compared to waves
- **Mitigation**: Configurable reward multipliers, iterative tuning
- **Validation**: Playtesting with different reward configurations

---

## Timeline & Dependencies

**Phase 1 (Core Event System with Mastery Foundation): 2-3 hours**
- Basic event system using existing SpawnDirector infrastructure
- 4 event types with fundamental functionality
- Mastery point earning and tracking system
- Integration testing

**Phase 1.5 (Event Mastery Tree UI): 1-2 hours**
- Simple mastery tree interface for point allocation
- Passive description and allocation system
- Basic respec functionality

**Phase 2 (Map Tier Progression with Flow Management): 1-2 weeks**
- Tier system implementation with intensity wave management
- Event mastery modifier integration
- Performance tracking foundation

**Phase 3 (Map Selection & Tier System): 1 week**
- MapDevice UI for map/tier selection
- ArenaLoader scene management
- Tier gating via meta progression

**Phase 4 (Enhanced Performance-Based Progression): 1 week**
- Performance metrics with near-miss psychology
- Failure-forward design implementation
- Meta progression integration with arena insights

**Total Effort: ~3-4 weeks for complete system (reduced Phase 1 complexity)**

---

## Integration with Broader Vision

### Connects To Enhanced Gameflow Vision
- ✅ **"Frantically dodging swarms while growing powerful"** - Events + scaling + intensity waves
- ✅ **"Strategic objectives with time pressure"** - Event mastery system with player choice
- ✅ **"Performance-based progression"** - XP multipliers + near-miss psychology
- ✅ **"15-minute map cycles"** - Tier progression with flow management
- ✅ **"Expected failure drives advancement"** - Failure-forward design + arena insights
- ✅ **"Build synergies feeling impactful"** - Transparent synergy mathematics
- ✅ **"Player agency in event modification"** - Direct control via mastery passives (PoE Atlas style)
- ✅ **"Just one more run psychology"** - Near-miss rewards for 14+ minute survival

### Enables Future Systems (Enhanced with Multi-Mind Insights)
- **Multiple arena types** - Event mastery system works across different arena themes
- **Advanced event types** - Foundation supports complex mechanics with mastery modifiers
- **Deep meta progression** - Performance tracking + failure-forward design enables sophisticated advancement
- **Seasonal content** - Event system can support rotating/special events with new mastery trees
- **Build identity formation** - Transparent synergy systems support projective character identity
- **Social systems** - Arena insights and build showcases enable community features
- **Mastery specialization** - Players can focus on specific event types for different playstyles

### Preserves Existing Work
- **SpawnDirector architecture** - Enhanced, not replaced
- **MapConfig flexibility** - Extended with event options
- **Zone system** - Leveraged for event placement
- **Dynamic scaling** - Built upon existing foundation

This enhanced approach delivers the core gameflow vision while building on proven, working systems. Each phase provides immediate value while setting up the foundation for the next level of features.

**Multi-Mind Enhancement Integration**: This system now incorporates proven 2024-2025 engagement patterns (PoE Atlas mastery system, transparent synergies, failure-forward design, flow state management) through additive enhancements that respect the existing deterministic architecture and performance constraints. The result is a best-in-class roguelike/ARPG hybrid that creates sustainable engagement without exploitative mechanics.

**Key Simplification**: Replaced complex event personality AI with player-controlled PoE Atlas-style mastery system - maintains strategic depth while eliminating AI complexity and providing direct player agency.