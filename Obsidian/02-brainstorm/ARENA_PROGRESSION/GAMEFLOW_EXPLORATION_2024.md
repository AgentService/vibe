# Gameflow & Progression System Brainstorm
*Created: 2024 | Status: Exploration Phase*

## Current Challenge
- Pack spawning overlaps create messy gameplay
- No clear player objectives or strategic positioning
- Missing progression system with meaningful milestones
- Need engaging, addictive gameflow that motivates continuous play

## Core Questions to Explore

### 1. Player Motivation & Experience ✅
**What drives the player to keep playing for hours?**
- Frantically dodging overwhelming enemy swarms while character grows more powerful
- Gradual escalation building to epic boss confrontations with stronger enemies
- Completing events fast enough to get better rewards (time pressure creates urgency)
- Build choices feeling good and making progress toward build vision

**What creates the "just one more run" feeling?**
- Wanting to kill stronger enemies and face bigger challenges
- Exploration of build progression options - "what comes next?"
- Progress in map tier system for better rewards
- Meta level progression to unlock special passives/skills/builds
- Finding more/better items for current or future builds
- Unlocking new characters or advancing character meta progression

**What makes the player feel powerful and progressing?**
- Dual progression: immediate build power + long-term meta unlocks
- Build synergies coming together and feeling impactful
- Successfully handling stronger enemy waves
- Completing events efficiently for maximum rewards
- Unlocking new passive abilities and build-enabling skills

### 2. Pacing & Rhythm ✅
**How fast should the game escalate in difficulty?**
- Continuous wave spawning for constant low-mid pressure baseline
- Smooth scaling throughout the run (no sudden jumps)
- Spikes in intensity at event zones
- 30-second preparation window at start (with indicator) so player can scale before first event

**Should there be breathing room, or constant pressure?**
- Player should get swarmed always, but degree varies
- Brief preparation periods (15-30s) between events
- Maybe overwhelm spikes before level tier increases or during event endings
- Constant pressure with intensity variations rather than full breaks

**Event Timing & Flow:**
- Events appear 30-60 seconds after one is completed
- Alternative: Events spawn on timers at different map locations (multiple active)
- Events only start when player enters area or activates them
- Missing events = less reward (time pressure) rather than punishment
- Question: How to handle multiple simultaneous events vs sequential?

### 3. Objectives & Goals ✅
**Event System Design - PoE League Mechanic Style:**
- **Scenario B**: Multiple simultaneous events across different zones
- **Player Choice**: Select events based on preference, rewards, or current build needs
- **One Event Active**: Player tackles one at a time, others wait
- **Random Event Types**: Variety like PoE (Abyss, Breach, Ritual, Delirium style)

**Event Zone Types:**
1. **Strong Pack Defeat**: Eliminate challenging enemy group for rewards
2. **Defend Objective**: Protect something while under attack
3. **Collection/Activation**: Gather objectives under pressure
4. **Mini-Boss Encounter**: Special boss with unique mechanics

**Strategic Decisions During Events:**
- **Time Pressure**: "Clear this fast to maximize reward"
- **Risk/Reward**: "Harder event = better rewards, can I handle it?"
- **Build Synergy**: "This event type suits my current build"

**Progression Focus:**
- Events = main driver to get stronger during the run
- Meta progression = long-term advancement between runs
- Build assessment happens through event success/failure

### 4. Spawn System Philosophy ✅
**Baseline + Event Spawn System:**
- **Option B**: Baseline continuous spawning continues during events
- **Flexible Event Control**: Some events can create "no-spawn zones" to stop auto-spawning when needed
- **Event-Specific Behavior**: Events can either disable proximity spawning OR let it continue normally

**Pre-Spawned Pack System:**
- **Map Tier Scaling**: Pre-spawned packs scale with map level progression
- **Hybrid Approach**: Keep both pre-spawned packs AND events
- **Pack Composition**: 1 rare + magic/normal monsters around (radar shows rare)
- **Location Strategy**: Pre-spawned packs avoid event locations
- **Alternative Consideration**: Replace all pre-spawning with pure event system

**Spawn Proximity & Player Location:**
- Proximity-based auto-spawning as baseline pressure
- Event zones can override proximity rules when needed
- Player movement affects baseline spawning but events are location-fixed

### 5. Progression Triggers ✅
**Map Tier Advancement:**
- **Time-Based**: ~15 minutes per map tier (predictable escalation)
- **No Hybrid Bonus**: Completing events faster shouldn't accelerate tier progression
- **Anti-Gaming**: Events must give superior XP/rewards to prevent "wait and farm waves" strategy
- **Event Priority**: Events should always be more rewarding than baseline wave farming

**When Map Tier Increases:**
- **All Enemies Scale**: Immediate stat boost for all enemies
- **Scaling Method**: TBD - current enemies boost vs only new spawns vs reset all
- **New Enemy Types**: Higher tiers unlock different enemy varieties
- **Better Reward Pools**: Each tier has improved drop tables
- **Event Types**: May unlock new event mechanics (or keep random throughout)

