# Arena Progression & Stage System Vision

**Created:** 2025-09-29
**Status:** 🟢 Core Design Confirmed
**Philosophy:** MEGABONK-style risk/reward progression
**Goal:** Leaderboard kill maximization with skill-based risk management

---

## Final Confirmed Design

### Core Philosophy: MEGABONK-Style Progression

**Key Principles:**
- ✅ Rewards staying longer (more kills for leaderboard)
- ✅ Voluntary difficulty control (shrines)
- ✅ Higher difficulty = more spawns + better rewards
- ✅ Death = lose all run progress (survival paramount)
- ✅ Mathematical ceiling prevents infinite farming
- ✅ Multiple viable strategies (conservative to extreme)

---

## Complete Stage Flow

### Timeline (Based on MEGABONK Structure)
```
0:00 - Stage starts, normal spawning
1:30 - Rift spawns (visual marker, NOT functional yet)
3:00 - First Mini Boss spawns (mini-objective)
4:00 - Pressure Wave 1 (swarm phase)
6:00 - Pressure Wave 2 (more dangerous)
7:00 - Second Mini Boss spawns
8:00 - Main Boss spawns (must kill before 10:00)
9:30 - Optimal boss kill → Rift ACTIVATES (can enter anytime)
10:00 - Timer expires → FINAL SWARM begins
10:00-13:00 - Optional: Farm Final Swarm (rift still accessible)
11:00 - Black Ghosts phase (extreme danger signal)
13:00+ - Mathematical ceiling → Must enter rift or die
```

**MEGABONK Reference Timings (Tier 1 & 2):**
- 7:00 = First Mini Boss
- 6:00 = First Swarm
- 3:00 = Second Swarm
- 2:00 = Second Mini Boss
- 0:00 = Final Swarm
- -1:00 = Black Ghosts

**Our System (Adjusted for 10min timer):**
- Similar structure but adapted to our difficulty curve
- Mini bosses provide escalating challenges
- Black Ghosts at 11:00 (1 min into Final Swarm) = final warning

### Phase Breakdown

**Phase 1: Shopping (0:00 - 10:00)**
- Kill enemies to gather gold
- Open chests for upgrades (consistent spawn rate, fixed costs)
- Visit shrines (difficulty increases, power boosts)
- Pressure waves at 4min, 6min, 8min create escalating danger
- **Critical objective:** Kill boss before 10:00 timer

**Phase 2: Boss Fight**
- Boss spawns at X:XX (early enough for comfortable kill by 10:00)
- **Boss kill = unlock rift** (permanent access to portal)
- Difficulty snapshot at boss kill time
- Can activate rift immediately OR keep farming

**Phase 3: Final Swarm (10:00+)**
- Timer expires → overwhelming spawn rate + stat buffs
- **Only accessible if boss was killed** (otherwise stuck until death)
- Survivable for 2-4 minutes (skill/build dependent)
- Exponential scaling creates mathematical ceiling
- Rift portal remains available (can leave anytime)
- Used for leaderboard kill grinding

---

## Boss Kill Deadline Mechanic

**Critical Rule:** Boss must be killed BEFORE 10:00 timer expires

**Success Scenario:**
- Boss killed before timer → Portal unlocks permanently
- Can farm until Final Swarm starts (10:00)
- Can farm DURING Final Swarm (portal stays open)
- Enter portal anytime to progress to next stage

**Failure Scenario:**
- Timer expires before boss kill → Final Swarm begins
- Boss becomes extremely difficult or impossible
- No portal access → Stuck until death
- Run effectively over

---

## Difficulty Scaling System

### Difficulty Coefficient (ROR2-Style)

**What It Represents:**
- Global difficulty value that increases over time + stage progression
- Visual bar: Easy → Normal → Hard → Very Hard → INSANE...
- Affects: enemy stats, spawn rates, spawn budgets

**Scaling Effects:**
- **Enemy Health:** +30% per level
- **Enemy Damage:** +20% per level
- **Spawn rates:** Increase with coefficient
- **Spawn budgets:** More credits = more/stronger enemies

**Enemy Level Formula:**
```
enemyLevel = 1 + (coefficient - playerFactor) / 0.33
```

