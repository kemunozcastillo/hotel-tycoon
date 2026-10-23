extends TestCase
## Pruebas de GridMap2D: niveles, suelo, paredes por arista y bloqueo entre celdas.

const MAP_SIZE := Vector2i(10, 8)


func test_new_map_has_only_level_zero() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	assert_eq(grid.size, MAP_SIZE)
	assert_true(grid.has_level(0))
	assert_false(grid.has_level(1))
	assert_eq(grid.get_levels(), [0] as Array[int])


func test_add_level() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	assert_true(grid.add_level(1))
	assert_true(grid.add_level(-1))
	assert_false(grid.add_level(1), "no se puede duplicar un nivel")
	assert_eq(grid.get_levels(), [-1, 0, 1] as Array[int])


func test_floor_set_and_get() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var cell := Vector2i(2, 3)
	assert_eq(grid.get_floor_type(cell, 0), CellTypes.FloorType.NONE)
	assert_true(grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC))
	assert_eq(grid.get_floor_type(cell, 0), CellTypes.FloorType.BASIC)
	assert_false(grid.set_floor_type(cell, 0, CellTypes.FloorType.BASIC), "sin cambio devuelve false")
	assert_eq(grid.get_floor_type(Vector2i(3, 2), 0), CellTypes.FloorType.NONE, "otra celda intacta")


func test_floor_out_of_bounds_or_missing_level() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	assert_false(grid.set_floor_type(Vector2i(-1, 0), 0, CellTypes.FloorType.BASIC))
	assert_false(grid.set_floor_type(Vector2i(MAP_SIZE.x, 0), 0, CellTypes.FloorType.BASIC))
	assert_false(grid.set_floor_type(Vector2i(0, MAP_SIZE.y), 0, CellTypes.FloorType.BASIC))
	assert_false(grid.set_floor_type(Vector2i(0, 0), 5, CellTypes.FloorType.BASIC), "nivel inexistente")
	assert_eq(grid.get_floor_type(Vector2i(-1, 0), 0), CellTypes.FloorType.NONE)


func test_levels_are_independent() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	grid.add_level(1)
	grid.set_floor_type(Vector2i(1, 1), 1, CellTypes.FloorType.BASIC)
	var edge: Edge = Edge.from_side(Vector2i(1, 1), Edge.Side.NORTH)
	grid.set_wall(edge, 1, true)
	assert_eq(grid.get_floor_type(Vector2i(1, 1), 0), CellTypes.FloorType.NONE)
	assert_false(grid.has_wall(edge, 0))
	assert_true(grid.has_wall(edge, 1))


func test_wall_is_shared_between_neighbor_cells() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var south_of_a: Edge = Edge.from_side(Vector2i(4, 4), Edge.Side.SOUTH)
	assert_true(grid.set_wall(south_of_a, 0, true))
	var north_of_b: Edge = Edge.from_side(Vector2i(4, 5), Edge.Side.NORTH)
	assert_true(grid.has_wall(north_of_b, 0), "se ve igual desde la celda vecina")
	assert_false(grid.set_wall(north_of_b, 0, true), "colocarla otra vez no cambia nada")
	assert_true(grid.set_wall(north_of_b, 0, false))
	assert_false(grid.has_wall(south_of_a, 0))


func test_wall_does_not_touch_other_axis() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	grid.set_wall(Edge.new(Vector2i(2, 2), Edge.Axis.X), 0, true)
	assert_false(grid.has_wall(Edge.new(Vector2i(2, 2), Edge.Axis.Y), 0))


func test_edge_bounds_include_south_and_east_border() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	# Cierre sur el borde sur: arista X con y == alto.
	assert_true(grid.is_edge_valid(Edge.new(Vector2i(0, MAP_SIZE.y), Edge.Axis.X), 0))
	assert_true(grid.is_edge_valid(Edge.new(Vector2i(MAP_SIZE.x - 1, MAP_SIZE.y), Edge.Axis.X), 0))
	# Cierre sobre el borde este: arista Y con x == ancho.
	assert_true(grid.is_edge_valid(Edge.new(Vector2i(MAP_SIZE.x, 0), Edge.Axis.Y), 0))
	# Fuera del perímetro.
	assert_false(grid.is_edge_valid(Edge.new(Vector2i(MAP_SIZE.x, 0), Edge.Axis.X), 0))
	assert_false(grid.is_edge_valid(Edge.new(Vector2i(0, MAP_SIZE.y), Edge.Axis.Y), 0))
	assert_false(grid.is_edge_valid(Edge.new(Vector2i(-1, 0), Edge.Axis.Y), 0))
	assert_false(grid.set_wall(Edge.new(Vector2i(0, MAP_SIZE.y + 1), Edge.Axis.X), 0, true))
	assert_false(grid.is_edge_valid(Edge.new(Vector2i(0, 0), Edge.Axis.X), 3), "nivel inexistente")


