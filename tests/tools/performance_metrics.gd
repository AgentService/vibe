class_name PerformanceMetrics
extends RefCounted

## Performance metrics tracking utility for stress tests
## Provides FPS monitoring, memory sampling, and statistical analysis

# FPS tracking with moving averages
var fps_samples: Array[float] = []
var fps_window_size: int = 60  # 2 seconds at 30 FPS
var frame_time_samples: Array[float] = []
var target_fps: float = 30.0

# Memory tracking
var initial_memory: int = 0
var peak_memory: int = 0
var memory_samples: Array[int] = []
var memory_sample_interval: float = 1.0  # Sample every 1 second
var last_memory_sample_time: float = 0.0

# Test timing
var test_start_time: float = 0.0
var test_duration: float = 0.0

# Performance counters
var total_frames: int = 0
var frames_below_target: int = 0
var frame_spikes: int = 0  # Frames > 50ms
var memory_growth: int = 0

func start_test() -> void:
	print("=== PERFORMANCE METRICS STARTED ===")
	test_start_time = Time.get_unix_time_from_system()
	initial_memory = _get_memory_usage()
	peak_memory = initial_memory
	memory_samples.clear()
	fps_samples.clear()
	frame_time_samples.clear()
	total_frames = 0
	frames_below_target = 0
	frame_spikes = 0
	last_memory_sample_time = test_start_time
	
	memory_samples.append(initial_memory)
	print("Initial memory usage: %.2f MB" % (initial_memory / 1024.0 / 1024.0))

func update_frame_metrics(delta: float) -> void:
	total_frames += 1
	var current_fps = 1.0 / delta if delta > 0 else 60.0
	var frame_time_ms = delta * 1000.0
	
	# Track FPS
	fps_samples.append(current_fps)
	if fps_samples.size() > fps_window_size:
		fps_samples.pop_front()
	
	# Track frame times
	frame_time_samples.append(frame_time_ms)
	
	# Count performance issues
	if current_fps < target_fps:
		frames_below_target += 1
	
	if frame_time_ms > 50.0:  # > 50ms indicates frame spike
		frame_spikes += 1
	
	# Sample memory periodically
	var current_time = Time.get_unix_time_from_system()
	if current_time - last_memory_sample_time >= memory_sample_interval:
		_sample_memory()
		last_memory_sample_time = current_time

func end_test() -> Dictionary:
	test_duration = Time.get_unix_time_from_system() - test_start_time
	memory_growth = peak_memory - initial_memory
	
	var results = {
		"duration_seconds": test_duration,
		"total_frames": total_frames,
		"average_fps": _calculate_average_fps(),
		"min_fps": _calculate_min_fps(),
		"frames_below_target": frames_below_target,
		"frame_spikes": frame_spikes,
		"fps_stability": _calculate_fps_stability(),
		"frame_time_95th_percentile": _calculate_percentile(frame_time_samples, 95),
		"frame_time_99th_percentile": _calculate_percentile(frame_time_samples, 99),
		"initial_memory_mb": initial_memory / 1024.0 / 1024.0,
		"peak_memory_mb": peak_memory / 1024.0 / 1024.0,
		"memory_growth_mb": memory_growth / 1024.0 / 1024.0,
		"average_memory_mb": _calculate_average_memory() / 1024.0 / 1024.0,
		"test_passed": _evaluate_test_results()
	}
	
	print("=== PERFORMANCE METRICS COMPLETE ===")
	print_test_results(results)
	
	return results

func print_test_results(results: Dictionary) -> void:
	print("\n=== PERFORMANCE TEST RESULTS ===")
	print("Test Duration: %.2f seconds" % results.duration_seconds)
	print("Total Frames: %d" % results.total_frames)
	print("Average FPS: %.1f" % results.average_fps)
	print("Minimum FPS: %.1f" % results.min_fps)
	print("FPS Stability: %.1f%%" % results.fps_stability)
	print("Frames Below Target (30 FPS): %d (%.1f%%)" % [results.frames_below_target, (results.frames_below_target * 100.0 / results.total_frames)])
	print("Frame Spikes (>50ms): %d (%.1f%%)" % [results.frame_spikes, (results.frame_spikes * 100.0 / results.total_frames)])
	print("Frame Time 95th Percentile: %.2f ms" % results.frame_time_95th_percentile)
	print("Frame Time 99th Percentile: %.2f ms" % results.frame_time_99th_percentile)
	print("Initial Memory: %.2f MB" % results.initial_memory_mb)
	print("Peak Memory: %.2f MB" % results.peak_memory_mb)
	print("Memory Growth: %.2f MB" % results.memory_growth_mb)
	print("Average Memory: %.2f MB" % results.average_memory_mb)
	print("\n=== TEST EVALUATION ===")
	if results.test_passed:
		print("✓ PASSED: Performance requirements met")
	else:
		print("✗ FAILED: Performance requirements not met")
	print_pass_fail_criteria(results)

