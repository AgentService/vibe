# UI Progression Screens Polish (Option B Layouts)

**Created:** 2025-10-03
**Status:** 🟡 Planning
**Priority:** Low
**Estimated Effort:** 4-5 sessions
**Category:** 🎨 UI/UX Polish
**Parent Task:** [Task 1 - Single-Session Run Refactoring](completed-tasks/1_PROGRESSION_single_session_refactoring_COMPLETED.md) (Phases 4-6 deferred UI)

## 📋 Task Description

Upgrade progression UI screens from minimal debug layouts (Option A) to polished visual designs (Option B) matching the original mockups. This includes three-column end-of-run breakdown, grid-based character select with portraits, and two-panel map selection.

**Current State (Option A - Functional MVP):**
- ✅ EndOfRunDebug.tscn - Simple VBoxContainer with text labels
- ✅ CharacterSelectDebug.tscn - Simple list of character buttons
- ✅ MapSelectionDebug.tscn - Dropdown + tier buttons
- ⚠️ No visual polish, minimal layout, text-only

**Target State (Option B - Polished Design):**
- ✅ EndOfRun.tscn - Three-column layout (damage breakdown | summary | quests)
- ✅ CharacterSelect.tscn - 4x5 grid with portraits, skins, info panel
- ✅ MapSelect.tscn - Two-panel layout (map list | details + tier selection)
- ✅ Consistent styling using UI template system (BaseMenuContainer, GridMenuContainer, etc.)
- ✅ Animations, icons, visual feedback

## 🎯 Implementation Plan

### Phase 1: End-of-Run Three-Column Layout (2 sessions)
**Goal:** Replace debug screen with full stats breakdown matching mockup

**Column Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│ LEFT COLUMN        │ CENTER COLUMN       │ RIGHT COLUMN      │
│ Damage Breakdown   │ Run Summary         │ Completed Quests  │
│                    │                     │                   │
│ Ability | DMG | DPS│ Character Portrait  │ Quest 1 ✓         │
│ Bone    | 2016| 45 │ Kills: 150          │ Quest 2 ✓         │
│ Fireball| 1834| 41 │ Time: 12:34         │                   │
│ ...                │ Level: 8            │ (Placeholder)     │
│                    │                     │                   │
│                    │ Inventory Grid      │                   │
│                    │ [Items] [Tomes]     │                   │
│                    │ [Skills]            │                   │
├────────────────────┴─────────────────────┴───────────────────┤
│ BOTTOM SECTION                                                │
│ Rift Fragments Earned: +73 (Tier 2: 1.1x multiplier)         │
│ Unlocks this run: 3 | Discoveries: 2                          │
│ [CONFIRM] button                                              │
└───────────────────────────────────────────────────────────────┘
```

**Implementation Steps:**
- [ ] Create `scenes/ui/EndOfRun.tscn` with HBoxContainer for 3 columns:
  - [ ] **Left Column (30% width)**: DamageBreakdown panel
    - [ ] ScrollContainer with VBoxContainer
    - [ ] Ability rows: [Icon] Name | Damage | DPS | Level
    - [ ] Sorted by damage (highest first)
    - [ ] Read from SessionState.damage_breakdown
  - [ ] **Center Column (40% width)**: Run summary
    - [ ] Character portrait (TextureRect or placeholder)
    - [ ] Stats labels (kills, time, level, stage reached)
    - [ ] Inventory grid (4x4 GridContainer for items/tomes/skills)
    - [ ] Read from SessionState (kills, time_survived, level, collected_items)
  - [ ] **Right Column (30% width)**: Quest completion
    - [ ] Placeholder for quest system (future)
    - [ ] Label: "Quest system coming soon!"
    - [ ] Wire to quest system once Task 3 is done
  - [ ] **Bottom Section**: Rewards summary
    - [ ] Rift Fragments earned (with tier multiplier breakdown)
    - [ ] Discoveries count (link to Task 6)
    - [ ] Unlocks count (if any achievements triggered)
    - [ ] [CONFIRM] button → returns to main menu
- [ ] Wire to SessionState.end_run():
  - [ ] Populate damage_breakdown table
  - [ ] Populate run summary stats
  - [ ] Calculate Rift Fragments (base + bonuses + tier multiplier)
- [ ] Add visual polish:
  - [ ] Fade-in animation (Tween)
  - [ ] Counter animations (kills counting up from 0)
  - [ ] Sound effects for Rift Fragments earned
  - [ ] Background dim overlay (CanvasLayer)

**Test:** Complete run → see three-column layout with all stats displayed

---

### Phase 2: Character Select Grid with Portraits (2 sessions)
**Goal:** Replace simple list with 4x5 grid matching mockup

**Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│ CHARACTER SELECT                                             │
│                                                              │
│ LEFT PANEL (70%)               │ RIGHT PANEL (30%)           │
│ ┌──┬──┬──┬──┐                 │ Character Name              │
│ │🦊│🔒│🔒│🔒│  (4x5 grid)      │ Rank: Novice                │
│ ├──┼──┼──┼──┤                 │                             │
│ │🔒│🔒│🔒│🔒│                  │ Passive Ability:            │
│ ├──┼──┼──┼──┤                 │ "Fox gains +10% speed"      │
│ │🔒│🔒│🔒│🔒│                  │                             │
│ ├──┼──┼──┼──┤                 │ Starting Runs: 0            │
│ │🔒│🔒│🔒│🔒│                  │                             │
│ └──┴──┴──┴──┘                 │ Skins:                      │
│                                │ [✓] [🔒] [🔒] [🔒] [🔒]     │
│                                │                             │
│                                │ [CONFIRM] button            │
└────────────────────────────────┴─────────────────────────────┘
```

