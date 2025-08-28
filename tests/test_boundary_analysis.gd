extends SceneTree

# Test runner for the architecture boundary analysis tool
# Can be run headless for automated testing

func _initialize() -> void:
	print("🔍 Running Architecture Boundary Analysis...")
	print("==================================================")
	
	var analyzer := BoundaryAnalyzer.new()
	analyzer._analyze_project()
	analyzer._generate_reports()
	
	print("\n📊 Analysis complete!")
	quit(0)

class BoundaryAnalyzer:
	
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
		var dependencies := _extract_basic_dependencies(content)
		
		dependency_graph[file_path] = {
			"layer": current_layer,
			"dependencies": dependencies
		}

	func _extract_basic_dependencies(content: String) -> Array[String]:
		var deps: Array[String] = []
		var lines := content.split("\n")
		
		for line in lines:
			line = line.strip_edges()
			
			# Check for preload statements
			if line.find("preload(") != -1:
				var start := line.find("preload(\"") + 9
				var end := line.find("\")", start)
				if start > 8 and end > start:
					deps.append(line.substr(start, end - start))
			
			# Check for get_node calls with ../
			elif line.find("get_node(") != -1 and line.find("../") != -1:
				deps.append("SCENE_ACCESS_VIOLATION")
			
			# Check for EventBus usage in domain
			elif line.find("EventBus.") != -1:
				deps.append("EVENTBUS_USAGE")
		
		return deps

	func _generate_reports() -> void:
		_print_layer_summary()
		_print_simple_analysis()

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

	func _print_simple_analysis() -> void:
		print("\n🔍 Dependency Analysis:")
		print("------------------------------")
		
		var violations_found := false
		
		for file_path in dependency_graph:
			var file_data: Dictionary = dependency_graph[file_path]
			var layer: String = file_data.layer
			
			for dep in file_data.dependencies:
				if dep == "SCENE_ACCESS_VIOLATION" and layer == "systems":
					print("⚠️ " + file_path + " - Systems accessing scenes via get_node()")
					violations_found = true
				elif dep == "EVENTBUS_USAGE" and layer == "domain":
					print("⚠️ " + file_path + " - Domain models using EventBus")
					violations_found = true
		
		if not violations_found:
			print("✅ No obvious architectural violations detected")