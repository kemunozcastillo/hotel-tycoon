extends SceneTree
## Ejecuta todas las suites de tests/ sin ventana:
##   godot --headless --path . --script res://tests/run_tests.gd
## Termina con código 1 si algún test falla.

const SUITES: Array[String] = [
	"res://tests/test_edge.gd",
	"res://tests/test_grid_map.gd",
	"res://tests/test_build_commands.gd",
	"res://tests/test_grid_shapes.gd",
	"res://tests/test_doors.gd",
	"res://tests/test_min_heap.gd",
	"res://tests/test_grid_walkability.gd",
	"res://tests/test_pathfinder.gd",
	"res://tests/test_agent_movement.gd",
	"res://tests/test_room_type_catalog.gd",
	"res://tests/test_room_validator.gd",
	"res://tests/test_room_detector.gd",
	"res://tests/test_room_registry.gd",
	"res://tests/test_room_types_assignment.gd",
	"res://tests/test_room_overlay.gd",
	"res://tests/test_room_texts.gd",
	"res://tests/test_iso_projection.gd",
	"res://tests/test_iso_camera.gd",
	"res://tests/test_game_clock.gd",
]


func _init() -> void:
	var total_checks: int = 0
	var total_failures: int = 0
	var total_tests: int = 0
	for path: String in SUITES:
		var script: GDScript = load(path) as GDScript
		var suite: TestCase = script.new() as TestCase
		print("== %s" % path.get_file())
		for method: Dictionary in suite.get_method_list():
			var method_name: String = method["name"]
			if not method_name.begins_with("test_"):
				continue
			suite.current_test = method_name
			suite.call(method_name)
			total_tests += 1
		total_checks += suite.checks
		total_failures += suite.failures
	print("")
	print("%d tests, %d comprobaciones, %d fallos" % [total_tests, total_checks, total_failures])
	quit(1 if total_failures > 0 else 0)
