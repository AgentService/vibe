# MEGABONK Ultra Guide - Reference

**Source:** [Steam Community Guide by IcyCyborg](https://steamcommunity.com/sharedfiles/filedetails/?id=3571240516)
**Extracted:** 2025-09-29
**Purpose:** Reference for arena progression system design

---

## Core Gameplay Mechanics

### Primary Goal
- Reach the boss teleporter before time limit expires
- Progress through tiers (1, 2, 3) by defeating bosses
- Endless enemy waves spawn if teleporter isn't reached in time

### Controls
- Sliding: CTRL
- Quick restart: R key
- Map marker: Red arrow shows teleporter location

---

## Progression System

### Tier Structure
- **Tier 1:** Basic tier, 1 stage
- **Tier 2:** Intermediate, 1 teleport between stages
- **Tier 3:** Advanced, 2 teleports + final boss

### Boss & Teleporter Mechanics
- Must defeat boss at teleporter to progress
- Teleporters only unlock if you've reached corresponding tier
- Boss must be killed before timer expires
- After boss kill, portal/teleporter becomes active

### Time Limit & Final Swarm
- Each stage has a time limit
- When time expires → "Endless waves of enemies" begin
- **Final Swarm Characteristics:**
  - Waves get "faster, stronger, and more numerous" over time
  - Has no end, continues until player death
  - **Bonus silver for surviving longer** in final swarm
  - Designed as ultimate survival challenge

---

## Difficulty Scaling System

### Difficulty Stat
- Increases enemy strength and count
- Higher difficulty = more rewards (XP, gold)
- Monthly leaderboard resets

### Ways to Increase Difficulty
1. **Greed Shrine:** +5% difficulty per activation
2. **Curse Tome:** Increases difficulty
3. **Character abilities:** Some characters (e.g., Sir Chadwell) have difficulty-increasing abilities
4. **Boss curses:** Additional difficulty modifiers

### Difficulty Effects
- Enemy health increases
- Enemy damage increases
- Enemy count increases
- Spawn rates increase
- Better rewards (XP/gold) at higher difficulties

---

## Character System (20+ Characters)

### Character Types
- Each character has unique abilities
- Different stat distributions
- Varied playstyles (AoE, single-target, tank, etc.)

### Top Tier Characters (Referenced)
- **Dicehead:** Broken crit stacking (holds 7/10 top leaderboard spots)
- **CL4NK:** S-tier
- **Robinette:** S-tier
- **Sir Chadwell:** Has difficulty-increasing ability

---

## Stat System

### Core Stats
- **Max HP:** Health pool
- **HP Regen:** Health regeneration rate
- **Shield:** Damage absorption
- **Armor:** Damage reduction
- **Evasion:** Dodge chance
- **Lifesteal:** Heal on hit

### Stat Mechanics
- **Diminishing returns** at higher stat levels
- Balance between offensive and defensive stats critical
- Different builds prioritize different stats

---

## Weapon System

### Weapon Types
- Multiple weapon categories
- Different mechanics per weapon
- Can have multiple weapons equipped
- **Final boss removes all weapons except primary**

### Weapon Investment
- Important to fully invest in primary weapon
- Final boss strips secondary weapons
- Attack speed and damage scale with investment

---

## Item & Tome System

### Rarity Tiers
- Common
- Uncommon
- Rare
- Epic
- Legendary

### Key Tomes (Build-Defining)
- **Curse Tome:** Spawns more enemies (increases difficulty)
- **XP Gain Tome:** Boosts XP from all sources
- **Luck Tome:** Improves quality/rarity of level-up choices
- **Damage Tome:** Multiplies all damage output
- **Attack Speed Tome:** Increases attack frequency
- **Quantity Tome:** Adds more projectiles

### "Holy Trinity" Build
- **Curse + XP Gain + Luck** = Exponential growth engine
- Top strategy for high kill counts and leaderboard runs
- Creates positive feedback loop of power scaling

### Item Selection Mechanics
- **Banish:** Remove item from pool permanently
- **Skip:** Ignore this choice, item stays in pool
- **Refresh:** Reroll current options

---

## XP & Gold Economy

### XP Sources
- Killing enemies (scales with difficulty)
- **Blue Skeletons:** Guaranteed level up
- XP Gain Tome multiplies all XP
- **Shrine of Succ:** Collects all nearby XP at once

### Gold Sources
- Killing enemies (scales with difficulty)
- **Gold Skeletons:** Drop gold
- Greed Shrine increases gold find
- **Final Swarm:** Gold continues dropping (bonus silver for survival time)

### Currency Types
- **Gold:** In-run currency (chests, shrines)
- **Silver:** Meta-progression currency (permanent unlocks)
  - Tier 1 = 1x silver multiplier
  - Tier 3 = 1.2x silver multiplier
  - Higher tiers = better silver rewards

---

## Shrine System

### Shrine Types
- **Greed Shrine:** +5% difficulty (more rewards)
- **Shrine of Combat:** Spawn enemy waves for rewards
- **Shrine of Succ:** Collect all nearby XP
- **Shrine of Blood:** Exchange health for rewards
- **Charge Shrine:** +8% difficulty option

### Shrine Strategy
- Greed shrines scale rewards but increase danger
- Combat shrines = controlled risk/reward
- Balance shrine usage with survival capability

---

## High-Level Strategies

### Leaderboard Runs
- Top runs: **90+ minutes, 2 million+ kills**
- Focus on exponential scaling builds
- Farm Final Swarm phases extensively
- Requires perfect build synergies

### Optimal Build Path
1. Secure "Holy Trinity" (Curse, XP, Luck)
2. Stack attack speed and damage
3. Build survivability (lifesteal, evasion, shields)
4. Maximize AoE coverage
5. Focus primary weapon investment (final boss strips others)

### Tier 3 Final Boss
- Removes all weapons except primary
- 8-18 million HP
- Multiple invulnerability phases (must disable beacons)
- Long, challenging fight
- Requires heavily invested primary weapon

---

## Final Swarm Mechanics (Detailed)

### Trigger Conditions
- Stage timer reaches 0:00
- Only survivable if boss was killed (portal available)
- If boss not killed = stuck until death

### Swarm Timeline (Exact Timings)

**Tier 1 & 2:**
- **7:00** - First Mini Boss spawns
- **6:00** - First Swarm
- **3:00** - Second Swarm
- **2:00** - Second Mini Boss spawns
- **0:00** - Final Swarm begins
- **-1:00** - Black Ghosts spawn (extreme danger)

**Tier 3:**
- (Timing data incomplete - different from Tier 1 & 2)
- First Mini Boss spawns at different time
- Swarm timings adjusted for tier difficulty
- **0:00** - Final Swarm begins
- **-1:00** - Black Ghosts spawn

### Swarm Characteristics
- **Regular Swarms (6:00, 3:00):** Pressure waves, survivable
- **Final Swarm (0:00):** Intense spawning, continuous until death
- **Black Ghosts (-1:00):** Exponentially harder, designed to kill everyone

### Rewards for Survival
- **Bonus silver** (scales with survival time)
- **Kill count** for leaderboards
- **Gold** continues dropping (no XP gain)

### Survival Requirements
- Strong AoE damage
- High lifesteal
- Movement speed
- Defensive stats (armor, evasion, shields)

---

## Progression Unlocks

### Unlock System
- Complete challenges to unlock new content
- Characters, weapons, items require specific achievements
- Silver used for permanent meta-progression purchases
- Monthly leaderboard resets provide fresh competition

---

## Design Insights for Our System

**What MEGABONK Does Well:**
1. **Clear risk/reward choices** (difficulty shrines, Final Swarm farming)
2. **Multiple viable strategies** (early clear vs extended farming)
3. **Build diversity** (Holy Trinity, tank builds, speed builds)
4. **Skill expression** (survival time in Final Swarm)
5. **Meta-progression** (silver rewards long-term investment)

**Potential Issues:**
1. **90+ minute runs** may be too long (fatigue factor)
2. **Infinite scaling** creates imbalanced leaderboard (Dicehead domination)
3. **Final boss weapon strip** feels punishing (invalidates build investment)

**What We're Adapting:**
- Boss-kill deadline (clear objective)
- Final Swarm as optional challenge (not required)
- Difficulty shrines (voluntary risk-taking)
- Mathematical ceiling (prevents infinite runs)
- Fixed stage jumps (predictable progression)

---

**Status:** Reference document for progression system design. Key takeaways documented in STAGE_PROGRESSION_VISION.md