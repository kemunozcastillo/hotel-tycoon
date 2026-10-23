extends TestCase
## Pruebas de la normalización de aristas y de la selección de la arista más cercana.


func test_opposite_sides_share_one_canonical_edge() -> void:
	var cell := Vector2i(3, 4)
	var south: Edge = Edge.from_side(cell, Edge.Side.SOUTH)
	var north_of_next: Edge = Edge.from_side(cell + Vector2i(0, 1), Edge.Side.NORTH)
	assert_true(south.is_equal(north_of_next), "sur de (3,4) == norte de (3,5)")
	var east: Edge = Edge.from_side(cell, Edge.Side.EAST)
	var west_of_next: Edge = Edge.from_side(cell + Vector2i(1, 0), Edge.Side.WEST)
	assert_true(east.is_equal(west_of_next), "este de (3,4) == oeste de (4,4)")
	assert_false(south.is_equal(east))


func test_between_adjacent_cells() -> void:
	var a := Vector2i(2, 2)
	for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var forward: Edge = Edge.between(a, a + offset)
		var backward: Edge = Edge.between(a + offset, a)
		assert_true(forward != null and forward.is_equal(backward), "simétrica hacia %s" % str(offset))


func test_between_non_adjacent_is_null() -> void:
	assert_eq(Edge.between(Vector2i(0, 0), Vector2i(2, 0)), null)
	assert_eq(Edge.between(Vector2i(0, 0), Vector2i(1, 1)), null)
	assert_eq(Edge.between(Vector2i(0, 0), Vector2i(0, 0)), null)


func test_cells_separated_by_edge() -> void:
	var edge: Edge = Edge.between(Vector2i(5, 5), Vector2i(6, 5))
	var cells: Array[Vector2i] = edge.cells()
	assert_eq(cells.size(), 2)
	assert_true(cells.has(Vector2i(5, 5)) and cells.has(Vector2i(6, 5)))


func test_nearest_picks_closest_side() -> void:
	assert_true(Edge.nearest(Vector2(0.5, 0.1)).is_equal(Edge.from_side(Vector2i(0, 0), Edge.Side.NORTH)))
	assert_true(Edge.nearest(Vector2(0.5, 0.9)).is_equal(Edge.from_side(Vector2i(0, 0), Edge.Side.SOUTH)))
	assert_true(Edge.nearest(Vector2(0.1, 0.5)).is_equal(Edge.from_side(Vector2i(0, 0), Edge.Side.WEST)))
	assert_true(Edge.nearest(Vector2(0.9, 0.5)).is_equal(Edge.from_side(Vector2i(0, 0), Edge.Side.EAST)))


func test_nearest_with_offset_and_negative_coordinates() -> void:
	assert_true(Edge.nearest(Vector2(7.5, 3.95)).is_equal(Edge.from_side(Vector2i(7, 3), Edge.Side.SOUTH)))
	# Una celda negativa: floor(-0.5) = -1, no 0.
	var edge: Edge = Edge.nearest(Vector2(-0.5, 0.2))
	assert_eq(edge.cell, Vector2i(-1, 0))
	assert_eq(edge.axis, Edge.Axis.X)
