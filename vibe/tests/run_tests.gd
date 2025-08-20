extends Node

## Test runner for RNG streams and balance simulations.
## Can be instantiated and called from other scripts.

const BalanceSimsTest = preload("res://tests/balance_sims.gd")
const TestSignalContracts = preload("res://tests/test_signal_contracts.gd")

func _ready() -> void:
	print("Starting tests...")
	
	# Load and run RNG stream test
	TestRngStreams.run_test()
	
	# Run signal contracts test
	TestSignalContracts.run_test()
	
	print("\nRunning balance simulation (1,000 trials for headless)...")
	BalanceSimsTest.run_baseline_simulation(1000, 42)
	
	print("\nAll tests completed.")
	
	# Exit in headless mode
	if DisplayServer.get_name() == "headless":
		get_tree().quit()

# Static function to run from command line or other scripts
static func run_from_command_line() -> void:
	print("Starting tests from command line...")
	
	# Load and run RNG stream test
	TestRngStreams.run_test()
	
	# Run signal contracts test
	TestSignalContracts.run_test()
	
	print("\nRunning balance simulation (10,000 trials)...")
	BalanceSimsTest.run_baseline_simulation(10000, 42)
	
	print("\nAll tests completed.")

# Main function for direct script execution
func _main() -> void:
	run_from_command_line()
