extends Resource
class_name ItemMetadata

## Item metadata for discovery & unlock system
## Used by MetaProgression and UnlocksShop
## Files stored in: /data/content/items/*.tres

enum Rarity {
	COMMON = 0,
	UNCOMMON = 1,
	RARE = 2,
	EPIC = 3,
	LEGENDARY = 4
}

@export var item_id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export_multiline var flavor_text: String = ""
@export var category: String = "items"  # "items", "skills", "tomes"
@export var icon_path: String = ""
@export var unlock_cost: int = 100  # Rift Fragments cost
@export var rarity: Rarity = Rarity.COMMON

## Achievement requirement to discover this item (shown in details panel)
@export_multiline var discovery_requirement: String = ""  # e.g., "Deal 1000 critical hits"

## Optional: Stats for display
@export var stat_summary: String = ""  # e.g., "+10% Damage"

## Get rarity color for UI display
static func get_rarity_color(rarity_value: Rarity) -> Color:
	match rarity_value:
		Rarity.COMMON:
			return Color(0.6, 0.6, 0.6)  # Grey
		Rarity.UNCOMMON:
			return Color(0.3, 0.9, 0.3)  # Green
		Rarity.RARE:
			return Color(0.3, 0.5, 1.0)  # Blue
		Rarity.EPIC:
			return Color(0.7, 0.3, 1.0)  # Purple
		Rarity.LEGENDARY:
			return Color(1.0, 0.8, 0.2)  # Gold
		_:
			return Color.WHITE

## Get rarity name as string
static func get_rarity_name(rarity_value: Rarity) -> String:
	match rarity_value:
		Rarity.COMMON:
			return "Common"
		Rarity.UNCOMMON:
			return "Uncommon"
		Rarity.RARE:
			return "Rare"
		Rarity.EPIC:
			return "Epic"
		Rarity.LEGENDARY:
			return "Legendary"
		_:
			return "Unknown"

func _init() -> void:
	pass