**Implementation Steps:**
- [ ] Create `scenes/ui/CharacterSelect.tscn` with two-panel layout:
  - [ ] **Left Panel**: GridContainer (4 columns, 5 rows)
    - [ ] Character portrait buttons (TextureButton)
    - [ ] Locked characters show lock icon + grayed out
    - [ ] Unlocked characters show portrait
    - [ ] Selected character shows highlight border
  - [ ] **Right Panel**: Character info display
    - [ ] Character name (Label)
    - [ ] Rank (Label - placeholder for achievement system)
    - [ ] Passive ability description (RichTextLabel)
    - [ ] Starting runs count (read from MetaProgression.character_runs)
    - [ ] Skin selector (5 TextureButton slots)
    - [ ] [CONFIRM] button → go to map select
- [ ] Wire to MetaProgression:
  - [ ] Query `unlocked_characters` to determine which portraits show
  - [ ] Query `character_achievements` for locked character unlock conditions
  - [ ] Query `unlocked_skins` for skin availability
- [ ] Add character metadata resources:
  - [ ] `/data/content/characters/fuchs.tres` - name, portrait path, passive description
  - [ ] Create for all planned characters
- [ ] Visual polish:
  - [ ] Hover effects on portraits
  - [ ] Click animations
  - [ ] Locked character tooltip: "Complete Stage 5 to unlock"

**Test:** Select character → see info panel update → click CONFIRM → go to map select

---

### Phase 3: Map Selection Two-Panel Layout (1-2 sessions)
**Goal:** Replace dropdown UI with visual map list + details panel

**Layout:**
```
┌─────────────────────────────────────────────────────────────┐
│ MAP SELECTION                                                │
│                                                              │
│ LEFT PANEL (40%)               │ RIGHT PANEL (60%)           │
│ Map List:                      │ Forest Arena                │
│ ┌─────────────────┐            │ ┌─────────────────────┐     │
│ │ [✓] Forest      │ (selected) │ │ Map thumbnail      │     │
│ └─────────────────┘            │ └─────────────────────┘     │
│ ┌─────────────────┐            │                             │
│ │ [🔒] Desert     │ (locked)   │ Tier Selection:             │
│ └─────────────────┘            │ [Tier 1] [Tier 2] [Tier 3]  │
│                                │                             │
│ Unlock condition:              │ Rift Fragments: 1.0x / 1.1x / 1.2x │
│ "Reach Stage 2 on Forest"      │                             │
│                                │ Personal Bests (Tier 1):    │
│                                │ Highscore: 150 kills        │
│                                │ Speedrun: 12:34             │
│                                │                             │
│                                │ Characters Completed:       │
│                                │ [🦊] [🔒] [🔒]              │
│                                │                             │
│                                │ [START RUN] button          │
└────────────────────────────────┴─────────────────────────────┘
```

**Implementation Steps:**
- [ ] Create `scenes/ui/MapSelect.tscn` with two-panel layout:
  - [ ] **Left Panel**: Map list (VBoxContainer with map buttons)
    - [ ] Locked maps show lock icon + unlock condition text
    - [ ] Unlocked maps show checkmark
    - [ ] Selected map shows highlight
  - [ ] **Right Panel**: Map details
    - [ ] Map thumbnail (TextureRect or placeholder)
    - [ ] Tier selection (3 buttons: Tier 1, 2, 3)
    - [ ] Tier multiplier display (1.0x / 1.1x / 1.2x)
    - [ ] Personal bests for selected tier (read from LocalLeaderboard)
    - [ ] Character completion icons (read from LocalLeaderboard.get_completed_characters)
    - [ ] [CHALLENGES] button (future - placeholder)
    - [ ] [START RUN] button → SessionState.start_run() → go to arena
