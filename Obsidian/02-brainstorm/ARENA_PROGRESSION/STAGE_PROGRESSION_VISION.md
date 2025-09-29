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

---

## Vision Development Log
*Updates will be added here as we explore together*