func test_signals_are_emitted_only_on_change() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var cell_events: Array[Vector2i] = []
	var edge_events: Array[Edge] = []
	grid.cell_changed.connect(func(cell: Vector2i, _level: int) -> void: cell_events.append(cell))
	grid.edge_changed.connect(func(edge: Edge, _level: int) -> void: edge_events.append(edge))
	grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	grid.set_floor_type(Vector2i(1, 1), 0, CellTypes.FloorType.BASIC)
	var edge: Edge = Edge.new(Vector2i(1, 1), Edge.Axis.Y)
	grid.set_wall(edge, 0, true)
	grid.set_wall(edge, 0, true)
	grid.set_wall(Edge.new(Vector2i(99, 99), Edge.Axis.Y), 0, true)
	assert_eq(cell_events, [Vector2i(1, 1)] as Array[Vector2i])
	assert_eq(edge_events.size(), 1)


func test_is_blocked_between() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var a := Vector2i(3, 3)
	var b := Vector2i(4, 3)
	assert_false(grid.is_blocked_between(a, b, 0))
	grid.set_wall(Edge.between(a, b), 0, true)
	assert_true(grid.is_blocked_between(a, b, 0))
	assert_true(grid.is_blocked_between(b, a, 0), "simétrico")
	assert_true(grid.is_blocked_between(a, Vector2i(5, 3), 0), "no contiguas")
	assert_true(grid.is_blocked_between(Vector2i(0, 0), Vector2i(-1, 0), 0), "fuera del mapa")


# Caso clave del diseño por aristas: un baño de 2x2 se cierra con 8 aristas.
func test_2x2_room_is_enclosed_by_eight_edges() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var origin := Vector2i(3, 3)
	var perimeter: Array[Edge] = [
		Edge.from_side(origin, Edge.Side.NORTH),
		Edge.from_side(origin + Vector2i(1, 0), Edge.Side.NORTH),
		Edge.from_side(origin + Vector2i(1, 0), Edge.Side.EAST),
		Edge.from_side(origin + Vector2i(1, 1), Edge.Side.EAST),
		Edge.from_side(origin + Vector2i(1, 1), Edge.Side.SOUTH),
		Edge.from_side(origin + Vector2i(0, 1), Edge.Side.SOUTH),
		Edge.from_side(origin + Vector2i(0, 1), Edge.Side.WEST),
		Edge.from_side(origin, Edge.Side.WEST),
	]
	for edge: Edge in perimeter:
		grid.set_wall(edge, 0, true)
	assert_eq(GridTestHelpers.count_walls(grid), 8, "ocho paredes en total")
	assert_eq(GridTestHelpers.flood_fill(grid, origin).size(), 4, "la habitación encierra exactamente 4 celdas")

	# Una puerta (quitar una arista) abre la habitación al resto del mapa.
	grid.set_wall(perimeter[0], 0, false)
	assert_true(GridTestHelpers.flood_fill(grid, origin).size() > 4, "con la puerta abierta el relleno escapa")


func test_room_on_map_corner_uses_border_edges() -> void:
	# Habitación de 2x2 en la esquina sur-este: las paredes sur y este caen en el borde.
	var grid := GridMap2D.new(MAP_SIZE)
	var origin := MAP_SIZE - Vector2i(2, 2)
	var perimeter: Array[Edge] = [
		Edge.from_side(origin, Edge.Side.NORTH),
		Edge.from_side(origin + Vector2i(1, 0), Edge.Side.NORTH),
		Edge.from_side(origin, Edge.Side.WEST),
		Edge.from_side(origin + Vector2i(0, 1), Edge.Side.WEST),
		Edge.from_side(origin + Vector2i(0, 1), Edge.Side.SOUTH),
		Edge.from_side(origin + Vector2i(1, 1), Edge.Side.SOUTH),
		Edge.from_side(origin + Vector2i(1, 0), Edge.Side.EAST),
		Edge.from_side(origin + Vector2i(1, 1), Edge.Side.EAST),
	]
	for edge: Edge in perimeter:
		assert_true(grid.set_wall(edge, 0, true), "arista válida en el borde")
	assert_eq(GridTestHelpers.flood_fill(grid, origin).size(), 4)
