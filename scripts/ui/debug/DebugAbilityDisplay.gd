## DebugAbilityDisplay.gd
## Debug UI component for visualizing ability system state in real-time.
##
## Shows:
## - Equipped abilities (name, level, cooldown timers)
## - Equipped tomes (name, stack count)
## - Updates every frame for live feedback during development
##
## Usage:
##   Add as child of Player node in Player.tscn
##   Position above player (Y offset -100)
##   Enable/disable via DebugSettings
extends Label

# ============================================================================
# CONFIGURATION
# ============================================================================

## Player reference (auto-detected from "player" group)
var _player: Node2D = null

## Reference to player's AbilityController
var _ability_controller: RefCounted = null

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	# Wait one frame to ensure parent's _ready() has completed
	# (Child _ready() runs before parent _ready() in Godot)
	await get_tree().process_frame

	# Get player reference from parent (this label is a child of the player)
	_player = get_parent()

	if not _player:
		visible = false
		return

	# Get AbilityController reference
	if "ability_controller" in _player:
		_ability_controller = _player.ability_controller

	if not _ability_controller:
		visible = false
		return

	# Setup label styling
	_setup_label_styling()


## Sets up label appearance for readability
func _setup_label_styling() -> void:
	# Monospace font for aligned columns
	add_theme_font_size_override("font_size", 14)

	# White text with black outline for contrast
	add_theme_color_override("font_color", Color.WHITE)
	add_theme_color_override("font_outline_color", Color.BLACK)
	add_theme_constant_override("outline_size", 2)

	# Align text
	horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	vertical_alignment = VERTICAL_ALIGNMENT_TOP


# ============================================================================
# UPDATE LOOP
# ============================================================================

func _process(_delta: float) -> void:
	if not _player or not _ability_controller:
		return

	# Build display string
	var display_text := _build_display_string()
	text = display_text


## Builds formatted display string showing ability system state
func _build_display_string() -> String:
	var lines: PackedStringArray = []

	# Abilities section
	lines.append("[Abilities]")
	lines.append_array(_build_ability_lines())

	# Spacing
	lines.append("")

	# Tomes section
	lines.append("[Tomes]")
	lines.append_array(_build_tome_lines())

	return "\n".join(lines)


## Builds lines for ability display
func _build_ability_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var ability_slots: Array = _ability_controller.ability_slots
	var ability_cooldowns: Array = _ability_controller.ability_cooldowns

	for i in range(ability_slots.size()):
		var ability = ability_slots[i]

		if not ability:
			lines.append("[%d] Empty" % i)
			continue

		# Format: [0] Ranger Arrow Lv3 (CD: 0.5s)
		var ability_name: String = ability.ability_name
		var ability_level: int = ability.ability_level
		var cooldown: float = ability_cooldowns[i]

		var cooldown_str := "READY" if cooldown <= 0.0 else "%.1fs" % cooldown
		lines.append("[%d] %s Lv%d (CD: %s)" % [i, ability_name, ability_level, cooldown_str])

	return lines


## Builds lines for tome display
func _build_tome_lines() -> PackedStringArray:
	var lines: PackedStringArray = []

	var tome_slots: Array = _ability_controller.tome_slots
	var tome_stacks: Array = _ability_controller.tome_stacks

	for i in range(tome_slots.size()):
		var tome = tome_slots[i]

		if not tome:
			lines.append("[%d] Empty" % i)
			continue

		# Format: [0] Tome of Power ×3
		var tome_name: String = tome.tome_name
		var stack_count: int = tome_stacks[i]
		lines.append("[%d] %s ×%d" % [i, tome_name, stack_count])

	return lines