- [ ] Wire to MetaProgression + LocalLeaderboard:
  - [ ] Query `unlocked_maps` for availability
  - [ ] Query `LocalLeaderboard.get_personal_best_kills(map_id, tier)` for highscore
  - [ ] Query `LocalLeaderboard.get_fastest_time(map_id, tier)` for speedrun
  - [ ] Query `LocalLeaderboard.get_completed_characters(map_id, tier)` for icons
- [ ] Add map metadata resources:
  - [ ] `/data/content/maps/forest.tres` - name, thumbnail path, unlock condition
  - [ ] Create for future maps (desert, etc.)
- [ ] Visual polish:
  - [ ] Tier button highlighting
  - [ ] Map thumbnail fade-in when selected
  - [ ] START RUN button pulse animation

**Test:** Select map → select tier → see personal bests update → click START RUN → run starts

---

## 🔗 Integration with UI Template System

This task should leverage the UI container templates created in Phase 9:
- `BaseMenuContainer` - Border + background foundation
- `TitledMenuContainer` - Adds title section
- `GridMenuContainer` - Adds scrollable grid
- `GridWithDetailsContainer` - Adds toggleable details panel
- `TabbedGridContainer` - Adds tab navigation

**Recommended Template Usage:**
- **EndOfRun**: Use `TitledMenuContainer` for each column (damage/summary/quests)
- **CharacterSelect**: Use `GridWithDetailsContainer` (grid on left, info on right)
- **MapSelect**: Use `GridWithDetailsContainer` (map list on left, details on right)

**See:** `scenes/ui/components/MENU_CONTAINERS_GUIDE.md` for template patterns

---

## 📝 Testing Checklist

### End-of-Run Screen:
- [ ] Damage breakdown sorts by total damage (highest first)
- [ ] DPS calculations correct (damage / time_survived)
- [ ] Inventory grid shows all collected items
- [ ] Rift Fragments calculation includes tier multiplier
- [ ] CONFIRM button returns to main menu
- [ ] Fade-in animation plays on screen open

### Character Select:
- [ ] Locked characters show lock icon and condition text
- [ ] Unlocked characters show portraits
- [ ] Clicking character updates info panel
- [ ] Skin selector shows unlocked skins (or all locked for new characters)
- [ ] CONFIRM button navigates to map select

### Map Select:
- [ ] Locked maps show unlock condition
- [ ] Tier buttons update personal bests display
- [ ] Personal bests query correct map+tier combination
- [ ] Character completion icons show correct characters
- [ ] START RUN button starts run with correct map+tier+character

---

## 🚨 Edge Cases & Considerations

### Missing Portraits/Icons
- **Issue:** Character portraits or map thumbnails might not exist yet
- **Solution:** Use placeholder TextureRect with solid color + text label

### Empty Personal Bests
- **Issue:** New players have no leaderboard entries for map+tier
- **Solution:** Show "No runs yet!" placeholder text

### Long Ability Names
- **Issue:** Damage breakdown table might overflow with long names
- **Solution:** Use `clip_text: true` on Labels, or abbreviate in display logic

### Quest System Not Ready
- **Issue:** Right column of end-of-run shows placeholder
- **Solution:** Acceptable - add TODO comment, wire to quest system in Task 3 later

---

## ✅ Definition of Done

- [ ] EndOfRun.tscn displays three-column layout with all stats
- [ ] Damage breakdown table sorts by damage and shows DPS
- [ ] Inventory grid displays collected items/tomes/skills
- [ ] Rift Fragments calculation shows tier multiplier breakdown
- [ ] CharacterSelect.tscn displays 4x5 grid with portraits
- [ ] Character info panel shows name, passive, runs, skins
- [ ] Locked characters show unlock conditions
- [ ] MapSelect.tscn displays two-panel layout (list + details)
- [ ] Tier selection updates personal bests display
- [ ] Character completion icons show correct characters per tier
- [ ] All screens use UI template system (BaseMenuContainer, etc.)
- [ ] Visual polish: animations, hover effects, sound effects (optional)

---

**Related:** [Task 1 - Phases 4-6](completed-tasks/1_PROGRESSION_single_session_refactoring_COMPLETED.md) | [UI Templates Guide](../../scenes/ui/components/MENU_CONTAINERS_GUIDE.md) | [LocalLeaderboard API](../../autoload/CLAUDE.md#localleaderboard)
