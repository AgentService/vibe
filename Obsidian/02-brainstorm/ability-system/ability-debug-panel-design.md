# Ability Debug Panel Design
> In-game debug tool for ability testing and iteration

**Created:** 2025-10-03
**Status:** 🎨 Design Phase
**Related:** [Ability System Design](ability-system-design-exploration.md)

## Overview

An in-game debug panel integrated with the existing DebugPanel system that allows designers to:
1. **Edit** ability parameters (damage, cooldown, projectile count, etc.)
2. **Equip** abilities to player slots (1-4) for immediate testing
3. **Save** changes directly to .tres files
4. **Test** ability combinations without restarting the game

`★ Design Philosophy ─────────────────────────────`
**Immediate Feedback Loop:**
Designer workflow: Edit values → Save → See changes (no restart, no Shift+F5)
- All changes saved to .tres files (persistent across sessions)
- Optional "Apply to Equipped" button for instant in-game updates
- Dropdown-based ability selection (browse all available abilities)
- Slot-based equipment (4 slots, dropdown per slot)

This matches professional game dev tools (Hades debug console, Dead Cells dev panel).
`─────────────────────────────────────────────────`

## UI Layout

### Integration with Existing DebugPanel

**CHOSEN APPROACH: Popup/Modal Window** (Separate popup opened via button)

```
┌─────────────────────────────────────┐
│ Debug Panel (Current - UNCHANGED)   │
├─────────────────────────────────────┤
│ [Enemy Type Dropdown ▼]             │
│ [Spawn at Cursor] [Spawn at Player] │
│ [Count: 1] [5] [10]                 │
│                                     │
│ ─────────────────────────────────   │
│ Entity Inspector...                 │
│ ─────────────────────────────────   │
│ Performance Stats...                │
│ ─────────────────────────────────   │
│                                     │
│ [🎯 Ability Testing Tool]  ← NEW    │ ← Opens popup
└─────────────────────────────────────┘

                ↓ Click button

┌───────────────────────────────────────────────────────────┐
│ Ability Testing Tool                          [X] Close   │
├─────────────────────────┬─────────────────────────────────┤
│ LEFT COLUMN             │ RIGHT COLUMN                    │
│ ─────────────           │ ──────────────                  │
│ (Ability Editor)        │ (Slot Equipment)                │
│                         │                                 │
│ Select Ability:         │ Slot 1: [Fireball ▼]           │
│ [Dropdown ▼]            │ Slot 2: [None ▼]               │
│                         │ Slot 3: [None ▼]               │
│ Base Damage: [25.0]     │ Slot 4: [None ▼]               │
│ Cooldown: [1.5]         │                                 │
│                         │ [Equip Selected Abilities]      │
│ [Save to File]          │ [Level Up All]                  │
│ [Apply to Equipped]     │ [Clear All]                     │
└─────────────────────────┴─────────────────────────────────┘
```

**Why This Approach:**
- ✅ Existing DebugPanel **completely unchanged** (no refactoring needed)
- ✅ Ability tool is **independent** (separate scene, separate logic)
- ✅ Only visible when needed (opens on demand, closes with X button)
- ✅ Can be positioned anywhere on screen (draggable if needed)
- ✅ Reuses existing debug panel visibility logic (both use DebugManager.is_debug_mode_active())
- ✅ Clean separation of concerns (enemy spawning vs ability testing)

---

## Panel Structure (Ability Tab)

### Two-Column Layout (Matches current DebugPanel style)

