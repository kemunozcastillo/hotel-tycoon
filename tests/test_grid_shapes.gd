extends TestCase
## Pruebas de las formas rectangulares y de los comandos de forma de BuildCommands.

const MAP_SIZE := Vector2i(12, 10)


func test_rect_between_normalizes_corner_order() -> void:
	var a := Vector2i(5, 2)
	var b := Vector2i(2, 4)
	var expected := Rect2i(Vector2i(2, 2), Vector2i(4, 3))
	assert_eq(GridShapes.rect_between(a, b), expected)
	assert_eq(GridShapes.rect_between(b, a), expected, "el orden de las esquinas no importa")
	assert_eq(GridShapes.rect_between(a, a), Rect2i(a, Vector2i.ONE), "una sola celda")


func test_rect_cells_count_and_content() -> void:
	var rect := GridShapes.rect_between(Vector2i(1, 1), Vector2i(3, 2))
	var cells: Array[Vector2i] = GridShapes.rect_cells(rect)
	assert_eq(cells.size(), 6)
	assert_true(cells.has(Vector2i(1, 1)) and cells.has(Vector2i(3, 2)))
	assert_false(cells.has(Vector2i(4, 2)))


func test_rect_perimeter_has_no_duplicates_and_expected_size() -> void:
	for size: Vector2i in [Vector2i(1, 1), Vector2i(2, 2), Vector2i(1, 5), Vector2i(4, 3)]:
		var edges: Array[Edge] = GridShapes.rect_perimeter(Rect2i(Vector2i(3, 3), size))
		assert_eq(edges.size(), 2 * (size.x + size.y), "tamaño %s" % str(size))
		var keys: Dictionary = {}
		for edge: Edge in edges:
			keys["%d,%d,%d" % [edge.cell.x, edge.cell.y, edge.axis]] = true
		assert_eq(keys.size(), edges.size(), "sin aristas repetidas en %s" % str(size))


func test_rect_perimeter_encloses_exactly_its_cells() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(3, 3), Vector2i(3, 2))
	for edge: Edge in GridShapes.rect_perimeter(rect):
		grid.set_wall(edge, 0, true)
	assert_eq(GridTestHelpers.flood_fill(grid, rect.position).size(), 6)


func test_fill_and_clear_rect_floor() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 3))
	assert_eq(state.build.fill_rect_floor(rect, 0), 9)
	assert_eq(state.build.fill_rect_floor(rect, 0), 0, "repetir no cambia nada")
	assert_eq(state.grid.get_floor_type(Vector2i(4, 4), 0), CellTypes.FloorType.BASIC)
	assert_eq(state.grid.get_floor_type(Vector2i(5, 4), 0), CellTypes.FloorType.NONE)
	# Quitar un rectángulo que solapa a medias solo cuenta lo que realmente había.
	assert_eq(state.build.clear_rect_floor(Rect2i(Vector2i(4, 4), Vector2i(3, 3)), 0), 1)
	assert_eq(state.build.clear_rect_floor(rect, 0), 8)


func test_outline_and_clear_walls() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 2))
	assert_eq(state.build.outline_rect_walls(rect, 0), 10)
	assert_eq(GridTestHelpers.count_walls(state.grid), 10)
	assert_eq(state.build.outline_rect_walls(rect, 0), 0)
	# Una pared del perímetro ya puesta no se cuenta otra vez.
	state.build.remove_wall(Edge.from_side(Vector2i(2, 2), Edge.Side.NORTH), 0)
	assert_eq(state.build.outline_rect_walls(rect, 0), 1)
	assert_eq(state.build.clear_outline_walls(rect, 0), 10)
	assert_eq(GridTestHelpers.count_walls(state.grid), 0)


func test_build_room_2x2_is_a_closed_bathroom() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(4, 4), Vector2i(2, 2))
	assert_eq(state.build.build_room(rect, 0), 4 + 8, "4 suelos y 8 paredes")
	assert_eq(GridTestHelpers.count_walls(state.grid), 8)
	assert_eq(GridTestHelpers.flood_fill(state.grid, rect.position).size(), 4)
	assert_eq(state.build.build_room(rect, 0), 0, "repetir no cambia nada")


func test_build_room_keeps_what_already_exists() -> void:
	var state := GameState.new(MAP_SIZE)
	var inner_wall: Edge = Edge.from_side(Vector2i(5, 5), Edge.Side.EAST)
	state.build.place_wall(inner_wall, 0)
	state.build.place_floor(Vector2i(4, 4), 0)
	var changes: int = state.build.build_room(Rect2i(Vector2i(4, 4), Vector2i(3, 3)), 0)
	assert_eq(changes, 8 + 12, "8 suelos nuevos y 12 paredes de perímetro (la pared interior ya estaba)")
	assert_true(state.grid.has_wall(inner_wall, 0), "la pared existente sigue ahí")


func test_demolish_room() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(1, 1), Vector2i(3, 3))
	state.build.build_room(rect, 0)
	assert_eq(state.build.demolish_room(rect, 0), 9 + 12)
	assert_eq(GridTestHelpers.count_walls(state.grid), 0)
	assert_eq(state.grid.get_floor_type(Vector2i(2, 2), 0), CellTypes.FloorType.NONE)


func test_shapes_outside_the_map_are_ignored() -> void:
	var state := GameState.new(Vector2i(4, 4))
	# Un rectángulo que sobresale: solo se construye la parte válida y no hay errores.
	var rect := Rect2i(Vector2i(2, 2), Vector2i(5, 5))
	assert_eq(state.build.fill_rect_floor(rect, 0), 4)
	assert_eq(state.build.fill_rect_floor(rect, 3), 0, "nivel inexistente")