func print_pass_fail_criteria(results: Dictionary) -> void:
	print("\nPass/Fail Breakdown:")
	
	# FPS requirement: ≥30 FPS average
	var fps_pass = results.average_fps >= 30.0
	print("  Average FPS ≥30: %s (%.1f)" % ["✓" if fps_pass else "✗", results.average_fps])
	
	# Frame time requirement: <33.3ms 95th percentile  
	var frame_time_pass = results.frame_time_95th_percentile < 33.3
	print("  Frame Time 95th < 33.3ms: %s (%.2f ms)" % ["✓" if frame_time_pass else "✗", results.frame_time_95th_percentile])
	
	# Memory growth requirement: <50MB
	var memory_pass = results.memory_growth_mb < 50.0
	print("  Memory Growth < 50MB: %s (%.2f MB)" % ["✓" if memory_pass else "✗", results.memory_growth_mb])
	
	# FPS stability requirement: >90% frames at target
	var stability_pass = results.fps_stability > 90.0
	print("  FPS Stability > 90%%: %s (%.1f%%)" % ["✓" if stability_pass else "✗", results.fps_stability])

func export_baseline_csv(filename: String, results: Dictionary) -> void:
	# Convert to absolute path if it's a resource path
	var abs_filename = filename
	if filename.begins_with("res://"):
		abs_filename = ProjectSettings.globalize_path(filename)
	
	var file = FileAccess.open(abs_filename, FileAccess.WRITE)
	if not file:
		print("ERROR: Could not create baseline file: " + abs_filename)
		return
	
	# Write CSV header
	file.store_line("timestamp,duration_seconds,total_frames,average_fps,min_fps,fps_stability,frame_time_95th_percentile,initial_memory_mb,peak_memory_mb,memory_growth_mb,test_passed")
	
	# Write results
	var timestamp = Time.get_datetime_string_from_system()
	var line = "%s,%.2f,%d,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%.2f,%s" % [
		timestamp,
		results.duration_seconds,
		results.total_frames,
		results.average_fps,
		results.min_fps,
		results.fps_stability,
		results.frame_time_95th_percentile,
		results.initial_memory_mb,
		results.peak_memory_mb,
		results.memory_growth_mb,
		"PASS" if results.test_passed else "FAIL"
	]
	file.store_line(line)
	file.close()
	
	print("Baseline metrics exported to: " + abs_filename)

func _get_memory_usage() -> int:
	return OS.get_static_memory_usage()

func _sample_memory() -> void:
	var current_memory = _get_memory_usage()
	memory_samples.append(current_memory)
	if current_memory > peak_memory:
		peak_memory = current_memory

func _calculate_average_fps() -> float:
	if fps_samples.is_empty():
		return 0.0
	
	var sum = 0.0
	for fps in fps_samples:
		sum += fps
	return sum / fps_samples.size()

func _calculate_min_fps() -> float:
	if fps_samples.is_empty():
		return 0.0
	
	var min_fps = fps_samples[0]
	for fps in fps_samples:
		if fps < min_fps:
			min_fps = fps
	return min_fps

func _calculate_fps_stability() -> float:
	if total_frames == 0:
		return 0.0
	
	var frames_at_target = total_frames - frames_below_target
	return (frames_at_target * 100.0) / total_frames

func _calculate_average_memory() -> float:
	if memory_samples.is_empty():
		return 0.0
		
	var sum = 0
	for memory in memory_samples:
		sum += memory
	return sum / float(memory_samples.size())

func _calculate_percentile(samples: Array[float], percentile: int) -> float:
	if samples.is_empty():
		return 0.0
	
	var sorted_samples = samples.duplicate()
	sorted_samples.sort()
	
	var index = int((percentile / 100.0) * (sorted_samples.size() - 1))
	return sorted_samples[index]

func _evaluate_test_results() -> bool:
	var fps_pass = _calculate_average_fps() >= 30.0
	var frame_time_pass = _calculate_percentile(frame_time_samples, 95) < 33.3
	var memory_pass = (memory_growth / 1024.0 / 1024.0) < 50.0
	var stability_pass = _calculate_fps_stability() > 90.0
	
	return fps_pass and frame_time_pass and memory_pass and stability_pass