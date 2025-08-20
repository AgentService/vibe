extends SceneTree

# Standalone Architecture Boundary Analysis Tool
# Can be run headless or from editor

func _initialize() -> void:
	print("🔍 Architecture Boundary Analysis Starting...")
	print("==================================================")
	
	var analyzer := ArchitectureBoundaryAnalyzer.new()
	analyzer.run_analysis()
	
	print("\n📊 Analysis complete!")
	quit(0)

class ArchitectureBoundaryAnalyzer:
	
	const LAYER_DEFINITIONS := {
		"autoload": {
			"path_pattern": "autoload/",
			"can_import": ["domain"],
			"can_call": ["domain", "autoload"],
			"description": "Global singletons for coordination"
		},
		"systems": {
			"path_pattern": "scripts/systems/",
			"can_import": ["domain", "autoload"],
			"can_call": ["domain", "autoload", "systems"],
			"description": "Game logic and rules"
		},
		"scenes": {
			"path_pattern": "scenes/",
			"can_import": ["systems", "autoload"],
			"can_call": ["systems", "autoload"],
			"description": "UI and visual representation"
		},
		"domain": {
			"path_pattern": "scripts/domain/",
			"can_import": [],
			"can_call": ["domain"],
			"description": "Pure data models and helpers"
		}
	}

	var dependency_graph: Dictionary = {}
	var violations: Array[Dictionary] = []
	var file_layers: Dictionary = {}

	func run_analysis() -> void:
		_analyze_project()
		_generate_reports()
		
		if violations.size() > 0:
			print("\n❌ Analysis complete with " + str(violations.size()) + " violations")
		else:
			print("\n✅ Analysis complete - no violations found")

	func _analyze_project() -> void:
		var project_files := _discover_project_files()
		
		# First pass: categorize files by layer
		for file_path in project_files:
			var layer := _determine_file_layer(file_path)
			if layer != "":
				file_layers[file_path] = layer
		
		# Second pass: analyze dependencies
		for file_path in file_layers:
			_analyze_file_dependencies(file_path)

	func _discover_project_files() -> Array[String]:
		var files: Array[String] = []
		_scan_directory(".", files)
		return files

	func _scan_directory(dir_path: String, files: Array[String]) -> void:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			return
		
		dir.list_dir_begin()
		var file_name := dir.get_next()
		
		while file_name != "":
			if file_name.begins_with("."):
				file_name = dir.get_next()
				continue
			
			var full_path := dir_path + "/" + file_name
			
			if dir.current_is_dir():
				_scan_directory(full_path, files)
			elif file_name.ends_with(".gd"):
				files.append(full_path)
			
			file_name = dir.get_next()

	func _determine_file_layer(file_path: String) -> String:
		for layer_name in LAYER_DEFINITIONS:
			var pattern: String = LAYER_DEFINITIONS[layer_name].path_pattern
			if file_path.find(pattern) != -1:
				return layer_name
		return ""

	func _analyze_file_dependencies(file_path: String) -> void:
		var file := FileAccess.open(file_path, FileAccess.READ)
		if file == null:
			return
		
		var content := file.get_as_text()
		file.close()
		
		var current_layer: String = file_layers[file_path]
		var dependencies := _extract_dependencies(content)
		
		dependency_graph[file_path] = {
			"layer": current_layer,
			"dependencies": dependencies
		}
		
		_validate_dependencies(file_path, current_layer, dependencies, content)

	func _extract_dependencies(content: String) -> Array[Dictionary]:
		var deps: Array[Dictionary] = []
		var lines := content.split("\n")
		
		for i in range(lines.size()):
			var line := lines[i].strip_edges()
			var line_number := i + 1
			
			# Check for various dependency patterns
			if line.begins_with("extends ") or line.begins_with("class_name"):
				var dependency := _extract_class_dependency(line)
				if dependency != "":
					deps.append({"type": "inheritance", "target": dependency, "line": line_number})
			
			elif line.begins_with("const") and line.find("preload(") != -1:
				var dependency := _extract_preload_dependency(line)
				if dependency != "":
					deps.append({"type": "preload", "target": dependency, "line": line_number})
			
			elif line.begins_with("@onready") or line.find("load(") != -1:
				var dependency := _extract_load_dependency(line)
				if dependency != "":
					deps.append({"type": "runtime_load", "target": dependency, "line": line_number})
			
			elif line.find("get_node(") != -1:
				var node_path := _extract_node_path(line)
				if node_path != "":
					deps.append({"type": "node_access", "target": node_path, "line": line_number})
		
		return deps

	func _extract_class_dependency(line: String) -> String:
		var parts := line.split(" ")
		if parts.size() >= 2:
			return parts[1].strip_edges()
		return ""

	func _extract_preload_dependency(line: String) -> String:
		var start := line.find("preload(\"") + 9
		var end := line.find("\")", start)
		if start > 8 and end > start:
			return line.substr(start, end - start)
		return ""

	func _extract_load_dependency(line: String) -> String:
		var start := line.find("load(\"") + 6
		var end := line.find("\")", start)
		if start > 5 and end > start:
			return line.substr(start, end - start)
		return ""

	func _extract_node_path(line: String) -> String:
		var start := line.find("get_node(\"") + 10
		var end := line.find("\")", start)
		if start > 9 and end > start:
			return line.substr(start, end - start)
		return ""

	func _validate_dependencies(file_path: String, current_layer: String, dependencies: Array[Dictionary], content: String) -> void:
		var allowed_layers: Array = LAYER_DEFINITIONS[current_layer].can_import
		
		for dep in dependencies:
			var target_layer: String = _determine_dependency_layer(dep.target)
			
			if target_layer == "":
				continue  # External dependency or built-in
			
			# Check if this layer can import from target layer
			if target_layer not in allowed_layers and target_layer != current_layer:
				_add_violation(file_path, dep.line, "FORBIDDEN_LAYER_IMPORT", 
					"Layer '" + current_layer + "' cannot import from '" + target_layer + "'. " +
					"Allowed imports: " + str(allowed_layers))
			
			# Check for specific anti-patterns
			_check_antipatterns(file_path, current_layer, dep, content)

	func _determine_dependency_layer(target: String) -> String:
		# Determine which layer a dependency belongs to
		for layer_name in LAYER_DEFINITIONS:
			var pattern: String = LAYER_DEFINITIONS[layer_name].path_pattern
			if target.find(pattern) != -1:
				return layer_name
		
		# Check against known files
		for file_path in file_layers:
			if target in file_path:
				return file_layers[file_path]
		
		return ""  # External or built-in

	func _check_antipatterns(file_path: String, layer: String, dep: Dictionary, content: String) -> void:
		match layer:
			"systems":
				if dep.type == "node_access" and dep.target.find("../") != -1:
					_add_violation(file_path, dep.line, "SYSTEMS_SCENE_COUPLING",
						"Systems should not access parent scenes via get_node(). Use signals or dependency injection.")
			
			"domain":
				if dep.target.find("EventBus") != -1:
					_add_violation(file_path, dep.line, "DOMAIN_SIGNAL_COUPLING",
						"Domain models should be pure data. Use systems for EventBus interactions.")
			
			"scenes":
				if dep.type == "preload" and dep.target.find("scripts/domain/") != -1:
					_add_violation(file_path, dep.line, "SCENES_DOMAIN_BYPASS",
						"Scenes should access domain models through systems, not directly.")

	func _add_violation(file_path: String, line_number: int, violation_type: String, message: String) -> void:
		violations.append({
			"file": file_path,
			"line": line_number,
			"type": violation_type,
			"message": message
		})

	func _generate_reports() -> void:
		_print_layer_summary()
		_print_dependency_matrix()
		_print_violations()

	func _print_layer_summary() -> void:
		print("\n📊 Layer Summary:")
		print("------------------------------")
		
		var layer_counts := {}
		for layer in LAYER_DEFINITIONS:
			layer_counts[layer] = 0
		
		for file_path in file_layers:
			var layer: String = file_layers[file_path]
			layer_counts[layer] += 1
		
		for layer in LAYER_DEFINITIONS:
			var definition: Dictionary = LAYER_DEFINITIONS[layer]
			print(layer.capitalize() + ": " + str(layer_counts[layer]) + " files (" + definition.description + ")")

	func _print_dependency_matrix() -> void:
		print("\n📈 Dependency Matrix:")
		print("------------------------------")
		
		var matrix := {}
		for from_layer in LAYER_DEFINITIONS:
			matrix[from_layer] = {}
			for to_layer in LAYER_DEFINITIONS:
				matrix[from_layer][to_layer] = 0
		
		for file_path in dependency_graph:
			var file_data: Dictionary = dependency_graph[file_path]
			var from_layer: String = file_data.layer
			
			for dep in file_data.dependencies:
				var to_layer: String = _determine_dependency_layer(dep.target)
				if to_layer in matrix[from_layer]:
					matrix[from_layer][to_layer] += 1
		
		# Print matrix
		var header: String = "From\\To\t"
		for layer in LAYER_DEFINITIONS:
			header += layer.substr(0, 6) + "\t"
		print(header)
		
		for from_layer in LAYER_DEFINITIONS:
			var row: String = from_layer.substr(0, 6) + "\t"
			for to_layer in LAYER_DEFINITIONS:
				row += str(matrix[from_layer][to_layer]) + "\t"
			print(row)

	func _print_violations() -> void:
		if violations.size() == 0:
			print("\n✅ No architecture violations found!")
			return
		
		print("\n❌ Architecture Violations:")
		print("----------------------------------------")
		
		for violation in violations:
			print("[" + violation.type + "] " + violation.file + ":" + str(violation.line))
			print("  " + violation.message)
			print("")