```
┌───────────────────────────────────────────────────────────┐
│ Ability Debug Panel                                       │
├─────────────────────────┬─────────────────────────────────┤
│ LEFT COLUMN             │ RIGHT COLUMN                    │
│ ─────────────           │ ──────────────                  │
│                         │                                 │
│ ┌─ ABILITY EDITOR ────┐ │ ┌─ SLOT EQUIPMENT ────────────┐│
│ │                     │ │ │                             ││
│ │ Select Ability:     │ │ │ Slot 1 (Base):              ││
│ │ [Dropdown ▼]        │ │ │ [Fireball ▼]                ││
│ │                     │ │ │                             ││
│ │ ─────────────────── │ │ │ Slot 2:                     ││
│ │ Ability ID:         │ │ │ [Ice Blast ▼]               ││
│ │ fireball            │ │ │                             ││
│ │                     │ │ │ Slot 3:                     ││
│ │ Name:               │ │ │ [Lightning Strike ▼]        ││
│ │ [Fireball_______]   │ │ │                             ││
│ │                     │ │ │ Slot 4:                     ││
│ │ Base Damage:        │ │ │ [None ▼]                    ││
│ │ [25.0_____] (+/-)   │ │ │                             ││
│ │                     │ │ │ ─────────────────────────── ││
│ │ Cooldown:           │ │ │                             ││
│ │ [1.5______] (+/-)   │ │ │ [Equip Selected Abilities]  ││
│ │                     │ │ │                             ││
│ │ Projectile Count:   │ │ │ [Reset to Defaults]         ││
│ │ [3________] (+/-)   │ │ │                             ││
│ │                     │ │ │ ─────────────────────────── ││
│ │ Tags:               │ │ │                             ││
│ │ [projectile, fire]  │ │ │ ┌─ CURRENT EQUIPPED ──────┐││
│ │                     │ │ │ │ Slot 1: Fireball (Lv 5) │││
│ │ ─────────────────── │ │ │ │ Slot 2: Ice Blast (Lv 3)│││
│ │                     │ │ │ │ Slot 3: Lightning (Lv 1)│││
│ │ [Save to File]      │ │ │ │ Slot 4: (Empty)         │││
│ │ [Apply to Equipped] │ │ │ └─────────────────────────┘││
│ │                     │ │ │                             ││
│ └─────────────────────┘ │ │ ─────────────────────────── ││
│                         │ │                             ││
│ ┌─ FILE INFO ─────────┐ │ │ ┌─ TESTING ACTIONS ───────┐││
│ │ File:               │ │ │ │                         │││
│ │ res://data/content/ │ │ │ │ [Level Up Slot 1 (+1)]  │││
│ │ abilities/          │ │ │ │ [Level Up All (+1)]     │││
│ │ fireball.tres       │ │ │ │                         │││
│ │                     │ │ │ │ [Clear All Abilities]   │││
│ │ Last Saved:         │ │ │ │ [Refresh from Files]    │││
│ │ 2 seconds ago       │ │ │ │                         │││
│ └─────────────────────┘ │ └─────────────────────────────┘│
│                         │                                 │
└─────────────────────────┴─────────────────────────────────┘
```

---

## Component Breakdown

### LEFT COLUMN: Ability Editor

**1. Ability Selection Dropdown**
```gdscript
@onready var ability_dropdown: OptionButton = $LeftColumn/AbilityDropdown

var ability_definitions: Dictionary = {}  # ability_id -> BaseAbility
var ability_file_paths: Dictionary = {}   # ability_id -> file path

func _populate_ability_dropdown() -> void:
    ability_dropdown.clear()

    # Load all abilities from /data/content/abilities/
    var dir = DirAccess.open("res://data/content/abilities/")
    if dir:
        dir.list_dir_begin()
        var file_name = dir.get_next()

        while file_name != "":
            if file_name.ends_with(".tres"):
                var full_path = "res://data/content/abilities/" + file_name
                var ability = ResourceLoader.load(full_path) as BaseAbility

                if ability:
                    ability_definitions[ability.ability_id] = ability
                    ability_file_paths[ability.ability_id] = full_path
                    ability_dropdown.add_item(ability.ability_name)

            file_name = dir.get_next()

    # Select first ability by default
    if ability_dropdown.item_count > 0:
        ability_dropdown.selected = 0
        _on_ability_selected(0)
```

