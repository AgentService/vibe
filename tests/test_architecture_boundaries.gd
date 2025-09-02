extends SceneTree

# Architecture Boundary Validation Test
# Detects violations of the layered architecture rules defined in ARCHITECTURE.md

class_name ArchitectureBoundaryTest

const LAYER_PATHS := {
	"scenes": "scenes/",
	"systems": "scripts/systems/",
	"domain": "scripts/domain/",
	"autoload": "autoload/"
}

var violations: Array[Dictionary] = []

func _initialize() -> void:
	print("🔍 Starting architecture boundary validation...")
	
	# Clear previous results
	violations.clear()
	
	# Scan all .gd files for boundary violations
	_scan_project_files()
	
	# Report results
	_report_violations()
	
	# Exit with appropriate code
	if violations.size() > 0:
		print("❌ Architecture violations detected: " + str(violations.size()))
		quit(1)
	else:
		print("✅ Architecture boundaries validated successfully")
		quit(0)

func _scan_project_files() -> void:
	var files := _get_all_gd_files(".")
	
	for file_path in files:
		_validate_file(file_path)

func _get_all_gd_files(directory: String) -> Array[String]:
	var files: Array[String] = []
	var dir := DirAccess.open(directory)
	
	if dir == null:
		print("❌ Cannot open directory: " + directory)
		return files
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		var full_path := directory + "/" + file_name
		
		if dir.current_is_dir() and not file_name.begins_with("."):
			files.append_array(_get_all_gd_files(full_path))
		elif file_name.ends_with(".gd"):
			files.append(full_path)
		
		file_name = dir.get_next()
	
	return files

func _validate_file(file_path: String) -> void:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		print("⚠️ Cannot read file: " + file_path)
		return
	
	var content := file.get_as_text()
	file.close()
	
	var layer := _determine_layer(file_path)
	if layer == "":
		return  # Not in a tracked layer
	
	_check_layer_violations(file_path, content, layer)

func _determine_layer(file_path: String) -> String:
	for layer_name in LAYER_PATHS:
		if file_path.find(LAYER_PATHS[layer_name]) != -1:
			return layer_name
	return ""

func _check_layer_violations(file_path: String, content: String, layer: String) -> void:
	var lines := content.split("\n")
	
	for i in range(lines.size()):
		var line := lines[i].strip_edges()
		var line_number := i + 1
		
		# Check for forbidden patterns based on layer
		match layer:
			"systems":
				_check_systems_violations(file_path, line, line_number)
			"domain":
				_check_domain_violations(file_path, line, line_number)
			"scenes":
				_check_scenes_violations(file_path, line, line_number)

func _check_systems_violations(file_path: String, line: String, line_number: int) -> void:
	# Systems must not use get_node() to access scenes
	if line.find("get_node(") != -1 and line.find("../") != -1:
		_add_violation(file_path, line_number, "SYSTEMS_NO_SCENE_ACCESS", 
			"Systems must not use get_node() to access parent scenes. Use signals instead.")
	
	# Systems must not import scenes
	if line.begins_with("@onready") and line.find("scenes/") != -1:
		_add_violation(file_path, line_number, "SYSTEMS_NO_SCENE_IMPORT",
			"Systems must not import scene files. Use dependency injection or signals.")

func _check_domain_violations(file_path: String, line: String, line_number: int) -> void:
	# Domain must not import scenes or systems
	if line.begins_with("const") or line.begins_with("@export") or line.begins_with("var"):
		if line.find("scenes/") != -1:
			_add_violation(file_path, line_number, "DOMAIN_NO_SCENE_IMPORT",
				"Domain models must not import scene files.")
		
		if line.find("systems/") != -1:
			_add_violation(file_path, line_number, "DOMAIN_NO_SYSTEM_IMPORT",
				"Domain models must not import system files.")
	
	# Domain must not use signals (except for internal data events)
	if line.find("EventBus.") != -1:
		_add_violation(file_path, line_number, "DOMAIN_NO_EVENTBUS",
			"Domain models must not use EventBus. Keep them pure data/helpers.")

func _check_scenes_violations(file_path: String, line: String, line_number: int) -> void:
	# Scenes should not directly import domain without going through systems
	if line.find("scripts/domain/") != -1 and not line.find("# allowed") != -1:
		# Allow pure Resource configuration classes that scenes commonly need
		if _is_pure_resource_import(line):
			return  # Allow this import
		
		_add_violation(file_path, line_number, "SCENES_NO_DIRECT_DOMAIN",
			"Scenes should access domain models through systems, not directly.")

func _is_pure_resource_import(line: String) -> bool:
	# List of pure Resource configuration classes that scenes can import
	var allowed_resources := [
		"AnimationConfig",
		"ArenaConfig", 
		"BossSpawnConfig",
		"RadarConfigResource",
		"LogConfigResource",
		"XPCurvesResource",
		"AbilitiesBalance",
		"CombatBalance",
		"MeleeBalance",
		"PlayerBalance",
		"WavesBalance"
	]
	
	for resource_name in allowed_resources:
		if line.find(resource_name) != -1:
			return true
	return false

func _add_violation(file_path: String, line_number: int, violation_type: String, message: String) -> void:
	violations.append({
		"file": file_path,
		"line": line_number,
		"type": violation_type,
		"message": message
	})

func _report_violations() -> void:
	if violations.size() == 0:
		print("✅ No architecture violations found")
		return
	
	print("❌ Architecture Boundary Violations Found:")
	print("========================================")
	
	for violation in violations:
		var location: String = violation.file + ":" + str(violation.line)
		print("[" + violation.type + "] " + location)
		print("  " + violation.message)
		print("")
	
	print("Total violations: " + str(violations.size()))
	print("Fix these violations before committing.")