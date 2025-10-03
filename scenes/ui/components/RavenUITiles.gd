extends RefCounted
class_name RavenUITiles

## Helper to use Raven UI TileSet for UI components
## No manual slicing or coordinate measuring required!

const TILESET := preload("res://assets/ui/raven_ui_tileset.tres")

# Tile coordinates - Update these after creating TileSet
# Format: Vector2i(column, row) starting from (0, 0) at top-left
# Hover over tiles in TileSet editor to find coordinates

# Panels (Row 0) - Adjust based on your actual tile layout
const TILE_PANEL_BROWN_LARGE := Vector2i(0, 0)
const TILE_PANEL_BEIGE_LARGE := Vector2i(1, 0)
const TILE_PANEL_PURPLE_LARGE := Vector2i(2, 0)

# Buttons (Row 1) - Adjust based on your actual tile layout
const TILE_BUTTON_NORMAL := Vector2i(2, 1)
const TILE_BUTTON_HOVER := Vector2i(3, 1)
const TILE_BUTTON_PRESSED := Vector2i(4, 1)

# Hearts (Row 2) - Adjust based on your actual tile layout
const TILE_HEART_FULL := Vector2i(0, 2)
const TILE_HEART_HALF := Vector2i(1, 2)
const TILE_HEART_EMPTY := Vector2i(2, 2)

# Bars (Row 1) - Adjust based on your actual tile layout
const TILE_HP_BAR_BG := Vector2i(0, 1)
const TILE_HP_BAR_FILL := Vector2i(1, 1)
const TILE_XP_BAR_FILL := Vector2i(2, 1)

# Icons (Row 2+) - Adjust based on your actual tile layout
const TILE_COIN := Vector2i(3, 2)
const TILE_SKULL := Vector2i(4, 2)
const TILE_SWORD := Vector2i(5, 2)
const TILE_SHIELD := Vector2i(6, 2)

## Get texture for a specific tile coordinate
static func get_tile_texture(tile_coords: Vector2i) -> AtlasTexture:
	if not TILESET:
		push_error("RavenUITiles: TileSet not loaded!")
		return null

	# Get atlas source (first and only)
	var source_id = TILESET.get_source_id(0)
	var atlas: TileSetAtlasSource = TILESET.get_source(source_id)

	if not atlas:
		push_error("RavenUITiles: Atlas source not found!")
		return null

	# Get texture region for this tile
	var region = atlas.get_tile_texture_region(tile_coords)

	# Create AtlasTexture
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = atlas.texture
	atlas_texture.region = region

	return atlas_texture

## Create a TextureRect with a specific tile
static func create_texture_rect(tile_coords: Vector2i, size: Vector2 = Vector2.ZERO) -> TextureRect:
	var tex_rect = TextureRect.new()
	tex_rect.texture = get_tile_texture(tile_coords)

	if size != Vector2.ZERO:
		tex_rect.custom_minimum_size = size

	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

	return tex_rect

## Configure a NinePatchRect with a specific tile
static func configure_ninepatch(
	ninepatch: NinePatchRect,
	tile_coords: Vector2i,
	margins: Vector4i
) -> void:
	ninepatch.texture = get_tile_texture(tile_coords)

	ninepatch.patch_margin_left = margins.x
	ninepatch.patch_margin_top = margins.y
	ninepatch.patch_margin_right = margins.z
	ninepatch.patch_margin_bottom = margins.w

	# Tile mode for pixel-perfect scaling
	ninepatch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	ninepatch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE

## Create a StyleBoxTexture for themes (buttons, panels)
static func create_stylebox(tile_coords: Vector2i, margins: Vector4i) -> StyleBoxTexture:
	var stylebox = StyleBoxTexture.new()
	stylebox.texture = get_tile_texture(tile_coords)

	stylebox.texture_margin_left = margins.x
	stylebox.texture_margin_top = margins.y
	stylebox.texture_margin_right = margins.z
	stylebox.texture_margin_bottom = margins.w

	return stylebox
