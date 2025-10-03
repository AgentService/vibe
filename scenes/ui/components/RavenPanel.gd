extends Control
class_name RavenPanel

## Reusable panel using Raven UI TileSet
## No manual slicing or measuring required!

enum PanelStyle {
	BROWN_LEATHER,   # Main UI panels
	BEIGE_PARCHMENT, # Info panels
	PURPLE_MYSTICAL  # Special/shop panels
}

@export var panel_style: PanelStyle = PanelStyle.BROWN_LEATHER
@export var padding: int = 20
@export var min_size: Vector2 = Vector2(200, 200)

@onready var background_panel: NinePatchRect = $BackgroundPanel
@onready var content_margin: MarginContainer = $BackgroundPanel/ContentMargin
@onready var content_container: VBoxContainer = $BackgroundPanel/ContentMargin/ContentContainer

# Tile coordinate mappings per style
const PANEL_TILES = {
	PanelStyle.BROWN_LEATHER: RavenUITiles.TILE_PANEL_BROWN_LARGE,
	PanelStyle.BEIGE_PARCHMENT: RavenUITiles.TILE_PANEL_BEIGE_LARGE,
	PanelStyle.PURPLE_MYSTICAL: RavenUITiles.TILE_PANEL_PURPLE_LARGE
}

# Standard patch margins (16px for 96×96 panels)
const PANEL_MARGINS := Vector4i(16, 16, 16, 16)

func _ready() -> void:
	_apply_panel_style()
	_configure_padding()

func _apply_panel_style() -> void:
	var tile_coords = PANEL_TILES[panel_style]
	RavenUITiles.configure_ninepatch(background_panel, tile_coords, PANEL_MARGINS)
	custom_minimum_size = min_size

func _configure_padding() -> void:
	content_margin.add_theme_constant_override("margin_left", padding)
	content_margin.add_theme_constant_override("margin_top", padding)
	content_margin.add_theme_constant_override("margin_right", padding)
	content_margin.add_theme_constant_override("margin_bottom", padding)

func get_content_container() -> VBoxContainer:
	"""Return the container where UI elements should be added."""
	return content_container

func set_panel_title(title: String) -> void:
	"""Add a title label to the top of the panel."""
	var title_label = Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 24)
	content_container.add_child(title_label)
	content_container.move_child(title_label, 0)
