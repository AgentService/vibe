extends Resource
class_name ItemMetadata

## Item metadata for discovery & unlock system
## Used by MetaProgression and UnlocksShop
## Files stored in: /data/content/items/*.tres

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_multiline var flavor_text: String = ""
@export var category: String = "items"  # "items", "skills", "tomes"
@export var icon_path: String = ""
@export var unlock_cost: int = 100  # Rift Fragments cost
@export_enum("Common", "Uncommon", "Rare", "Epic", "Legendary") var rarity: String = "Common"

## Optional: Stats for display
@export var stat_summary: String = ""  # e.g., "+10% Damage"

func _init() -> void:
	pass
