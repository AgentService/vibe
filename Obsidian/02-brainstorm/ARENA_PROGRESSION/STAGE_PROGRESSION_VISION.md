# Arena Progression & Stage System Vision

**Created:** 2025-09-29
**Status:** 🟡 Active Brainstorming
**Reference:** [Risk of Rain 2 Difficulty](https://riskofrain2.fandom.com/wiki/Difficulty)
**Related Task:** [Map Level Difficulty Scaling](../../03-tasks/03_COMBAT_map_level_difficulty_scaling_integration.md)

## Core Vision Elements (Initial)
- **Procedural map generation** creates distinct stages
- **Stage completion** triggers portal/boss encounter
- **New stage = new generation + difficulty jump** (ROR2-style)
- **Visual progression** via tile color modulation
- **No revive system** - death = game over with results screen
- **Difficulty bar progression** similar to ROR2

---

## Q&A Exploration

### Question 1: Stage Structure & Flow
**Q:** How do you envision the basic flow? Is it: Arena → Boss/Portal → New Arena → Repeat?

**A:** Portal → New Generation → Difficulty jump (top right bar like ROR2) → **INFINITE STAGES** possible with procedural generation

**Key Insight:** Unlike ROR2's fixed 8-stage loop, procedural generation enables unlimited progression!

### Question 2: Stage Completion Triggers
**Q:** What determines when a stage is "complete" and the portal/boss appears? Time-based? Enemy kill count? Objective-based?

**A:** EXPLORING OPTIONS:

**Option A: ROR2 Style - Player Choice**
- Portal spawns after 90 seconds minimum
- Player decides when to activate (risk vs reward)
- Staying longer = more loot but exponentially harder enemies

**Option B: Escalation Pressure**
- Portal appears when MapLevel difficulty reaches dangerous threshold
- Forces progression before enemies become impossible
- Creates natural "escape hatch" timing

**Option C: Objective Gates**
- Kill elite/mini-boss to spawn portal
- Clear specific enemy count or survive wave patterns
- More structured progression with clear goals

**SELECTED:** Option A - Pressure Portal System
- Portal spawns after 90 seconds minimum
- MapLevel difficulty continues climbing while available
- Portal glows more urgently as difficulty increases
- No hard cutoff - skilled players can push further

**KEY QUESTION:** How does the risk/reward balance actually work?

### Question 3: Risk/Reward Balance Mechanics
**Q:** How do we create the ROR2-style tension between staying for rewards vs escaping before difficulty outscales you?

**ROR2 Analysis:**
- **Limited chests per stage** (~8-12 fixed spawns)
- **Exponential difficulty scaling** (+30% enemy stats per minute)
- **Linear power growth** (one item = one boost)
- **Gold from kills** decreases as enemies get tankier
- **Sweet spot window** exists before math turns against you

**For Our System:**
- What are the limited resources per arena? (Chests? Elite enemies? XP sources?)
- How does our MapLevel scaling compare to enemy power gained?
- Should distant rewards become harder to reach as difficulty climbs?
- How does staying longer affect the NEXT stage difficulty?

**A:** EXPLORING MECHANICS:

**Chest System:**
- Random chests spawn during procedural generation
- Gold cost to open (earned from killing enemies)
- Random boosts to specific stats/abilities
- Shrines with different effects

**PROBLEM IDENTIFIED:** Arena may be too small for "distance = risk" mechanic

**ROR2 Enemy Spawning Answer:**
- **Hybrid system:** Initial wave + continuous escalating spawns
- **Spawn rate increases** with difficulty over time
- **Enemy types escalate** (stronger variants appear)
- **Director system** manages spawn pressure and budgets

**Small Arena Solutions:**
1. ~~**Interaction Time Risk:** Chests take 3-5 seconds to open = vulnerability window~~ ❌ **REJECTED - Game pauses during reward selection**
2. **Spawn Pressure:** Enemy spawn rate increases while looting
3. **Elite Guards:** Valuable chests spawn elite enemies nearby
4. **Resource Scarcity:** Limited gold forces harder choices about which chests to buy

**CONSTRAINT IDENTIFIED:** Game pauses when selecting rewards - eliminates interaction vulnerability

**CORE GAMEPLAY LOOP CLARIFIED:**
- Kill enemies to gather gold
- Use gold to open chests for upgrades
- Visit shrines for power boosts
- Trigger events to spawn more enemies (more gold/rewards)
- Scale efficiently to stay ahead of difficulty curve
- Choose optimal time to activate portal

**KEY QUESTION:** In ROR2's Option A system, why ISN'T it always best to wait until the last possible second to activate the portal?

**FOLLOW-UP QUESTION:** Why are early chests cheap and later chests expensive in ROR2 when they're pre-spawned?

**ANSWER:** Chest costs are FIXED - the "expensive" feeling comes from gold income declining as enemies get tankier

**CRITICAL QUESTION:** Enemies get tankier but players also get stronger - so why does efficiency decline?

**ANSWER:** Exponential enemy scaling vs linear player progression creates mathematical tipping point

**NEW PROBLEM:** With smaller arenas and pre-spawned chests - what prevents player from just opening everything before boss?

**ROR2 GOLD MECHANICS RESEARCH:**
- Gold converts to XP when leaving stage (2:1 ratio)
- Enemy gold values vary by spawn timing:
  - Pre-spawned enemies: Lowest value
  - Natural spawns during exploration: Highest value
  - Teleporter event spawns: Lower value
  - Shrine of Combat spawns: Highest value
- **Optimal strategy:** Wait to start teleporter until funding goal almost met

**KEY INSIGHT:** Enemy spawn timing affects gold value - creates incentive to farm "fresh" spawns

**ROR2 TELEPORTER TIMING EXPLANATION:**
"Wait to start teleporter until funding goal almost met" means:
- You explore/farm enemies BEFORE starting teleporter event
- Once teleporter starts: must stay in radius + enemies give less gold
- **Funding goal** = have enough gold to buy what you want
- Start too early = stuck farming low-value teleporter enemies
- Start too late = wasted time, could have moved to next stage already

**FUNDING GOAL CONCEPT:** Calculate how much gold you need for remaining chests/shrines, then start teleporter when you're close to that amount

**"FUNDING GOAL ALMOST MET" MEANS:**
- Example: 3 chests remaining × 25 gold each = 75 gold needed (your funding goal)
- You currently have 65 gold
- "Almost met" = you're close enough (65/75 = 87% there)
- You can earn the missing 10 gold quickly during teleporter phase
- Don't need to farm much more before starting teleporter

**CRITICAL QUESTION:** Gold for what exactly? Does player still need to physically reach chests after activating teleporter? What if chests are too far from teleporter radius?

**ROR2 WIKI RESEARCH ANSWER:**
- **YES, chests can be opened during teleporter event**
- Chests become "locked with orange tendrils" during teleporter but remain functional
- The limitation is **movement restriction** (must stay near teleporter radius)
- **Real constraint:** Physical distance + enemy pressure, not mechanical restriction

**CORRECTED STRATEGY:** "Funding goal almost met" works because you CAN open nearby chests during teleporter phase, but distant chests require risky movement outside safe radius

**ROR2 TELEPORTER MECHANICS (CONFIRMED):**
- **Leaving teleporter area = charging slows down** (not death/failure)
- Minimum 90 seconds if all players stay in red dome constantly
- **Time penalty** for leaving area, not mechanical restriction
- **Real tension:** Faster completion vs distant chest rewards

**THE ACTUAL RISK/REWARD:** Leave dome for distant chest = extend teleporter phase = more enemy spawns = higher danger over time

**ENEMY SPAWN MECHANICS DURING TELEPORTER:**
- **Enemies continue spawning until 99% charged** (regardless of player position)
- Spawns occur **within the red dome area** (120m diameter)
- **Player leaving zone = slower charging = MORE total spawns** before completion
- Spawning stops only at 99% completion

**CONFIRMED FORMULA:** Leaving zone = Extended time = More total enemy spawns = Exponentially harder survival

**CRITICAL QUESTION:** If leaving zone = more enemy spawns = more gold opportunities, wouldn't staying outside always be beneficial? How does ROR2 prevent this exploit?

**SIMPLE SOLUTION PROPOSED:** Block all chests once teleporter is activated

**WHY THIS WORKS:**
- Eliminates "farm extra enemies for chest gold" incentive
- Forces all shopping decisions BEFORE teleporter activation
- Makes teleporter phase purely about survival, not resource gathering
- Prevents infinite farming exploits completely

**CONFIRMED APPROACH:** Two-phase system with blocked chests during rift
- ✅ Shopping phase can end before collecting everything (player choice)
- ✅ Creates strategic timing decisions
- ✅ Clean separation of exploration vs survival
- ✅ **90 seconds for rift activation** (confirmed timing)
- ✅ **Alternative terminology:** "Rift charging" instead of "teleporter"

---

## Next Design Challenges (Noted for Future)

### 🔄 **Intra-Stage Progression Balance**
**Key Question:** How do we scale enemies with player upgrades within a single stage?

**The Challenge:**
- Player gets stronger from chests/shrines during shopping phase
- Enemy difficulty increases over time via MapLevel
- **Need balance:** Player power growth vs enemy scaling within same stage
- **Risk:** Player becomes too powerful OR enemies become impossible

**Design Considerations:**
- Should enemy scaling account for expected player upgrades?
- How do we handle players who get lucky/unlucky with upgrade RNG?
- Does MapLevel scaling need to be aware of chest availability?
- Should there be minimum/maximum difficulty bounds per stage?

**Integration with Existing Systems:**
- Your MapLevel autoload already handles time-based scaling
- SpawnDirector manages enemy spawn rates and pressure
- EnemyFactory handles stat variations within templates
- **Question:** How does stage-based progression layer on top of these?

**Status:** 🟡 Identified but not yet explored - important for overall balance

---

## Vision Development Log

### Session 1: Core Mechanics Design (2025-09-29)
**Explored:** ROR2 progression mechanics, teleporter/rift system, risk/reward balance

**Key Decisions Made:**
1. ✅ Infinite procedural stages (no looping limit)
2. ✅ Two-phase system: Shopping → Rift Charging (90s)
3. ✅ Player-controlled activation timing (rift spawns after 90s minimum)
4. ✅ Chests blocked during rift phase (prevents farming exploits)
5. ✅ Clean separation: exploration vs survival phases
6. ✅ Player can leave rewards uncollected (strategic choice)

**Key Insights from ROR2 Analysis:**
- Exponential enemy scaling vs linear player progression creates tension
- Variable gold value by spawn timing (exploration > rift spawns)
- "Funding goal" strategy: activate when ~87% ready, not 100%
- Blocking chests during rift eliminates all farming exploits

**Open Questions for Next Session:**
- How does difficulty scale WITHIN a single stage?
- How does difficulty scale BETWEEN stages?
- What rewards/upgrade types are available?
- How does player power growth compare to enemy scaling?
- Integration with existing MapLevel/SpawnDirector systems

---

---

## New Focus: Difficulty Scaling & Integration

### Question 4: Difficulty Indicator & Scaling System
**Q:** How does the difficulty indicator (top-right bar) work and tie into the overall progression system?

**Topics to Explore:**
1. **Difficulty Indicator (ROR2 style bar)**
   - What does the bar represent?
   - How does it scale over time?
   - Does it reset between stages or carry over?
   - How does stage number affect baseline difficulty?

2. **Inter-Stage Difficulty Jumps**
   - How big is the difficulty jump between stages?
   - Stage 1 → Stage 2 → Stage 3... what's the progression curve?

3. **Rift Event Enemy Scaling**
   - Do rift enemies match difficulty at activation time?
   - Or do they continue scaling during the 90s event?
   - Are rift enemies harder than shopping phase enemies?

4. **Boss Scaling**
   - Boss spawns when rift reaches 99%
   - Early activation (e.g., 2 minutes) → easier boss?
   - Late activation (e.g., 8 minutes) → harder boss?
   - How does boss scale relative to difficulty bar?

5. **Upgrade Philosophy**
   - Player wants MANY upgrades (lots of choice)
   - Multiple chests per stage (8-12+ like ROR2?)
   - Creates meaningful build variety

6. **Credit/Budget System Integration**
   - ROR2 uses "Director Credits" for spawning
   - Credits accumulate over time
   - Spent to spawn enemies (cheap = weak, expensive = strong)
   - How does this tie into difficulty scaling and timer?

**Status:** 🟡 Ready to explore - critical for tying all systems together

---

### ROR2 Difficulty System Research

**What the Difficulty Bar Represents:**
- Global "difficulty coefficient" that increases over time + stage progression
- Visual labels: Easy → Normal → Hard → Very Hard → HAHAHAHA (max level 99)
- **Not a simple timer** - it's a compound formula

**ROR2 Difficulty Coefficient Formula:**
```
coefficient = f(players, time_elapsed, stages_completed, initial_difficulty)
```

**Enemy Level Formula:**
```
enemyLevel = 1 + (coefficient - playerFactor) / 0.33
```

**Scaling Effects:**
- **Enemy Health:** +30% per level
- **Enemy Damage:** +20% per level
- **Spawn rates:** Faster and more complex
- **Interactable costs:** Exponential increase
- **Enemy rewards:** Scale with coefficient (XP and gold)

**Key Insight:** Difficulty is NOT just time-based - it compounds with stages completed!

**DECISION: Use ROR2-style compound difficulty system**
- ✅ Difficulty coefficient carries over between stages (no reset)
- ✅ Creates exponential pressure over multiple stages
- ✅ Matches ROR2's proven formula

**Inter-Stage Difficulty Jump Options:**

**Option A: Percentage of Current Progress**
- Stage completion adds ~10% of current coefficient
- Example: End Stage 1 at coeff 4.0 → Start Stage 2 at 4.4
- **Scales naturally** - early stages = small jumps, late stages = big jumps

**Option B: Fixed Time Equivalent**
- Stage completion = "as if you played 1 more minute"
- Example: Stage 2 starts at coeff equivalent to +60 seconds
- **Consistent feeling** - each stage always feels like same time penalty

**Option C: Hybrid Approach**
- Base jump (e.g., +0.5 coefficient) + percentage scaling
- Ensures minimum difficulty increase even on fast clears
- Example: +0.5 + (10% of current coeff)

**Question:** Which approach feels right for the pacing you want?

**ROR2 Time Limit Answer:**
- ❌ **NO hard time limit** per stage in ROR2
- ✅ **Soft cap via exponential difficulty** - enemies eventually become impossible
- ✅ **Natural pacing** - player skill/risk tolerance determines stage duration

**CONFIRMED APPROACH: Fixed Stage Jump**
- ✅ DON'T use percentage-based jumps (too variable)
- ✅ DO use small **fixed coefficient increase** per stage
- ✅ **Independent of stage duration** - same jump whether you speedrun or farm
- ✅ Examples: +0.2, +0.5, +1.0 coefficient per stage (to be tuned)

**Simplified Formula:**
```
Stage 1: coefficient 1.0 → climbs over time → ends at X
Stage 2: coefficient (X + FIXED_JUMP) → climbs over time → ends at Y
Stage 3: coefficient (Y + FIXED_JUMP) → climbs over time → ends at Z
```

**Proposed Starting Value:** +1.0 coefficient per stage
- Significant but not brutal
- Easy to tune up/down based on playtesting
- Creates clear progression pressure without punishing thorough players

---

### Shopping Phase Duration & Chest Economics

**Challenge Identified:** Small maps + respawning chests = potential infinite farming

**ROR2 Difference:**
- ROR2: Limited chests (~8-12) per large map → natural depletion forces progression
- Our System: Smaller maps + need chest respawning → risk of infinite stalling

**Proposed Solutions:**

**Option 1: Maximum Stage Duration (Soft Cap)**
- Rift spawns at 90 seconds (earliest activation)
- **Latest activation deadline** at X minutes (e.g., 8-10 minutes)
- Player chooses timing within this window
- Forces progression, prevents indefinite farming

**Option 2: Chest Spawn Rate Decay**
- Chests spawn frequently early (every 30-60s)
- Spawn rate **decreases over time** (every 90s, then 120s, then 180s...)
- Eventually: waiting for chests becomes worse than progressing
- Natural incentive to activate rift rather than wait

**Option 3: Escalating Chest Costs**
- First few chests: 25 gold (affordable)
- Later chests: 50g → 100g → 200g (exponential)
- Gold income from enemies increases, but **chest costs increase faster**
- Diminishing returns create natural "I'm done shopping" point

**Option 4: Hybrid Approach**
- Chest spawn rate slows over time (Option 2)
- + Chest costs scale (Option 3)
- + Soft deadline at 10 minutes (Option 1)
- Multiple pressure points guide player toward rift activation

**Gold Income Consideration:**
- More/harder enemies = more gold earned
- If chest costs are FIXED, farming becomes infinite profit
- If chest costs SCALE FASTER than gold income → diminishing returns
- **Key question:** Should chest #10 cost more than chest #1?

**Option 5: Simplest Solution - Pressure Waves**
- ✅ Keep chest spawning SIMPLE (no decay, no cost scaling)
- ✅ Add **dangerous pressure waves** over time
- ✅ Waves create survival challenge, not economic pressure
- ✅ **Waves STOP when rift activated** → incentive to progress
- ✅ Much less balancing complexity

**How it works:**
- Chests spawn consistently throughout (e.g., every 60 seconds)
- Normal enemy spawning continues
- **At 4 minutes, 6 minutes, 8 minutes:** Special pressure wave spawns
- Pressure waves = elite enemies, higher density, dangerous
- Activating rift = escape from pressure waves

**Benefits:**
- ✅ No complex economic math to tune
- ✅ Clear danger signal ("things are getting scary, leave soon!")
- ✅ Leverages existing SpawnDirector system
- ✅ Player feels pressure from combat, not artificial timers
- ✅ Rewards player skill (can handle pressure = more chests)

**Comparison:**
- Hybrid (Option 4): Complex, lots of tuning, economic pressure
- Pressure Waves (Option 5): Simple, clear feedback, survival pressure

**CONFIRMED: Option 5 - Pressure Waves System**
- ✅ Simple chest spawning (consistent rate, fixed costs)
- ✅ Pressure waves at timed intervals (4min, 6min, 8min)
- ✅ Waves stop when rift activated
- ✅ Combat-focused pressure, not economic complexity
- ✅ Leverages existing SpawnDirector system

---

### Question 5: Rift Event Enemy Scaling

**Key Questions:**
1. Do rift enemies **snapshot difficulty** at activation time?
   - Example: Activate at 3 minutes → all rift enemies use coefficient 2.5

2. Or do rift enemies **continue scaling** during the 90s event?
   - Example: Activate at 3 minutes → enemies start at 2.5, reach 4.0 by end

3. Are rift enemies **inherently harder** than shopping phase enemies?
   - Same stats but more dense spawning?
   - Stat boost (e.g., +20% HP/damage)?
   - More elite variants?

**Design Implications:**

**Snapshot Scaling (Option A):**
- ✅ Rewards early activation (easier rift event)
- ✅ Punishes greed (late activation = hard rift)
- ✅ Clear risk/reward trade-off
- ❌ Might feel unfair if you barely survived to reach rift

**Continuous Scaling (Option B):**
- ✅ Consistent challenge regardless of activation time
- ✅ Always feels "appropriately hard"
- ❌ Removes activation timing strategy
- ❌ No reward for efficient shopping

**ROR2 Research Findings:**
- Boss spawns based on "difficulty and number of players"
- Director uses credits system that scales with coefficient
- Difficulty continues increasing during teleporter event
- **Unclear from documentation:** Exact snapshot timing

**Community Wisdom:**
- Players discuss "rushing teleporter vs farming" strategies
- Early activation = easier boss fight (common advice)
- This suggests **snapshot scaling** at activation time
- Otherwise rushing wouldn't matter

**DECISION NEEDED:** Choose between Option A (Snapshot) or Option B (Continuous)

**CONFIRMED: Snapshot Scaling (Option A)**
- ✅ Creates meaningful activation timing decisions
- ✅ Rewards risk-taking (late activation = harder challenge)
- ✅ Multiple viable strategies (speed vs farming)
- ✅ Simple to implement: capture coefficient at activation

**Boss Difficulty Scaling:**
- Early activation (3min, coeff 2.5) → Boss at level ~5
- Late activation (7min, coeff 5.0) → Boss at level ~12
- **Both strategies viable for leaderboard competition**

---

### MEGABONK Comparison Research

**MEGABONK's Difficulty System:**
- **Difficulty is a stat** you can actively increase (not just time-based)
- **Time scaling:** Mobs scale over time (boss: 8k HP early → 30k+ HP late)
- **Stage jumps:** Tier 1 → Tier 2 = massive difficulty spike (20k → 500k boss HP)
- **Player choice:** Can increase difficulty via shrines (+5% or +8%)
- **Reward scaling:** Higher difficulty = more XP and gold

**Key Difference from ROR2:**
- MEGABONK: **Encourages increasing difficulty** (better rewards)
- ROR2: **Punishes staying too long** (exponential danger)

**MEGABONK's Philosophy:**
- ✅ Active difficulty control (shrines, curses)
- ✅ Higher risk = higher reward (XP/gold scales)
- ✅ "Holy Trinity" combo = exponential power growth possible
- ✅ Rewards aggressive play and risk-taking

**ROR2's Philosophy:**
- ✅ Passive difficulty increase (time pressure)
- ✅ Efficiency beats greed (exponential danger)
- ✅ Teaches "get in, get out" gameplay
- ✅ Rewards speed and smart exits

**Question for Your System:** Which philosophy fits better?
- **MEGABONK style:** Reward players for staying longer / taking risks?
- **ROR2 style:** Punish greed, reward efficiency?
- **Hybrid:** Some of both?

**CRITICAL INSIGHT: Global Leaderboard Changes Everything**

**If tracking "Most Kills" on leaderboard:**
- ROR2 style = Speed-running dominates (low kill counts, fast exits)
- MEGABONK style = **Encourages staying longer for more kills**
- **MEGABONK philosophy aligns with leaderboard goals!**

**Leaderboard Impact Analysis:**

**With ROR2 "Efficiency" Philosophy:**
- ❌ Optimal play = fast clears (minimize kills, maximize survival)
- ❌ Leaderboard rewards avoidance, not engagement
- ❌ Contradictory goals: "leave early" vs "get most kills"
- ❌ Speedrunners dominate by avoiding combat

**With MEGABONK "Risk/Reward" Philosophy:**
- ✅ Optimal play = stay longer, take risks, maximize kills
- ✅ Leaderboard rewards engagement and skill
- ✅ Aligned goals: "push your limits" for high scores
- ✅ Voluntary difficulty increases = more spawns = more kills

**MEGABONK Features to Consider:**
1. **Voluntary difficulty shrines** (+5-8% difficulty)
   - Higher difficulty = more enemy spawns = more kill potential
   - Rewards players who can handle the pressure

2. **Reward scaling with difficulty**
   - Higher difficulty = better gold/XP per kill
   - Compensates for increased danger

3. **"How far can you push?" mentality**
   - Leaderboard becomes skill showcase
   - High scores require mastering risk management

**CONFIRMED DECISION: MEGABONK-style progression**
- ✅ Rewards staying longer (more kills)
- ✅ Voluntary difficulty control (shrines)
- ✅ Higher difficulty = better rewards + more spawns
- ✅ Aligns with leaderboard competition
- ✅ Still has pressure waves to create tension

**This changes the design!**

**LEADERBOARD INSIGHT:**
- Multiple paths to high kill counts: Stage 1 farming vs deep progression
- Different character builds optimize for different strategies
- AoE builds: early-stage farming specialists
- Scaling builds: deep progression specialists
- Creates natural meta diversity

**CRITICAL DESIGN CHALLENGE:**
**How to prevent "Stage 1 farming is always optimal" problem?**

**The Risk:** If staying in Stage 1 is too safe/rewarding, all leaderboard runs become "farm Stage 1 forever"

**Needed Pressure Mechanisms:**
- Exponential difficulty must eventually overtake player power
- Pressure waves need to be genuinely dangerous
- Diminishing returns on kill-per-minute as time increases?
- Enemy HP scaling faster than player DPS scaling?

**MEGABONK's Solution: "Final Swarm" Mechanic**

**How MEGABONK Forces Progression:**
1. **Stage timer** - Each stage has a time limit
2. **Time-based scaling** - Enemy stats increase continuously (8k HP → 30k+ HP)
3. **Final Swarm trigger** - When timer expires:
   - Overwhelming enemy spawn rate (spawn right next to player)
   - All enemy stats cranked up (HP, damage, speed)
   - Portal activates (escape or die)
   - Spawn rate "insane after 1:30m" into Final Swarm

**The Pressure:**
- You CAN stay longer (voluntary risk-taking)
- But eventually Final Swarm makes survival impossible
- Timer creates "soft ceiling" - can farm until timer expires
- Final Swarm creates "hard ceiling" - must leave or die

**Translated to Our System:**

**Option A: Direct Copy (Final Swarm)**
- Stage timer (e.g., 10 minutes)
- When timer expires → "Overwhelming Swarm" event
- Massive spawn rate spike + stat buffs
- Portal activates, player must escape or die
- Clear escalation signal

**Option B: Pressure Wave Evolution**
- No hard timer, pressure waves escalate naturally
- Wave 4+ become "proto-Final Swarm"
- Eventually waves overlap and become continuous
- Creates same pressure without artificial timer

**CONFIRMED: Final Swarm Mechanic**
- ✅ Stage timer (8-10 minutes)
- ✅ Rift spawns at 90 seconds (early activation option)
- ✅ Final Swarm triggers when timer expires
- ✅ Swarm = overwhelming spawn rate + stat buffs
- ✅ Forces portal activation or death
- ✅ Prevents "farm Stage 1 forever" exploit

**Timeline:**
```
0:00 - Stage start
1:30 - Rift spawns (earliest activation)
4:00 - Pressure Wave 1
6:00 - Pressure Wave 2
8:00 - Pressure Wave 3
10:00 - FINAL SWARM BEGINS (timer expires)
10:00-11:30 - Must activate rift or die
```

**MEGABONK Final Swarm Clarification:**
- **Final Swarm = infinite duration** (continues until death)
- **Triggered when stage timer expires** (e.g., 10 minutes)
- **Boss must be killed BEFORE timer expires** to activate teleporter/portal
- **If timer expires BEFORE boss kill:** Stuck in Final Swarm until death
- **Progression path:** Kill boss → Portal opens → Enter next stage
- **Final Swarm = end-of-run phase** for kill grinding/silver farming

**MEGABONK's Critical Mechanic:**

**You must kill boss BEFORE timer expires to unlock portal**

**Scenario A: Boss killed before timer (SUCCESS)**
- Boss dies → Portal appears
- Can enter portal immediately OR keep farming
- Timer still running
- Portal available even after timer expires
- Can farm in Final Swarm then enter portal anytime
- **Progression always available once boss is dead**

**Scenario B: Timer expires before boss kill (FAILURE)**
- Final Swarm begins
- Boss becomes much harder or impossible to kill
- Even if you kill boss in swarm, run usually ends in death
- **Effective run over - no realistic progression**

**Key Insight:** The timer deadline is for **BOSS KILL**, not portal activation
- Kill boss by 10:00 = can progress anytime after
- Miss boss by 10:00 = stuck in death swarm, run effectively over

**For Our System:**
- Should Final Swarm be survivable indefinitely with right build?
- Or should it be mathematically impossible after X time?
- MEGABONK rewards staying in swarm = more kills + more currency
- Creates "how long can you last?" challenge

**CONFIRMED APPROACH: Hybrid System (Not Pure MEGABONK)**

**Key Difference from MEGABONK:**
- MEGABONK: High risk = always optimal strategy (infinite swarm survivable)
- **Our System:** Final Swarm has **mathematical ceiling** (becomes impossible)

**Final Swarm Design:**
- ✅ Survivable for limited duration (2-4 minutes skill-based)
- ✅ Rewards mastery (more kills, more gold)
- ✅ **Becomes mathematically impossible** (exponential scaling)
- ✅ Forces "find your sweet spot" decision
- ✅ Death = lose all run progress

**The Balance:**
```
10:00 - Final Swarm starts (challenging but manageable)
11:00 - Very dangerous (requires strong build)
12:00 - Extremely dangerous (only best builds survive)
13:00 - Mathematically impossible (must have left by now)
```

**Strategic Tension:**
- **Risk:** Stay in swarm = more kills BUT risk death
- **Reward:** More kills for leaderboard, more gold/upgrades
- **Penalty:** Death = game over, no carry-over
- **Decision:** "Can I handle 30 more seconds, or should I progress NOW?"

**Key Design Goal:**
- Players must **find their personal ceiling**
- Not about "always max duration" (MEGABONK problem)
- About **risk assessment**: "Am I strong enough for one more minute?"
- Survival >>> greed (death ends run)

**This Creates:**
- ✅ Multiple viable strategies (conservative vs aggressive)
- ✅ Build-dependent ceiling (AoE builds last longer in swarm)
- ✅ Skill expression (knowing your limits)
- ✅ Tension between progression and death
- ❌ NOT "always stay max duration" meta

**Status:** 🟢 Final Swarm = limited survivability + mathematical ceiling

---

**CONFIRMED: MEGABONK-Style Boss Kill Deadline System**

**Complete Stage Flow:**
```
0:00 - Stage starts, normal spawning
1:30 - Rift spawns (visual only, NOT activatable yet)
4:00 - Pressure Wave 1
6:00 - Pressure Wave 2
8:00 - Pressure Wave 3
X:XX - Boss spawns (timing TBD - maybe with rift at 1:30?)
9:30 - Best-case boss kill → Rift ACTIVATES (can enter anytime)
10:00 - Timer expires → Final Swarm begins
10:00-13:00 - Optional: Farm Final Swarm (rift still accessible)
13:00 - Mathematical ceiling → Must enter rift or die
```

**The Boss Kill Mechanic:**
- ✅ Boss must be killed BEFORE 10:00 timer expires
- ✅ Boss death unlocks rift activation (permanent)
- ✅ Can enter rift immediately OR farm Final Swarm first
- ✅ Portal stays open during Final Swarm

**Risk/Reward Tiers:**
1. **Conservative (kill boss 5-7min):** Safe, reliable progression
2. **Balanced (kill boss 8-9min):** More upgrades, moderate risk
3. **Aggressive (kill boss 9:30-9:59):** Maximum pre-swarm power, high risk
4. **Extreme (farm Final Swarm):** Leaderboard push, death risk

**Design Philosophy:**
- Exponential scaling creates natural ceiling (no artificial caps)
- Players self-regulate based on build strength
- Skilled players can push further (organic skill expression)
- Multiple viable strategies (conservative to extreme)

**Status:** 🟢 Boss deadline + Final Swarm + mathematical ceiling confirmed
