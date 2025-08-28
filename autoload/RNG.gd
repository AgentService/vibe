extends Node
class_name RngService

## Deterministic RNG singleton with named streams.
## 
## RNG Strategy (Decision 6A):
## - `seed_run(run_seed: int)` stores master seed for the run
## - `stream(name: String)` returns stable substream via hash(run_seed, name)
## - Streams: `crit`, `loot`, `waves`, `ai`, `craft`
## - No direct calls to `randi()`; always via a stream
##
## Usage:
##   RNG.seed_run(12345)
##   var crit_rng = RNG.stream("crit")
##   var is_crit = crit_rng.randf() < 0.25
##   # Or use helpers:
##   var is_crit = RNG.randf("crit") < 0.25

var _master_seed: int = 0
var _streams: Dictionary = {}

func seed_run(run_seed: int) -> void:
	_master_seed = run_seed
	_streams.clear()

func stream(stream_name: String) -> RandomNumberGenerator:
	if not _streams.has(stream_name):
		var rng := RandomNumberGenerator.new()
		var stream_seed := _hash_seed(stream_name)
		rng.seed = stream_seed
		_streams[stream_name] = rng
	return _streams[stream_name]

func randf(stream_name: String) -> float:
	return stream(stream_name).randf()

func randf_range(stream_name: String, from: float, to: float) -> float:
	return stream(stream_name).randf_range(from, to)

func randi(stream_name: String) -> int:
	return stream(stream_name).randi()

func randi_range(stream_name: String, from: int, to: int) -> int:
	return stream(stream_name).randi_range(from, to)

func _hash_seed(stream_name: String) -> int:
	var combined := str(_master_seed) + stream_name
	return combined.hash()