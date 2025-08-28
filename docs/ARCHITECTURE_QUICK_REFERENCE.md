# Architecture Quick Reference

> Fast reference for architecture boundary enforcement tools and common patterns.

## 🚀 Quick Commands

### Run Architecture Check
```bash
# Easiest method
double-click check_architecture.bat

# Command line
"./Godot_v4.4.1-stable_win64_console.exe" --headless --script tools/check_boundaries_standalone.gd --quit-after 10

# Pre-commit (automatic)
git commit -m "changes"  # Runs check automatically
```

## 📊 Reading the Matrix

### Good Matrix (No Violations)
```
From\To	autolo	system	scenes	domain	
autolo	0	0	0	X	← Only imports domain
system	X	X	0	X	← Zero in scenes column ✅
scenes	X	X	X	0	← Zero in domain column ✅  
domain	0	0	0	X	← Only internal references
```

### Problem Indicators
- **Non-zero in forbidden cells** = violations
- **System → Scenes** = ❌ Systems accessing UI
- **Scenes → Domain** = ❌ UI bypassing systems
- **Domain → Anything** = ❌ Domain not pure

## 🔧 Common Fixes

### ❌ System Accessing Scene
```gdscript
# BAD
get_node("../../UI/HUD").update_health(hp)

# GOOD  
EventBus.health_changed.emit(hp)
```

### ❌ Domain Using EventBus
```gdscript
# BAD
class_name PlayerStats
func level_up():
    EventBus.level_up.emit(level)

# GOOD
class_name PlayerStats  
func get_level() -> int:
    return level
# (Let systems emit events)
```

### ❌ Scene Importing Domain
```gdscript
# BAD
const PlayerStats = preload("res://scripts/domain/PlayerStats.gd")

# GOOD
@onready var player_system = PlayerSystem.new()
func get_stats(): return player_system.get_player_stats()
```

## 🏗️ Layer Rules

| Layer | Path | Can Import | Purpose |
|-------|------|------------|---------|
| **Domain** | `scripts/domain/` | Domain only | Pure data/helpers |
| **Autoload** | `autoload/` | Domain | Global coordination |
| **Systems** | `scripts/systems/` | Domain, Autoload | Game logic |
| **Scenes** | `scenes/` | Systems, Autoload | UI/Visual |

## 🚨 Violation Types

| Code | Meaning | Fix |
|------|---------|-----|
| `FORBIDDEN_LAYER_IMPORT` | Wrong layer dependency | Restructure imports |
| `SYSTEMS_SCENE_COUPLING` | System using get_node() | Use signals instead |
| `DOMAIN_SIGNAL_COUPLING` | Domain using EventBus | Move to systems |
| `SCENES_DOMAIN_BYPASS` | Scene importing domain | Use systems layer |

## 📋 Workflow Checklist

### Before Coding
- [ ] Run architecture check to see current state
- [ ] Understand which layer you're working in
- [ ] Know what that layer can/cannot import

### While Coding  
- [ ] Follow import rules for your layer
- [ ] Use EventBus for cross-system communication
- [ ] Keep domain models pure (no signals/events)

### Before Committing
- [ ] Run architecture check
- [ ] Fix any violations found
- [ ] Verify matrix looks healthy
- [ ] Commit (pre-commit hook will double-check)

## 🔍 Troubleshooting

### Tool Won't Run
```bash
# Check location
pwd  # Should be in project root directory

# Check Godot exists
ls ./Godot_v4.4.1-stable_win64_console.exe

# Try longer timeout
--quit-after 30
```

### Unexpected Violations
1. Check file is in correct directory for its layer
2. Look for commented code that might be detected
3. Verify import statements match expected patterns

### False Clean (Should Have Violations)
1. Check tool is scanning all directories
2. Verify violation patterns are being detected
3. Test with known bad pattern to confirm tool works

## 📚 Documentation Links

- **Detailed Guide**: [ARCHITECTURE_ENFORCEMENT_GUIDE.md](ARCHITECTURE_ENFORCEMENT_GUIDE.md)
- **Enforcement Rules**: [ARCHITECTURE_RULES.md](ARCHITECTURE_RULES.md)
- **Overall Architecture**: [../ARCHITECTURE.md](../ARCHITECTURE.md)
- **Development Guidelines**: [../CLAUDE.md](../CLAUDE.md)