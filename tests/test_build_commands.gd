extends TestCase
## Pruebas de BuildCommands: colocar y quitar suelo y paredes, con casos inválidos.

const MAP_SIZE := Vector2i(6, 6)


func test_place_and_remove_floor() -> void:
	var state := GameState.new(MAP_SIZE)
	var cell := Vector2i(1, 2)
	assert_true(state.build.place_floor(cell, 0))
	assert_eq(state.grid.get_floor_type(cell, 0), CellTypes.FloorType.BASIC)
	assert_false(state.build.place_floor(cell, 0), "ya construido")
	assert_true(state.build.remove_floor(cell, 0))
	assert_eq(state.grid.get_floor_type(cell, 0), CellTypes.FloorType.NONE)
	assert_false(state.build.remove_floor(cell, 0), "ya vacío")


func test_place_floor_none_removes() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.place_floor(Vector2i(0, 0), 0)
	assert_true(state.build.place_floor(Vector2i(0, 0), 0, CellTypes.FloorType.NONE))
	assert_eq(state.grid.get_floor_type(Vector2i(0, 0), 0), CellTypes.FloorType.NONE)


func test_place_and_remove_wall() -> void:
	var state := GameState.new(MAP_SIZE)
	var edge: Edge = Edge.from_side(Vector2i(2, 2), Edge.Side.EAST)
	assert_true(state.build.place_wall(edge, 0))
	assert_true(state.grid.has_wall(edge, 0))
	assert_false(state.build.place_wall(edge, 0), "ya existe")
	assert_true(state.build.remove_wall(edge, 0))
	assert_false(state.grid.has_wall(edge, 0))
	assert_false(state.build.remove_wall(edge, 0), "ya no existe")


func test_invalid_targets_are_rejected() -> void:
	var state := GameState.new(MAP_SIZE)
	assert_false(state.build.place_floor(Vector2i(-1, 0), 0))
	assert_false(state.build.place_floor(MAP_SIZE, 0))
	assert_false(state.build.place_floor(Vector2i(0, 0), 2), "nivel inexistente")
	assert_false(state.build.place_wall(Edge.new(Vector2i(0, MAP_SIZE.y + 1), Edge.Axis.X), 0))
	assert_false(state.build.place_wall(Edge.new(Vector2i(0, 0), Edge.Axis.X), 2), "nivel inexistente")


func test_commands_notify_through_grid_signals() -> void:
	var state := GameState.new(MAP_SIZE)
	var notifications: Array[String] = []
	state.grid.cell_changed.connect(func(_cell: Vector2i, _level: int) -> void: notifications.append("cell"))
	state.grid.edge_changed.connect(func(_edge: Edge, _level: int) -> void: notifications.append("edge"))
	state.build.place_floor(Vector2i(0, 0), 0)
	state.build.place_wall(Edge.new(Vector2i(0, 0), Edge.Axis.X), 0)
	state.build.place_wall(Edge.new(Vector2i(0, 0), Edge.Axis.X), 0)
	state.build.remove_floor(Vector2i(0, 0), 0)
	assert_eq(notifications, ["cell", "edge", "cell"] as Array[String])
