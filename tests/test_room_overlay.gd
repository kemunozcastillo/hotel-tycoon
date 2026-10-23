extends TestCase
## Pruebas de la parte lógica de RoomOverlay (texto y color); el dibujo se verifica en ventana.


func _room_of(state: GameState, cell: Vector2i) -> Room:
	return state.rooms.get_room_at(cell, 0)


func test_describe_rectangular_room() -> void:
	var state := GameState.new(Vector2i(12, 10))
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(6, 2), Vector2i(4, 3)), 0)
	assert_eq(RoomOverlay.describe(_room_of(state, Vector2i(2, 2))), "2×2")
	assert_eq(RoomOverlay.describe(_room_of(state, Vector2i(7, 3))), "4×3")


func test_describe_incomplete_floor_and_irregular_room() -> void:
	var state := GameState.new(Vector2i(12, 10))
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(RoomOverlay.describe(_room_of(state, Vector2i(3, 3))), "2×2 · falta suelo")
	# Un L: las 3 celdas A, B y C rodeadas de paredes.
	var a := Vector2i(6, 6)
	var b := Vector2i(7, 6)
	var c := Vector2i(6, 7)
	var perimeter: Array[Edge] = [
		Edge.from_side(a, Edge.Side.NORTH), Edge.from_side(b, Edge.Side.NORTH),
		Edge.from_side(b, Edge.Side.EAST), Edge.from_side(b, Edge.Side.SOUTH),
		Edge.from_side(c, Edge.Side.EAST), Edge.from_side(c, Edge.Side.SOUTH),
		Edge.from_side(a, Edge.Side.WEST), Edge.from_side(c, Edge.Side.WEST),
	]
	for edge: Edge in perimeter:
		state.build.place_wall(edge, 0)
	for cell: Vector2i in [a, b, c]:
		state.build.place_floor(cell, 0)
	assert_eq(RoomOverlay.describe(_room_of(state, a)), "3 celdas")


func test_tint_depends_on_floor_completeness() -> void:
	var state := GameState.new(Vector2i(12, 10))
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var room: Room = _room_of(state, Vector2i(2, 2))
	var complete_tint: Color = RoomOverlay.tint_of(room)
	assert_near(complete_tint.a, RoomOverlay.TINT_ALPHA)
	state.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(RoomOverlay.tint_of(_room_of(state, Vector2i(2, 2))), RoomOverlay.INCOMPLETE_TINT)