### Inter-Stage Progression

**Fixed Stage Jump:**
- Coefficient carries over between stages (cumulative)
- Fixed jump per stage: **+1.0 coefficient** (tunable)
- Independent of stage duration (same jump whether fast or slow)

**Example:**
```
Stage 1: Start at 1.0 → End at 5.0 (if stayed 8 minutes)
Stage 2: Start at 6.0 (5.0 + 1.0 jump) → End at 10.0
Stage 3: Start at 11.0 (10.0 + 1.0 jump) → Continue...
```

### Rift Event Scaling

**Snapshot Scaling:**
- Difficulty coefficient captured at rift activation time
- All rift enemies use snapshotted difficulty
- Boss difficulty based on coefficient when boss was killed
- Creates strategic timing decisions (early vs late activation)

**Example:**
- Kill boss at 5min (coeff 3.0) → Boss level ~7
- Kill boss at 9min (coeff 5.5) → Boss level ~14

---

## Pressure Systems

### Pressure Waves (Combat Escalation)

**Purpose:** Create escalating danger without complex economics

**Mechanics:**
- Wave 1 (4min): Elite enemies, increased spawn rate
- Wave 2 (6min): More elites, higher danger
- Wave 3 (8min): Very dangerous, signals urgency
- Waves stop when rift activated

**Benefits:**
- Simple to implement (leverage SpawnDirector)
- Clear danger signals
- Rewards player skill (handle pressure = more time)

### Final Swarm (Maximum Pressure)

**Purpose:** Absolute ceiling that prevents infinite farming

**Mechanics:**
- Triggers at 10:00 timer expiration
- Overwhelming spawn rate (enemies spawn on top of player)
- All enemy stats boosted
- Continuous until death or portal entry
- Survivable for 2-4 minutes (build/skill dependent)
- **Mathematical ceiling** around 13:00 (becomes impossible)

**MEGABONK's Final Swarm Details:**
- **Black Ghosts spawn** after -1:00 (one minute into swarm)
- **No XP gain** during Final Swarm (XP scaling stops)
- **Gold still drops** from kills
- Ghosts become faster and stronger over time
- Eventually kills all players (designed to end run)

**For Our System:**
- Should Final Swarm enemies give XP or just gold?
- Special enemy types in swarm (ghosts, enhanced variants)?
- Exponential difficulty increase creates natural end

**Strategic Use:**
- Optional leaderboard kill grinding
- High risk (death = lose run)
- High reward (more kills + gold)
- Requires strong AoE builds + sustain
- Not about progression (no XP) - pure survival test

---

## Risk/Reward Tiers

**1. Conservative (5-7 min boss kill)**
- Safe, reliable progression
- Moderate kill count
- Low death risk
- Good for learning/consistency

**2. Balanced (8-9 min boss kill)**
- More upgrades collected
- Higher kill count
- Moderate risk
- Optimal for most players

**3. Aggressive (9:30-9:59 boss kill)**
- Maximum pre-swarm upgrades
- High kill count
- High risk of missing deadline
- Requires skill + strong execution

**4. Extreme (Final Swarm farming)**
- Leaderboard maximization
- 2-4 extra minutes of kills
- Death risk extremely high
- Requires perfect build + mastery

---

## Leaderboard Strategy Diversity

**Multiple Paths to High Scores:**

**Path A: Stage 1 Grinding**
- Stay in Stage 1 as long as possible (up to 13min)
- Farm Final Swarm for maximum kills
- High risk, high reward
- Best for: AoE-focused builds

**Path B: Deep Progression**
- Progress efficiently through multiple stages
- Accumulate kills across 5-10+ stages
- More consistent, scales with skill
- Best for: Scaling/single-target builds

**Path C: Balanced**
- Moderate farming per stage
- Progress before Final Swarm
- Safe, repeatable
- Best for: Hybrid builds

**Character Build Implications:**
- AoE characters excel at stage grinding
- Scaling characters excel at deep progression
- Different builds = different optimal strategies
- Creates natural meta diversity

---

## Chest & Upgrade Economy