**2. Editable Parameter Fields**
```gdscript
@onready var name_field: LineEdit = $LeftColumn/NameField
@onready var damage_spinner: SpinBox = $LeftColumn/DamageSpinner
@onready var cooldown_spinner: SpinBox = $LeftColumn/CooldownSpinner
@onready var projectile_spinner: SpinBox = $LeftColumn/ProjectileSpinner
@onready var tags_label: Label = $LeftColumn/TagsLabel

var current_ability: BaseAbility = null
var current_ability_file: String = ""

func _on_ability_selected(index: int) -> void:
    var ability_name = ability_dropdown.get_item_text(index)

    # Find ability by name
    for ability_id in ability_definitions.keys():
        var ability = ability_definitions[ability_id]
        if ability.ability_name == ability_name:
            current_ability = ability
            current_ability_file = ability_file_paths[ability_id]
            _load_ability_to_editor(ability)
            break

func _load_ability_to_editor(ability: BaseAbility) -> void:
    # Populate fields with ability data
    name_field.text = ability.ability_name
    damage_spinner.value = ability.base_damage
    cooldown_spinner.value = ability.cooldown

    # Projectile count only if this is ProjectileAbility
    if ability is ProjectileAbility:
        projectile_spinner.value = ability.projectile_count
        projectile_spinner.visible = true
    else:
        projectile_spinner.visible = false

    # Display tags
    tags_label.text = ", ".join(ability.tags)

    # Update file info
    file_path_label.text = current_ability_file
    last_saved_label.text = "Not modified"
```

**3. Save Buttons**
```gdscript
func _on_save_to_file_pressed() -> void:
    if not current_ability:
        Logger.warn("No ability selected for save", "debug")
        return

    # Update ability data from editor fields
    current_ability.ability_name = name_field.text
    current_ability.base_damage = damage_spinner.value
    current_ability.cooldown = cooldown_spinner.value

    if current_ability is ProjectileAbility:
        current_ability.projectile_count = int(projectile_spinner.value)

    # Save to .tres file
    var save_result = ResourceSaver.save(current_ability, current_ability_file)

    if save_result == OK:
        Logger.info("Saved ability: %s" % current_ability_file, "debug")
        last_saved_label.text = "Just now"
        _start_last_saved_timer()
    else:
        Logger.error("Failed to save ability: %s" % current_ability_file, "debug")

func _on_apply_to_equipped_pressed() -> void:
    """Immediately apply changes to equipped abilities in player slots"""
    if not current_ability:
        return

    # Find player
    var player = get_tree().get_first_node_in_group("players")
    if not player:
        Logger.warn("Player not found for apply to equipped", "debug")
        return

    # Update ability data from editor fields (same as save)
    current_ability.ability_name = name_field.text
    current_ability.base_damage = damage_spinner.value
    current_ability.cooldown = cooldown_spinner.value

    if current_ability is ProjectileAbility:
        current_ability.projectile_count = int(projectile_spinner.value)

    # Refresh any equipped instances with this ability_id
    for i in range(player.ability_slots.size()):
        var equipped_ability = player.ability_slots[i]
        if equipped_ability and equipped_ability.ability_id == current_ability.ability_id:
            # Re-create instance from updated definition
            player.ability_slots[i] = current_ability.duplicate(true)
            Logger.info("Applied changes to equipped slot %d" % (i + 1), "debug")

    # Optional: Save to file as well
    _on_save_to_file_pressed()
```

### RIGHT COLUMN: Slot Equipment

**1. Slot Dropdowns (4 slots)**
```gdscript
@onready var slot_dropdowns: Array[OptionButton] = [
    $RightColumn/Slot1Dropdown,
    $RightColumn/Slot2Dropdown,
    $RightColumn/Slot3Dropdown,
    $RightColumn/Slot4Dropdown
]

var selected_slot_abilities: Array[String] = ["", "", "", ""]  # ability_ids

func _populate_slot_dropdowns() -> void:
    for dropdown in slot_dropdowns:
        dropdown.clear()
        dropdown.add_item("(None)")  # First option is empty slot

        # Add all available abilities
        for ability_id in ability_definitions.keys():
            var ability = ability_definitions[ability_id]
            dropdown.add_item(ability.ability_name)

func _on_slot_dropdown_selected(slot_index: int, item_index: int) -> void:
    var dropdown = slot_dropdowns[slot_index]

    if item_index == 0:
        # "(None)" selected
        selected_slot_abilities[slot_index] = ""
    else:
        # Find ability by name
        var ability_name = dropdown.get_item_text(item_index)
        for ability_id in ability_definitions.keys():
            if ability_definitions[ability_id].ability_name == ability_name:
                selected_slot_abilities[slot_index] = ability_id
                break

    Logger.debug("Slot %d: %s" % [slot_index + 1, selected_slot_abilities[slot_index]], "debug")
```

