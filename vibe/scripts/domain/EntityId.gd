extends RefCounted

## Typed entity identifier for decoupled cross-system communication.
## Avoids Node references and provides stable, serializable entity IDs.

class_name EntityId

enum Type {
	PLAYER,
	ENEMY,
	PROJECTILE,
	XP_ORB,
	ITEM
}

var type: Type
var index: int

func _init(entity_type: Type, entity_index: int) -> void:
	type = entity_type
	index = entity_index

func _to_string() -> String:
	return "%s:%d" % [Type.keys()[type], index]

static func player() -> EntityId:
	return EntityId.new(Type.PLAYER, 0)

static func enemy(idx: int) -> EntityId:
	return EntityId.new(Type.ENEMY, idx)

static func projectile(idx: int) -> EntityId:
	return EntityId.new(Type.PROJECTILE, idx)

static func xp_orb(idx: int) -> EntityId:
	return EntityId.new(Type.XP_ORB, idx)

static func item(idx: int) -> EntityId:
	return EntityId.new(Type.ITEM, idx)

func equals(other: EntityId) -> bool:
	return type == other.type and index == other.index

func hash() -> int:
	return type * 10000 + index