**Chest Spawning:**
- Consistent spawn rate (e.g., every 60 seconds)
- Fixed gold costs (25g, 50g, etc.)
- Random stat/ability boosts
- Paused during reward selection (no vulnerability)

**Shrines:**
- **Difficulty Shrines:** +5-8% difficulty (more spawns, better rewards)
- **Combat Shrines:** Spawn elite waves for gold
- **Other shrine types** (TBD - healing, rerolls, etc.)

**Gold Economy:**
- Earned from killing enemies
- Higher difficulty = more gold per kill
- No complex scaling or decay
- Simple, predictable

**Chests Blocked During Rift:**
- Shopping phase ONLY
- Rift phase = pure combat (no chest access)
- Prevents farming exploits

---

## Integration with Existing Systems

**MapLevel Autoload:**
- Tracks current difficulty coefficient
- Updates over time (continuous scaling)
- Adds stage jump on progression
- Provides coefficient to SpawnDirector

**SpawnDirector:**
- Uses difficulty coefficient for spawn decisions
- Manages pressure waves (4min, 6min, 8min)
- Triggers Final Swarm at 10:00
- Handles spawn budgets (Director Credits system - TBD)

**BossSpawnManager:**
- Spawns boss at designated time
- Scales boss based on coefficient
- Signals boss death to unlock rift

**EventBus Signals:**
- `boss_killed` → Unlock rift activation
- `timer_expired` → Trigger Final Swarm
- `rift_activated` → Snapshot difficulty, start rift event
- `stage_completed` → Add stage jump, generate new map

---

## Open Design Questions

**Boss Spawn Timing:**
- When should boss spawn? Options:
  - With rift at 1:30 (long boss fight time)
  - At 5:00 (moderate)
  - At 7:00 (creates urgency)
  - Immediately at stage start (always present)

**Rift Visual vs Functional:**
- Rift spawns at 1:30 as visual marker
- Becomes functional only after boss kill
- Or: Rift spawns when boss spawns?

**Difficulty Shrine Mechanics:**
- When can player activate shrines?
- How much difficulty increase? (+5%, +10%?)
- Permanent or per-stage?
- Rewards: More spawns? Better loot quality?

**Director Credits System:**
- How do spawn budgets work?
- How do credits accumulate?
- How are credits spent (enemy costs)?
- Integration with difficulty coefficient?

---

## Next Steps

**Priority 1: Core Mechanics**
- Define exact boss spawn timing
- Implement difficulty coefficient tracking
- Create Final Swarm spawn logic
- Build boss-kill → rift-unlock mechanic

**Priority 2: Balancing**
- Tune stage jump value (+1.0 starting point)
- Tune Final Swarm escalation curve
- Find mathematical ceiling timing (~13min target)
- Balance pressure wave difficulty

**Priority 3: Director System**
- Research ROR2 Director Credits mechanics
- Design spawn budget system
- Integrate with difficulty coefficient
- Create credit accumulation/spending logic

**Priority 4: Visual/UX**
- Difficulty bar UI (top right)
- Timer display
- Boss health bar
- Rift visual states (locked vs unlocked)
- Final Swarm visual indicators

---

## Design Rationale Summary

**Why MEGABONK Over ROR2:**
- Leaderboard = kill count optimization
- ROR2's "efficiency beats greed" contradicts leaderboard goals
- MEGABONK's "push your limits" aligns perfectly
- Multiple viable strategies = richer meta

**Why Boss Kill Deadline:**
- Creates clear objective (not just "activate when ready")
- Failure state has consequences (stuck in swarm)
- Success state enables risk-taking (farm Final Swarm safely)
- Clear skill expression (can you beat timer?)

**Why Mathematical Ceiling:**
- Prevents MEGABONK's "always max risk" problem
- Forces personal risk assessment (not universal strategy)
- Death = total loss → survival matters
- Creates build-dependent ceilings (AoE vs scaling)

**Why Fixed Stage Jumps:**
- Predictable progression difficulty
- Doesn't punish thorough play
- Easy to tune (single value)
- Fair for all playstyles

---

**Status:** 🟢 Core design locked. Ready for implementation planning and Director Credits research.