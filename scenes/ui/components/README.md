# UI Components - Reusable Scene Templates

This directory contains reusable UI component scenes that can be instantiated dynamically in code.

## Available Components

### CharacterSelectButton

**File:** `CharacterSelectButton.tscn`
**Purpose:** Displays a character portrait and name for character selection screens

**Usage:**
```gdscript
const CharacterButtonScene = preload("res://scenes/ui/components/CharacterSelectButton.tscn")

# Create instance
var button: CharacterSelectButton = CharacterButtonScene.instantiate()

# Setup with data
var portrait_texture = load("res://assets/ui/characters/portraits/knight_portrait.png")
button.setup("knight", character_type, portrait_texture)

# Connect signal
button.character_selected.connect(_on_character_selected)

# Add to scene
character_grid.add_child(button)

# Update state
button.set_selected(true)  # Disable when selected
```

**Signals:**
- `character_selected(character_id: String)` - Emitted when button is clicked

**Methods:**
- `setup(char_id: String, char_type: CharacterType, portrait_texture: Texture2D)` - Initialize with character data
- `set_selected(selected: bool)` - Update visual state (enables/disables button)

---

### LeaderboardEntry

**File:** `LeaderboardEntry.tscn`
**Purpose:** Displays a leaderboard row with rank, player name, score, and character icon

**Usage:**
```gdscript
const LeaderboardEntryScene = preload("res://scenes/ui/components/LeaderboardEntry.tscn")

# Example: Populate friends leaderboard
func populate_friends_leaderboard(players: Array[Dictionary]) -> void:
    # Clear existing entries
    for child in friends_container.get_children():
        child.queue_free()

    # Create entry for each player
    for i in range(players.size()):
        var player = players[i]
        var entry: LeaderboardEntry = LeaderboardEntryScene.instantiate()

        # Load character icon (optional)
        var char_icon = load("res://assets/ui/characters/portraits/%s_portrait.png" % player.character_id)

        # Setup entry with data
        entry.setup(
            i + 1,                    # Rank (1-based)
            player.name,              # Player name
            "%d kills" % player.kills, # Score string
            char_icon                 # Character icon (optional)
        )

        # Highlight current player
        if player.is_current_player:
            entry.set_highlight(true)

        friends_container.add_child(entry)

# Example: Populate global leaderboard
func populate_global_leaderboard(leaderboard_data: Array[Dictionary]) -> void:
    for child in global_container.get_children():
        child.queue_free()

    for i in range(leaderboard_data.size()):
        var data = leaderboard_data[i]
        var entry: LeaderboardEntry = LeaderboardEntryScene.instantiate()

        # Format score (e.g., "1.2M")
        var score_text = format_large_number(data.score)

        entry.setup(i + 1, data.player_name, score_text)
        global_container.add_child(entry)
```

**Methods:**
- `setup(rank: int, player_name: String, score: String, char_icon: Texture2D = null)` - Initialize with leaderboard data
- `set_highlight(highlighted: bool)` - Highlight entry (e.g., for current player)

**Parameters:**
- `rank` - Player's position (1, 2, 3, etc.)
- `player_name` - Display name
- `score` - Formatted string ("1.2M kills", "Wave 45", etc.)
- `char_icon` - Optional character portrait texture

---

## Benefits of Scene Components

### Visual Editing
Edit the `.tscn` file in Godot editor to change appearance - all instances update automatically.

### Consistent Styling
One template ensures all entries look the same across different screens.

### Code Simplification
```gdscript
// Before: 50+ lines of manual UI construction
var entry = VBoxContainer.new()
var frame = NinePatchRect.new()
// ... many more lines

// After: 3 lines
var entry = LeaderboardEntryScene.instantiate()
entry.setup(rank, name, score)
parent.add_child(entry)
```

### Reusability
Use the same component in:
- Friends leaderboard
- Global leaderboard
- Match results screen
- Profile comparison screen

---

## Creating New Components

1. **Create `.tscn` file** in this directory
2. **Create `.gd` script** with same name
3. **Add `setup()` method** for initialization
4. **Handle pending data** pattern for early setup calls:

```gdscript
extends SomeControl
class_name NewComponent

@onready var some_label: Label = $Path/To/Label

var _pending_data: Dictionary = {}

func _ready() -> void:
    if not _pending_data.is_empty():
        _apply_data(_pending_data)
        _pending_data.clear()

func setup(data: Dictionary) -> void:
    if some_label:
        _apply_data(data)
    else:
        _pending_data = data

func _apply_data(data: Dictionary) -> void:
    some_label.text = data.text
```

5. **Document usage** in this README

---

## Component Styling

To change component appearance:

1. Open component `.tscn` in Godot editor
2. Select nodes and edit in Inspector
3. Save - all instances update automatically!

**Example:** Change LeaderboardEntry background color
1. Open `LeaderboardEntry.tscn`
2. Select `Frame` (NinePatchRect) node
3. Change `region_rect` or `modulate` in Inspector
4. Save → All leaderboard entries update everywhere

---

## Testing Components

```gdscript
# Test in isolation
func _ready() -> void:
    var test_entry = LeaderboardEntryScene.instantiate()
    test_entry.setup(1, "TestPlayer", "9999 kills")
    add_child(test_entry)
```