**2. Equip Button**
```gdscript
func _on_equip_selected_abilities_pressed() -> void:
    # Find player
    var player = get_tree().get_first_node_in_group("players")
    if not player:
        Logger.warn("Player not found for ability equip", "debug")
        return

    # Equip abilities to player slots
    for i in range(4):
        var ability_id = selected_slot_abilities[i]

        if ability_id.is_empty():
            # Empty slot
            player.ability_slots[i] = null
        else:
            # Create instance from definition
            var definition = ability_definitions[ability_id]
            player.ability_slots[i] = definition.duplicate(true)

        Logger.info("Equipped slot %d: %s" % [i + 1, ability_id if not ability_id.is_empty() else "(None)"], "debug")

    # Refresh "Current Equipped" display
    _refresh_equipped_display()

func _refresh_equipped_display() -> void:
    var player = get_tree().get_first_node_in_group("players")
    if not player:
        return

    var display_text = ""
    for i in range(player.ability_slots.size()):
        var ability = player.ability_slots[i]
        if ability:
            display_text += "Slot %d: %s (Lv %d)\n" % [i + 1, ability.ability_name, ability.ability_level]
        else:
            display_text += "Slot %d: (Empty)\n" % (i + 1)

    equipped_info_label.text = display_text
```

**3. Testing Actions**
```gdscript
func _on_level_up_slot_pressed(slot_index: int) -> void:
    var player = get_tree().get_first_node_in_group("players")
    if not player:
        return

    var ability = player.ability_slots[slot_index]
    if ability and ability.can_level_up():
        ability.level_up(1)
        Logger.info("Leveled up slot %d to level %d" % [slot_index + 1, ability.ability_level], "debug")
        _refresh_equipped_display()

func _on_clear_all_abilities_pressed() -> void:
    var player = get_tree().get_first_node_in_group("players")
    if not player:
        return

    for i in range(player.ability_slots.size()):
        player.ability_slots[i] = null

    Logger.info("Cleared all equipped abilities", "debug")
    _refresh_equipped_display()

func _on_refresh_from_files_pressed() -> void:
    # Reload all .tres files (hot-reload)
    _populate_ability_dropdown()
    _populate_slot_dropdowns()
    Logger.info("Refreshed abilities from files", "debug")
```

---

## Implementation Plan

### Phase 1: Core Popup Structure (1 session)
- [ ] Create new scene: `scenes/debug/AbilityTestingPopup.tscn`
  - [ ] Root node: Window (900x600px)
  - [ ] PanelContainer → MarginContainer → HBoxContainer (two columns)
  - [ ] Left column: VBoxContainer (Ability Editor)
  - [ ] Right column: VBoxContainer (Slot Equipment)
- [ ] Create script: `scenes/debug/AbilityTestingPopup.gd`
- [ ] Add button to DebugPanel.tscn: "🎯 Ability Testing Tool"
- [ ] Add button connection in DebugPanel.gd (minimal changes)
- [ ] Test popup open/close functionality

### Phase 2: Ability Editor (1 session)
- [ ] Load all .tres files from `/data/content/abilities/`
- [ ] Populate dropdown with ability names
- [ ] Display selected ability parameters in editable fields
- [ ] Implement "Save to File" button (ResourceSaver)
- [ ] Add file info display (path, last saved time)

### Phase 3: Slot Equipment (1 session)
- [ ] Add 4 slot dropdowns (populate from loaded abilities)
- [ ] Implement "Equip Selected Abilities" button
- [ ] Display "Current Equipped" info
- [ ] Connect to Player.ability_slots array

### Phase 4: Testing Actions (1 session)
- [ ] Implement "Apply to Equipped" button (instant update)
- [ ] Add level-up buttons per slot
- [ ] Add "Clear All" and "Refresh" buttons
- [ ] Add "Level Up All" button (levels all equipped abilities)

