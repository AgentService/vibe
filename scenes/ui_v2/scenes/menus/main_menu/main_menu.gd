extends MainMenu

# Custom implementation for Vibe game
# Connects Maaack's menu system to our game flow:
# MainMenu -> CharacterSelect -> MapSelect -> Arena
#
# NOTE: Set game_scene_path in Inspector to "res://scenes/ui/CharacterSelect.tscn"
# to make the New Game button visible. The base class auto-hides it if path is empty.

func new_game() -> void:
	# Override base behavior to go to character select instead
	# The base class would normally load game_scene_path directly,
	# but we override to use SceneLoader for async loading with progress bar
	SceneLoader.load_scene("res://scenes/ui/CharacterSelect.tscn")
