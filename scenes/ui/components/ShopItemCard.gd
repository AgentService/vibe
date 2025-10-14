extends Control
class_name ShopItemCard

## Reusable shop item card component with hover and selection states
## Used in UnlockShop to display items, tomes, skills, and characters

signal item_clicked(item_id: String, category: String)
signal item_hovered(item_id: String, category: String)

@onready var button: Button = $Frame/MarginContainer/Button
@onready var icon_texture: TextureRect = $Frame/MarginContainer/Button/CenterContainer/IconTexture
@onready var overlay_container: Control = $OverlayContainer
@onready var dim_overlay: ColorRect = $OverlayContainer/DimOverlay
@onready var cost_label: Label = $OverlayContainer/CostLabel

var item_id: String = ""
var category: String = ""
var _is_initialized: bool = false
var _is_selected: bool = false

# Store data if setup() is called before _ready()
var _pending_metadata: Variant = null  # Can be ItemMetadata, BaseTome, or BaseItem
var _pending_is_discovered: bool = false
var _pending_is_unlocked: bool = false
var _pending_can_afford: bool = false

func _ready() -> void:
	# Connect button signals
	if button:
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)
		if not button.mouse_entered.is_connected(_on_button_hovered):
			button.mouse_entered.connect(_on_button_hovered)

	# Hide overlay by default
	if overlay_container:
		overlay_container.visible = false

	# Apply pending data if setup() was called before _ready()
	if _pending_metadata:
		_apply_data(_pending_metadata, _pending_is_discovered, _pending_is_unlocked, _pending_can_afford)
		_pending_metadata = null

func setup(metadata: Variant, is_discovered: bool, is_unlocked: bool, can_afford: bool) -> void:
	"""Initialize the card with item metadata and state.

	Args:
		metadata: ItemMetadata, BaseTome, or BaseItem resource with item data
		is_discovered: Whether item has been discovered
		is_unlocked: Whether item is unlocked
		can_afford: Whether player can afford to unlock (only relevant if discovered+locked)
	"""
	# Duck typing: Get item_id from metadata
	# Different content types use different ID property names:
	# - BaseTome: tome_id
	# - BaseAbility: ability_id
	# - BaseItem: item_id
	# - BaseCharacter: character_id
	# - ItemMetadata: item_id
	if metadata is BaseTome:
		item_id = metadata.tome_id
	elif metadata is BaseAbility:
		item_id = metadata.ability_id
	elif metadata is BaseCharacter:
		item_id = metadata.character_id
	elif "item_id" in metadata:
		item_id = metadata.item_id
	else:
		Logger.warn("ShopItemCard: Unknown metadata type: %s" % str(metadata.get_class()), "ui")
		return

	category = metadata.category
	_is_initialized = true

	# If nodes are ready, apply immediately
	if icon_texture and button:
		_apply_data(metadata, is_discovered, is_unlocked, can_afford)
	else:
		# Store for later (will be applied in _ready())
		_pending_metadata = metadata
		_pending_is_discovered = is_discovered
		_pending_is_unlocked = is_unlocked
		_pending_can_afford = can_afford

func _apply_data(metadata: Variant, is_discovered: bool, is_unlocked: bool, can_afford: bool) -> void:
	"""Apply item data and state to UI elements."""
	# Load icon texture if available (duck typing: icon_path or icon)
	var texture: Texture2D = null

	if metadata is ItemMetadata and "icon_path" in metadata:
		if not metadata.icon_path.is_empty() and ResourceLoader.exists(metadata.icon_path):
			texture = load(metadata.icon_path)
	elif "icon" in metadata and metadata.icon:
		# BaseTome and BaseItem use direct icon: Texture2D reference
		texture = metadata.icon

	# Apply rarity tint to button background (duck typing: rarity is string for all types)
	var rarity_name: String = metadata.rarity if "rarity" in metadata else "common"
	if metadata is ItemMetadata:
		rarity_name = ItemMetadata.get_rarity_name(metadata.rarity)

	_apply_rarity_tint(rarity_name)

	# State-based visual appearance
	if is_unlocked:
		_apply_unlocked_state(texture)
	elif not is_discovered:
		_apply_undiscovered_state(texture)
	else:
		_apply_discovered_locked_state(texture, metadata.unlock_cost, can_afford)

func _apply_unlocked_state(texture: Texture2D) -> void:
	"""Apply unlocked visual state: full color icon, no overlay."""
	if icon_texture:
		icon_texture.texture = texture
		icon_texture.modulate = Color.WHITE

	if overlay_container:
		overlay_container.visible = false

func _apply_undiscovered_state(texture: Texture2D) -> void:
	"""Apply undiscovered visual state: black silhouette."""
	if icon_texture:
		icon_texture.texture = texture
		icon_texture.modulate = Color(0.0, 0.0, 0.0)

	if overlay_container:
		overlay_container.visible = false

func _apply_discovered_locked_state(texture: Texture2D, cost: int, can_afford: bool) -> void:
	"""Apply discovered+locked visual state: full color icon with dim overlay and cost."""
	if icon_texture:
		icon_texture.texture = texture
		icon_texture.modulate = Color.WHITE

	# Show overlay with cost
	if overlay_container and dim_overlay and cost_label:
		overlay_container.visible = true
		dim_overlay.visible = true
		dim_overlay.color = Color(0, 0, 0, 0.50)

		cost_label.visible = true
		cost_label.text = "💎 %d" % cost
		cost_label.modulate = Color.WHITE if can_afford else Color(1.0, 0.5, 0.5)

func _apply_rarity_tint(rarity: String) -> void:
	"""Apply subtle rarity-based tint to button background."""
	if not button:
		return

	# Note: Rarity tinting disabled for now as it was making icons look faded
	# The button.modulate with alpha < 1.0 affects all children (including icon)
	# TODO: Implement rarity border or background color using button theme overrides
	pass

func set_selected(selected: bool) -> void:
	"""Update visual state when card is selected/deselected.

	Args:
		selected: Whether this card should appear selected
	"""
	_is_selected = selected

	if button:
		if selected:
			# Apply pressed/focused appearance
			button.button_pressed = true
		else:
			# Remove pressed appearance
			button.button_pressed = false

func _on_button_pressed() -> void:
	"""Emit signal when button is clicked."""
	if _is_initialized:
		item_clicked.emit(item_id, category)

func _on_button_hovered() -> void:
	"""Emit signal when button is hovered."""
	if _is_initialized:
		item_hovered.emit(item_id, category)