### Phase 5: Polish & UX (1 session)
- [ ] Match DebugPanel styling (dark theme, rounded corners)
- [ ] Add keyboard shortcuts (Ctrl+S for save, Tab to switch fields)
- [ ] Add undo/redo support (store previous values)
- [ ] Add "Recent Changes" indicator (highlight modified fields)

---

## Technical Integration

### 1. DebugPanel.gd Modifications (MINIMAL CHANGES)

**Add button to existing panel + popup instance:**

```gdscript
# Add to existing @onready variables (around line 35)
@onready var ability_testing_btn: Button = $PanelContainer/.../AbilityTestingButton

# Popup reference (created dynamically)
var ability_testing_popup: Window = null

func _ready() -> void:
    # ... existing code (unchanged) ...

    # NEW: Connect ability testing button (add near end of _ready)
    ability_testing_btn.pressed.connect(_on_ability_testing_pressed)

    Logger.debug("DebugPanel initialized", "debug")

# NEW: Open ability testing popup
func _on_ability_testing_pressed() -> void:
    Logger.info("Ability Testing Tool button pressed", "debug")

    if ability_testing_popup and is_instance_valid(ability_testing_popup):
        # Popup already exists - bring to front
        ability_testing_popup.show()
        ability_testing_popup.move_to_foreground()
    else:
        # Create popup for first time
        _create_ability_testing_popup()

func _create_ability_testing_popup() -> void:
    # Load popup scene
    var popup_scene = preload("res://scenes/debug/AbilityTestingPopup.tscn")
    ability_testing_popup = popup_scene.instantiate()

    # Add to scene tree (as child of root to be independent)
    get_tree().root.add_child(ability_testing_popup)

    # Position popup (center of screen or offset from debug panel)
    ability_testing_popup.position = Vector2i(400, 100)

    # Connect close signal to handle cleanup
    ability_testing_popup.close_requested.connect(_on_ability_popup_closed)

    Logger.info("Ability Testing Popup created", "debug")

func _on_ability_popup_closed() -> void:
    if ability_testing_popup:
        ability_testing_popup.queue_free()
        ability_testing_popup = null
    Logger.debug("Ability Testing Popup closed", "debug")
```

**Add button to DebugPanel.tscn:**
```
In DebugPanel.tscn (via Godot Inspector):
1. Find RightColumn VBoxContainer (or wherever you want the button)
2. Add new Button node
3. Name: "AbilityTestingButton"
4. Text: "🎯 Ability Testing Tool"
5. Position: After existing buttons (clear_all, reset_session, etc.)
6. Styling: Match existing button style (applied via _apply_button_styling)
```

---

### 2. AbilityTestingPopup.tscn (New Scene)

**Create new scene at `scenes/debug/AbilityTestingPopup.tscn`:**

```
Root: Window (type = "Window")
├─ title: "Ability Testing Tool"
├─ size: Vector2i(900, 600)
├─ initial_position: WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
├─ unresizable: false (allow resize for flexibility)
├─ Script: AbilityTestingPopup.gd
│
└─ PanelContainer
    └─ MarginContainer
        └─ HBoxContainer (two columns)
            ├─ LeftColumn (VBoxContainer)
            │   ├─ Label ("Ability Editor")
            │   ├─ OptionButton (ability_dropdown)
            │   ├─ LineEdit (name_field)
            │   ├─ SpinBox (damage_spinner)
            │   ├─ SpinBox (cooldown_spinner)
            │   ├─ SpinBox (projectile_spinner)
            │   ├─ Label (tags_label)
            │   ├─ Button (save_btn: "Save to File")
            │   └─ Button (apply_btn: "Apply to Equipped")
            │
            └─ RightColumn (VBoxContainer)
                ├─ Label ("Slot Equipment")
                ├─ OptionButton (slot1_dropdown)
                ├─ OptionButton (slot2_dropdown)
                ├─ OptionButton (slot3_dropdown)
                ├─ OptionButton (slot4_dropdown)
                ├─ Button (equip_btn: "Equip Selected Abilities")
                ├─ RichTextLabel (equipped_info: Current Equipped)
                ├─ Button (level_up_all_btn: "Level Up All")
                ├─ Button (clear_all_btn: "Clear All")
                └─ Button (refresh_btn: "Refresh from Files")
```

