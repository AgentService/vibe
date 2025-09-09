# Death Screen Stats Tracking - Fix Total Damage and XP Gained

**Priority:** Medium  
**Status:** ✅ COMPLETED  
**Complexity:** Low-Medium  
**Architecture Impact:** Minor - Stats tracking enhancement  

## 🎯 Problem Statement

Death screen shows incorrect/missing stats for:
- **Total Damage**: Currently tracked but may not be working correctly
- **XP Gained**: Shows 0 (hardcoded) instead of actual XP earned during run

## 🔧 Current Implementation Issues

### Total Damage Tracking
```gdscript
// RunManager.gd - IMPLEMENTED but may have issues
func _on_damage_dealt(payload) -> void:
    if payload.has("source_type") and payload.source_type == "player":
        stats["total_damage_dealt"] = stats.get("total_damage_dealt", 0.0) + payload.get("damage", 0.0)
```

**Potential Issues:**
- `EventBus.damage_dealt` signal may not have `source_type` field
- Signal payload structure might be different
- Player damage events may not be properly emitted

### XP Gained Tracking  
```gdscript
// Player.gd - HARDCODED
"xp_gained": 0,  // ❌ Should get from XpSystem or PlayerProgression
```

**Missing Integration:**
- No connection to XpSystem for current XP total
- PlayerProgression.level exists but no XP tracking
- EventBus.enemy_killed emits XP but no total tracking

## ✅ Implementation Plan

### 1. Fix Total Damage Tracking
```gdscript
// Debug the damage_dealt signal payload structure
func _on_damage_dealt(payload) -> void:
    # Add debug logging to understand payload structure
    Logger.debug("Damage dealt payload: %s" % str(payload), "stats")
    
    # Check various possible field names
    var is_player_damage = (
        payload.get("source_type") == "player" or
        payload.get("attacker_type") == "player" or
        payload.get("entity_type") == "player"
    )
    
    if is_player_damage:
        var damage = payload.get("damage", payload.get("damage_amount", 0.0))
        stats["total_damage_dealt"] = stats.get("total_damage_dealt", 0.0) + damage
```

### 2. Implement XP Gained Tracking
```gdscript
// RunManager.gd - Add XP tracking
func _ready() -> void:
    # ... existing code ...
    EventBus.enemy_killed.connect(_on_enemy_killed)
    EventBus.level_up.connect(_on_level_up)  # If exists

func _on_enemy_killed(payload) -> void:
    stats["enemies_killed"] = stats.get("enemies_killed", 0) + 1
    # Track XP from kills
    var xp_value = payload.get("xp_value", payload.get("xp", 0))
    stats["xp_gained"] = stats.get("xp_gained", 0) + xp_value

func _load_player_stats() -> void:
    stats = {
        # ... existing fields ...
        "xp_gained": 0,  # Add this field
    }
```

### 3. Update Player Death Result
```gdscript
// Player.gd - Use real XP data
"xp_gained": RunManager.stats.get("xp_gained", 0),  // Fix hardcoded 0
```

### 4. Alternative: Direct XP System Integration
```gdscript
// If XpSystem tracks total XP directly
"xp_gained": XpSystem.get_current_xp() if XpSystem else 0,
```

## 🔍 Investigation Steps

1. **Check EventBus damage signals** - What fields do they actually have?
2. **Test enemy_killed payload** - Does it contain xp_value?
3. **Verify XpSystem** - Does it track total XP gained?
4. **Test death screen** - Are the RunManager stats being read correctly?

## 📋 Acceptance Criteria

- ✅ **Total Damage**: Shows accurate damage dealt by player during run
- ✅ **XP Gained**: Shows actual XP earned from enemy kills and other sources  
- ✅ **Death Screen**: Displays correct stats immediately upon death
- ✅ **No Performance Impact**: Stats tracking doesn't affect gameplay performance

## 🧪 Testing Plan

```gdscript
// Add debug output to death screen
func test_death_stats():
    print("=== DEATH STATS DEBUG ===")
    print("RunManager.stats: ", RunManager.stats)
    print("Expected enemies_killed: ", actual_kill_count)
    print("Expected damage_dealt: ", expected_damage_total)
    print("Expected xp_gained: ", expected_xp_total)
```

## 📊 Current Architecture

```
RunManager (Stat Tracking)
├── enemies_killed ✅ WORKING
├── total_damage_dealt ❓ MAY HAVE ISSUES  
└── xp_gained ❌ NOT IMPLEMENTED

EventBus Signals
├── enemy_killed → RunManager._on_enemy_killed()
├── damage_dealt → RunManager._on_damage_dealt()  
└── level_up → (need to connect)

Death Flow
└── Player.gd → death_result → ResultsScreen
```

## 🔗 Related Files
- `autoload/RunManager.gd` - Stats tracking
- `scenes/arena/Player.gd` - Death result creation  
- `scenes/ui/ResultsScreen.gd` - Stats display
- `scripts/systems/XpSystem.gd` - XP management
- `autoload/EventBus.gd` - Signal definitions

## 💡 Alternative Approaches

1. **Direct System Queries**: Query XpSystem/DamageSystem directly instead of event tracking
2. **Dedicated StatsTracker**: Create separate stats tracking system
3. **Scene-level tracking**: Track stats in Arena.gd instead of RunManager

---

## ✅ COMPLETION SUMMARY

**Completed:** January 2025  
**Commit:** `092c759` - "fix: Complete death screen stats tracking - total damage and XP gained"

### Issues Resolved:
1. **✅ Total Damage Tracking Fixed**
   - **Problem**: RunManager checked non-existent `payload.source_type` field
   - **Solution**: Fixed to use `payload.source == "player"` matching DamageDealtPayload structure  
   - **Root Cause**: DamageRegistry wasn't emitting `damage_dealt` signal; added signal emission with source mapping

2. **✅ XP Gained Tracking Implemented** 
   - **Problem**: Hardcoded 0 in death result, no XP accumulation
   - **Solution**: Connected RunManager to `EventBus.xp_gained` signal to track cumulative XP
   - **Flow**: XP Collection → PlayerProgression → EventBus.xp_gained → RunManager → Death Stats

3. **✅ Signal Architecture Fixed**
   - **Added**: `damage_dealt` signal emission in DamageRegistry._process_damage_immediate()
   - **Added**: Source mapping function to convert "melee"/"projectile" → "player" for stats
   - **Result**: Death screen now shows accurate damage dealt and XP gained values

### Files Modified:
- `autoload/RunManager.gd` - Fixed damage tracking, added XP tracking
- `scenes/arena/Player.gd` - Use real XP data instead of hardcoded 0
- `scripts/systems/damage_v2/DamageRegistry.gd` - Added damage_dealt signal emission

**Architecture Impact**: Minimal - Enhanced existing signal flow without breaking changes.

---
*Task created after implementing BaseArena system and kill counter*