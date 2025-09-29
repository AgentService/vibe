extends RefCounted

## Payload for arena_path_snapshot_ready signal - path-aware arena data ready.
## Emitted when PathAware_Forest completes generation and path snapshot is available.
## Provides compile-time type safety for spawning system coordination.

class_name ArenaPathSnapshotReadyPayload

var arena_id: String
var path_snapshot: PathAwarePathSnapshot

func _init(id: String, snapshot: PathAwarePathSnapshot) -> void:
	arena_id = id
	path_snapshot = snapshot

func _to_string() -> String:
	var snapshot_summary = path_snapshot.get_debug_summary() if path_snapshot else "null"
	return "ArenaPathSnapshotReadyPayload(arena_id=%s, snapshot=%s)" % [arena_id, snapshot_summary]