---

### 3. AbilityTestingPopup.gd (New Script)

```gdscript
extends Window
class_name AbilityTestingPopup

## Ability debug popup for editing and testing abilities in-game
## Opened via button in DebugPanel, independent popup window

# LEFT COLUMN: Editor
@onready var ability_dropdown: OptionButton = $HBoxContainer/LeftColumn/AbilityDropdown
@onready var name_field: LineEdit = $HBoxContainer/LeftColumn/NameField
@onready var damage_spinner: SpinBox = $HBoxContainer/LeftColumn/DamageSpinner
@onready var cooldown_spinner: SpinBox = $HBoxContainer/LeftColumn/CooldownSpinner
@onready var projectile_spinner: SpinBox = $HBoxContainer/LeftColumn/ProjectileSpinner
@onready var tags_label: Label = $HBoxContainer/LeftColumn/TagsLabel
@onready var save_btn: Button = $HBoxContainer/LeftColumn/SaveButton
@onready var apply_btn: Button = $HBoxContainer/LeftColumn/ApplyButton

# RIGHT COLUMN: Equipment
@onready var slot_dropdowns: Array[OptionButton] = [
    $HBoxContainer/RightColumn/Slot1Dropdown,
    $HBoxContainer/RightColumn/Slot2Dropdown,
    $HBoxContainer/RightColumn/Slot3Dropdown,
    $HBoxContainer/RightColumn/Slot4Dropdown
]
@onready var equip_btn: Button = $HBoxContainer/RightColumn/EquipButton
@onready var equipped_info: RichTextLabel = $HBoxContainer/RightColumn/EquippedInfo

# Data
var ability_definitions: Dictionary = {}
var ability_file_paths: Dictionary = {}
var current_ability: BaseAbility = null
var current_ability_file: String = ""
var selected_slot_abilities: Array[String] = ["", "", "", ""]

func _ready() -> void:
    # Load all abilities
    _load_all_abilities()
    _populate_ability_dropdown()
    _populate_slot_dropdowns()

    # Connect signals
    ability_dropdown.item_selected.connect(_on_ability_selected)
    save_btn.pressed.connect(_on_save_to_file_pressed)
    apply_btn.pressed.connect(_on_apply_to_equipped_pressed)
    equip_btn.pressed.connect(_on_equip_selected_abilities_pressed)

    # Connect slot dropdowns
    for i in range(slot_dropdowns.size()):
        slot_dropdowns[i].item_selected.connect(_on_slot_dropdown_selected.bind(i))

    Logger.info("AbilityDebugTab initialized", "debug")

# ... (all methods from component breakdown above)
```

---

## Workflow Example

**Designer Workflow:**
```
1. Designer opens debug panel (F3)
2. Switches to "Abilities" tab
3. Selects "Fireball" from dropdown
4. Sees current values:
   - Base Damage: 25.0
   - Cooldown: 1.5
   - Projectile Count: 1
5. Changes damage to 30.0
6. Changes projectile count to 3
7. Clicks "Save to File" (writes to fireball.tres)
8. Clicks "Apply to Equipped" (if Fireball is equipped, updates immediately)
9. Tests in-game (fires 3 projectiles at 30 damage each)
10. Adjusts cooldown to 1.0
11. Saves again
12. Tests again (faster fire rate)
```

**Iteration Time:** ~5 seconds (edit → save → test)
**No restarts, no Shift+F5, no external editor needed!**

---

## Next Steps

1. **Review this design** - Does this match your vision?
2. **Choose integration option** - Tab system (A), separate panel (B), or collapsible (C)?
3. **Implement Phase 1** - Basic tab structure + dropdown
4. **Test workflow** - Edit one ability, save, test in-game

**Ready to implement?** Let me know if you'd like me to:
- Proceed with implementation (Phase 1)
- Adjust the design
- Add more features (power-up testing, visual preview, etc.)
