extends Node

func _ready() -> void:
	# Wait a frame for LimboConsole to be ready
	await get_tree().process_frame
	
	# Register a test command
	if LimboConsole:
		LimboConsole.register_command(test_hello, "hello", "Test command that says hello")
		LimboConsole.register_command(get_player_pos, "player_pos", "Get current player position")
		LimboConsole.register_command(set_wave_spawn_rate, "wave_rate", "Set wave spawn rate (float)")
		Logger.info("Console commands registered", "console")
	else:
		Logger.error("LimboConsole not available", "console")

func test_hello(name: String = "World") -> void:
	LimboConsole.info("Hello " + name + "!")

func get_player_pos() -> void:
	if PlayerState and PlayerState.position != Vector2.ZERO:
		LimboConsole.info("Player position: " + str(PlayerState.position))
	else:
		LimboConsole.warning("Player position not available")

func set_wave_spawn_rate(rate: float) -> void:
	if BalanceDB and BalanceDB.waves_balance:
		BalanceDB.waves_balance.spawn_rate = rate
		LimboConsole.info("Wave spawn rate set to: " + str(rate))
		Logger.info("Console adjusted wave spawn rate to: " + str(rate), "balance")
	else:
		LimboConsole.error("Balance system not available")
