## MenuContainersDemo - Visual demonstration of all 5 menu container templates
extends Control

## Template references
@onready var demo_container: VBoxContainer = $DemoContainer

var current_demo: int = 0
var demos: Array = []

func _ready() -> void:
	_setup_demos()
	_show_demo(0)

func _setup_demos() -> void:
	# Demo 1: BaseMenuContainer
	var base = preload("res://scenes/ui/components/BaseMenuContainer.tscn").instantiate()
	base.name = "Demo1_Base"
	base.container_size = Vector2(500, 300)
	base.visible = false

	var content = base.get_content_container()
	var label1 = Label.new()
	label1.text = "1. BaseMenuContainer\n\nSimple border + background\nCustom content goes here"
	label1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label1.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	content.add_child(label1)
	demos.append(base)
	add_child(base)

	# Demo 2: TitledMenuContainer
	var titled = preload("res://scenes/ui/components/TitledMenuContainer.tscn").instantiate()
	titled.name = "Demo2_Titled"
	titled.container_size = Vector2(500, 300)
	titled.title_text = "CHARACTER SELECT"
	titled.title_font_size = 28
	titled.visible = false

	var content2 = titled.get_content_container()
	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	var btn1 = Button.new()
	btn1.text = "Knight"
	btn1.custom_minimum_size = Vector2(120, 50)
	var btn2 = Button.new()
	btn2.text = "Ranger"
	btn2.custom_minimum_size = Vector2(120, 50)
	hbox.add_child(btn1)
	hbox.add_child(btn2)
	content2.add_child(hbox)
	demos.append(titled)
	add_child(titled)

	# Demo 3: GridMenuContainer
	var grid = preload("res://scenes/ui/components/GridMenuContainer.tscn").instantiate()
	grid.name = "Demo3_Grid"
	grid.container_size = Vector2(650, 550)
	grid.title_text = "INVENTORY"
	grid.grid_columns = 6
	grid.grid_min_size = Vector2(600, 400)
	grid.visible = false

	var grid_cont = grid.get_grid_container()
	for i in range(18):
		var item = Button.new()
		item.text = "Item\n%d" % (i + 1)
		item.custom_minimum_size = Vector2(80, 80)
		grid_cont.add_child(item)
	demos.append(grid)
	add_child(grid)

	# Demo 4: GridWithDetailsContainer
	var details = preload("res://scenes/ui/components/GridWithDetailsContainer.tscn").instantiate()
	details.name = "Demo4_Details"
	details.container_size = Vector2(650, 650)
	details.title_text = "SHOP"
	details.grid_columns = 8
	details.visible = false

	var grid4 = details.get_grid_container()
	for i in range(12):
		var item = Button.new()
		item.text = str(i + 1)
		item.custom_minimum_size = Vector2(70, 70)
		grid4.add_child(item)

	var left = details.get_details_left_panel()
	var name_lbl = Label.new()
	name_lbl.text = "Item Name"
	name_lbl.add_theme_font_size_override("font_size", 18)
	var desc_lbl = Label.new()
	desc_lbl.text = "This is the item description. It shows details about the selected item."
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(name_lbl)
	left.add_child(desc_lbl)

	var right = details.get_details_right_panel()
	var unlock_btn = Button.new()
	unlock_btn.text = "UNLOCK\n💎 100"
	right.add_child(unlock_btn)
	demos.append(details)
	add_child(details)

	# Demo 5: TabbedGridContainer
	var tabbed = preload("res://scenes/ui/components/TabbedGridContainer.tscn").instantiate()
	tabbed.name = "Demo5_Tabbed"
	tabbed.container_size = Vector2(650, 700)
	tabbed.title_text = "UNLOCKS SHOP"
	tabbed.tab_names = ["ITEMS", "TOMES", "SKILLS"]
	tabbed.grid_columns = 8
	tabbed.visible = false

	# Add items to ITEMS tab
	var items_grid = tabbed.get_tab_grid("ITEMS")
	for i in range(8):
		var item = Button.new()
		item.text = "I%d" % (i + 1)
		item.custom_minimum_size = Vector2(70, 70)
		items_grid.add_child(item)

	# Add items to TOMES tab
	var tomes_grid = tabbed.get_tab_grid("TOMES")
	for i in range(4):
		var tome = Button.new()
		tome.text = "T%d" % (i + 1)
		tome.custom_minimum_size = Vector2(70, 70)
		tomes_grid.add_child(tome)

	# Add items to SKILLS tab
	var skills_grid = tabbed.get_tab_grid("SKILLS")
	for i in range(6):
		var skill = Button.new()
		skill.text = "S%d" % (i + 1)
		skill.custom_minimum_size = Vector2(70, 70)
		skills_grid.add_child(skill)

	# Add shared details panel
	var left5 = tabbed.get_details_left_panel()
	var name5 = Label.new()
	name5.text = "Selected Item"
	name5.add_theme_font_size_override("font_size", 18)
	var desc5 = Label.new()
	desc5.text = "Details panel is shared across all tabs"
	desc5.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left5.add_child(name5)
	left5.add_child(desc5)

	var right5 = tabbed.get_details_right_panel()
	var btn5 = Button.new()
	btn5.text = "UNLOCK"
	right5.add_child(btn5)
	demos.append(tabbed)
	add_child(tabbed)

func _show_demo(index: int) -> void:
	# Hide all
	for demo in demos:
		demo.visible = false

	# Show selected
	if index >= 0 and index < demos.size():
		demos[index].visible = true
		current_demo = index

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_LEFT:
			_show_demo((current_demo - 1 + demos.size()) % demos.size())
		elif event.keycode == KEY_RIGHT:
			_show_demo((current_demo + 1) % demos.size())
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_show_demo(event.keycode - KEY_1)

func _process(_delta: float) -> void:
	# Show help text
	if demos.size() > 0 and demos[current_demo].visible:
		var demo_name = demos[current_demo].name
		print_rich("[color=cyan]Demo %d/%d: %s[/color] | ←→ Navigate | 1-5 Direct" % [current_demo + 1, demos.size(), demo_name])
