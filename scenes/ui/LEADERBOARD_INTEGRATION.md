# Leaderboard Integration Guide
> How to use MeasureAtlas.tscn with LocalLeaderboard system

## Overview

The leaderboard UI (`MeasureAtlas.tscn`) displays:
- **Global Tab:** Placeholder for future online leaderboards
- **Friends Tab:** Your personal best runs via `LocalLeaderboard` autoload (✓ Connected)

## Current Setup ✓

### Scene Structure
```
MainMenu_v2 (Control) - MeasureAtlas.gd attached
├── TabBar (unique: %TabBar)
│   ├── Tab 0: "Global"
│   └── Tab 1: "Friends"
├── VBoxContainer_Global (unique: %VBoxContainer_Global)
│   ├── MarginContainerEntry (sample entry 1)
│   └── MarginContainerEntry2 (sample entry 2)
└── VBoxContainer_Friends (unique: %VBoxContainer_Friends)
    └── (empty - will be populated dynamically)
```

### Tab Switching ✓
- **Automatic:** Clicking tabs shows/hides the appropriate container
- **Signal:** `TabBar.tab_changed` → `_on_tab_changed(tab_index: int)`
- **Current behavior:** Tab 0 shows Global, Tab 1 shows Friends

## ✅ LocalLeaderboard Integration (Complete!)

### How It Works

**Friends Tab → Top 10 Kills Across Everything:**
```gdscript
# MeasureAtlas.gd automatically connects to LocalLeaderboard

func _load_local_leaderboard() -> void:
	# Gather ALL runs from ALL maps and tiers
	var all_runs: Array[Dictionary] = []
	for map_id in LocalLeaderboard.get_maps_with_entries():
		for tier in LocalLeaderboard.get_tiers_with_entries(map_id):
			all_runs.append_array(LocalLeaderboard.get_leaderboard(map_id, tier))

	# Sort by kills (highest first)
	all_runs.sort_custom(func(a, b): return a.kills > b.kills)

	# Show top 10
	var top_runs = all_runs.slice(0, 10)

	# Update UI with formatted data
	_populate_leaderboard(friends_container, top_runs)
```

**Auto-Updates:**
```gdscript
# Listens to EventBus.leaderboard_updated signal
# When LocalLeaderboard.add_run() is called after a game run,
# the Friends tab automatically refreshes the entire top 10
```

**Simple Design:**
- No map/tier filtering
- Just shows your best 10 runs by kill count
- Regardless of which character, map, or tier
- True "high scores" leaderboard

## Data Format Reference

### Expected Input Format

```gdscript
var leaderboard_data: Array[Dictionary] = [
	{
		"rank": 1,
		"name": "Signatured",
		"kills": 113300000,  # 113.3M
		"icon_path": "res://assets/ui/tile048.png"
	},
	{
		"rank": 2,
		"name": "Azateq",
		"kills": 13300000,  # 13.3M
		"icon_path": "res://assets/ui/tile038.png"
	}
]
```

### Number Formatting ✓

The `_format_number()` function automatically converts:
- `1_000_000_000+` → `"1.0B"`
- `1_000_000+` → `"1.0M"`
- `1_000+` → `"1.0K"`
- `< 1_000` → `"123"`

## Column Sizing ✓

The leaderboard has robust column constraints:

| Column | Min Width | Behavior | Notes |
|--------|-----------|----------|-------|
| **Rank** | 66px | Fixed, shrink-center | Handles #1 to #9999 |
| **Name** | 150px | Flexible, text overflow ellipsis | Long names truncated |
| **Kills** | 120px | Right-aligned | Number + Icon |
| **Icon** | 30px | Fixed | Character/achievement icon |

These sizes prevent layout shifts regardless of data values.

## Usage Examples

### Basic Static Display (Current)
```gdscript
# Just switch tabs - sample data is already in place
# No code needed, TabBar handles visibility automatically
```

### Dynamic Population
```gdscript
# In your game flow:
func _on_player_run_completed(final_kills: int) -> void:
	LeaderboardManager.submit_score(final_kills)
	await LeaderboardManager.leaderboard_updated

	# Leaderboard will auto-refresh when tab is opened
	# Or manually trigger:
	var leaderboard_scene = get_node("LeaderboardUI")
	leaderboard_scene._load_global_leaderboard()
```

### Real-time Updates
```gdscript
# In MeasureAtlas.gd _ready():
func _ready() -> void:
	tab_bar.tab_changed.connect(_on_tab_changed)
	LeaderboardManager.leaderboard_updated.connect(_on_leaderboard_data_changed)
	_on_tab_changed(0)

func _on_leaderboard_data_changed(type: String) -> void:
	# Refresh current tab
	var current_tab = tab_bar.current_tab
	_on_tab_changed(current_tab)
```

## Backend Integration Patterns

### Pattern 1: Local Storage (Offline)
```gdscript
func get_global_leaderboard() -> Array[Dictionary]:
	var save_file = FileAccess.open("user://leaderboard.json", FileAccess.READ)
	if save_file:
		var json = JSON.parse_string(save_file.get_as_text())
		return json.get("global", [])
	return []
```

### Pattern 2: HTTP API
```gdscript
func get_global_leaderboard() -> Array[Dictionary]:
	var http = HTTPRequest.new()
	add_child(http)
	http.request("https://api.yourgame.com/leaderboard/global")
	var result = await http.request_completed

	if result[1] == 200:
		var json = JSON.parse_string(result[3].get_string_from_utf8())
		return json.get("entries", [])
	return []
```

### Pattern 3: EventBus Integration
```gdscript
# In MeasureAtlas.gd
func _ready() -> void:
	EventBus.leaderboard_data_received.connect(_on_data_received)
	_on_tab_changed(0)

func _on_data_received(payload: LeaderboardPayload) -> void:
	if payload.board_type == "global":
		_populate_leaderboard(global_container, payload.entries)
	elif payload.board_type == "friends":
		_populate_leaderboard(friends_container, payload.entries)
```

## Testing Checklist

- [ ] Tab switching shows/hides correct containers
- [ ] Column widths remain stable with different data
- [ ] Text overflow works for long names
- [ ] Number formatting displays correctly (K/M/B)
- [ ] Icons load and display at 30x30px
- [ ] Empty leaderboards show gracefully
- [ ] Data refreshes when backend updates

## Architecture Notes

### Why TabBar instead of TabContainer?
- **More control:** Manual visibility management allows custom animations
- **Flexible layout:** Headers and content can be styled independently
- **Current project style:** Matches existing UI patterns in the codebase

### Separation of Concerns
- **MeasureAtlas.gd:** UI logic only (show/hide, format display)
- **LeaderboardManager:** Data fetching, caching, persistence
- **EventBus (optional):** Cross-system communication

This keeps the UI layer clean and focused on presentation.

## Next Steps

1. ✓ Tab switching implemented
2. ✓ Column sizing configured
3. → Create `LeaderboardManager` autoload
4. → Implement data fetching for your backend
5. → Create `LeaderboardEntry.tscn` if using dynamic population
6. → Connect to game flow (submit scores after runs)
7. → Add loading states/animations (optional)

---

**See Also:**
- [UI Framework Patterns](../CLAUDE.md) - General UI architecture
- [EventBus Integration](../../autoload/CLAUDE.md) - Signal-based communication
- [Data Layer](../../data/README.md) - Content resource patterns
