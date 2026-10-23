extends TestCase
## Pruebas de is_walkable, get_walk_cost y el contador de revisión del mapa.

const MAP_SIZE := Vector2i(8, 6)


func test_only_cells_with_floor_are_walkable() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var cell := Vector2i(2, 2)
	assert_false(grid.is_walkable(cell, 0), "sin suelo no se pisa")
	grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC)
	assert_true(grid.is_walkable(cell, 0))
	assert_false(grid.is_walkable(Vector2i(-1, 0), 0), "fuera del mapa")
	assert_false(grid.is_walkable(MAP_SIZE, 0), "fuera del mapa")
	assert_false(grid.is_walkable(cell, 3), "nivel inexistente")


func test_walls_do_not_make_a_cell_unwalkable() -> void:
	# Las paredes viven en las aristas: bloquean pasos entre celdas, no las celdas.
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	assert_true(state.grid.is_walkable(Vector2i(2, 2), 0))


func test_default_walk_cost_is_one() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	assert_near(grid.get_walk_cost(Vector2i(0, 0), 0), 1.0)


func test_revision_increases_only_on_real_changes() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var start: int = grid.revision
	grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	assert_eq(grid.revision, start + 1)
	grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	assert_eq(grid.revision, start + 1, "sin cambio no sube")
	var edge := Edge.new(Vector2i(1, 1), Edge.Axis.X)
	grid.set_wall(edge, 0, true)
	assert_eq(grid.revision, start + 2)
	grid.set_edge_type(edge, 0, CellTypes.EdgeType.DOOR)
	assert_eq(grid.revision, start + 3, "cambiar pared por puerta cuenta")
	grid.set_floor_type(Vector2i(-5, 0), 0, CellTypes.FloorType.BASIC)
	assert_eq(grid.revision, start + 3, "un cambio rechazado no sube")
	grid.add_level(1)
	assert_eq(grid.revision, start + 4)
	grid.add_level(1)
	assert_eq(grid.revision, start + 4)