**Incentive Structure:**
- Events give more XP/rewards than wave farming
- Fast event completion = more events per tier = more rewards overall
- No timing manipulation strategies should be viable

### 6. Reward Psychology ✅
**IN-RUN Progression (During Current Session):**
- **No Temporary Items** (avoided complexity)
- **Current Card System**: Straightforward, easy to implement
- **Alternative: Point-based Skill Enhancement**: Currency to enhance skills/passives during run
- **Meta Progression Slot Activation**: Unlock meta-progression slots that can be enhanced each run
- **Stat Boosts**: Compatible with build currency or card system approaches
- **Immediate Power**: Yes - player should feel stronger right after completing event

**META Progression (Between Runs in Hideout):**
- **Character Unlocks**: Not for now (focus on 2 current characters)
- **Permanent Passives**: Character-wide passive tree (PoE-style)
- **Abilities**: Complex system requiring separate deep dive
  - Option A: Linked to passive tree
  - Option B: Dual trees (1 passive, 1 skill)
  - Option C: Abilities drop randomly + support gem system + meta unlocks
- **Equipment Unlocks**: Better equipment through map tier progression
  - Higher tier maps start harder, give better rewards
  - New tiers unlock better items/upgrade types

**Reward Timing:**
- **Immediate**: Power increases during run (cards/points/stat boosts)
- **Delayed Gratification**: Meta passive choices only after run ends
- **Trigger System**: In-run events unlock ability to spend meta progression after run

**Design Constraints & Challenges:**
- **15-minute timer-based maps**: Removes completion speed as reward variable
- **Easy UI requirement**: Simple decisions, easy to understand systems
- **Balance challenge**: Maps shouldn't be completed on first try every time
- **Avoid frustration**: Failing runs repeatedly shouldn't feel punishing
- **Meta-influence on cards**: Meta progression should impact card options (not pure RNG)
- **Originality concern**: Card system used often in other games, need fresh approach?

**Preferred Systems Direction:**
- **In-Run**: Card system or 4 improvable in-run passives (reset after run)
- **Meta**: Experience-based progression, but needs reward mechanism beyond completion time
- **Event Unlock Tokens**: Very interesting - motivates maximum event completion
- **Hybrid Currency**: Also promising approach for dual progression

**Dynamic Difficulty Solution:**
- **Same Map, Scaling Difficulty**: Maps auto-scale after completion (no need for many maps)
- **Failing as Progression**: Failed runs are normal/expected part of progression path
- **Performance-Based Scaling**: Better performance = more XP/faster meta progression
- **Skill Reward Loop**: Advanced players with low meta progression get bonus XP
- **Natural Gating**: Map timer prevents infinite farming, events create progression variance

**Meta Progression Philosophy:**
- **Expected Failure**: Players expected to fail maps before building up enough meta progression
- **Performance Rewards**: Distance reached + events completed + efficiency = XP multipliers
- **Catch-up Mechanics**: Strong players get accelerated progression when behind
- **Gradual Scaling**: Player build choices + meta progression vs map scaling determines success

## Potential Gameflow Approaches

### Approach A: Event-Driven Exploration
**Core Loop**: Move → Find Event → Clear Event → Get Reward → Repeat
-

**Pros**:
-

**Cons**:
-

### Approach B: Territory Control
**Core Loop**: Claim Zone → Defend Zone → Expand Territory → Face Counterattack
-

**Pros**:
-

**Cons**:
-

### Approach C: Wave Defense Evolution
**Core Loop**: Survive Wave → Brief Respite → Stronger Wave → Boss Phase
-

**Pros**:
-

**Cons**:
-

### Approach D: Hunt & Escalation
**Core Loop**: Hunt Targets → Kill Elite → Trigger Escalation → Survive Chaos
-

**Pros**:
-

**Cons**:
-

### Approach E: [Your Custom Idea]
**Core Loop**:
-

**Pros**:
-

**Cons**:
-

## Key Design Principles to Consider

### Engagement Factors
- **Mastery**: Can players improve their skill over time?
- **Variety**: Does the experience stay fresh across sessions?
- **Choice**: Do players have meaningful decisions to make?
- **Feedback**: Is progress clearly communicated?

### Flow State Requirements
- **Clear goals**: Player always knows what to do next
- **Immediate feedback**: Actions have visible consequences
- **Challenge balance**: Difficult enough to engage, not frustrate
- **Sense of control**: Player feels agency over outcomes

## Technical Architecture Questions

### Core Systems Needed
**What are the minimum systems required for any approach?**
-

**What systems are specific to certain approaches?**
-

**How can we build flexible foundations that support multiple approaches?**
-

### Data-Driven Design
**What should be configurable in .tres files?**
-

**What needs to be hardcoded vs. data-driven?**
-

**How do we balance flexibility with simplicity?**
-

## Next Steps
1. Answer core questions above
2. Identify common architectural patterns
3. Design minimal MVP that tests core assumptions
4. Build iterative foundation for experimentation

---

## Brainstorm Sessions
*Use this section to capture ideas and discussions*

### Session 1: [Date]
**Topic**:
**Key Insights**:
-

**Decisions Made**:
-

**Questions for Next Session**:
-