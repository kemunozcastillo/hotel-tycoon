extends TestCase
## Pruebas de la detección de habitaciones (RoomDetector).

const MAP_SIZE := Vector2i(12, 10)


func test_empty_map_has_no_rooms() -> void:
	var grid := GridMap2D.new(MAP_SIZE)
	assert_eq(RoomDetector.detect(grid, 0).size(), 0)
	assert_eq(RoomDetector.detect(grid, 7).size(), 0, "nivel inexistente")


func test_2x2_bathroom_is_one_room() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(3, 3), Vector2i(2, 2)), 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1)
	var room: Room = rooms[0]
	assert_eq(room.get_area(), 4)
	assert_eq(room.get_bounds(), Rect2i(Vector2i(3, 3), Vector2i(2, 2)))
	assert_true(room.is_rectangular())
	assert_true(room.has_complete_floor)
	assert_eq(room.doors.size(), 0)
	assert_true(room.contains(Vector2i(4, 4)))
	assert_false(room.contains(Vector2i(5, 4)))


func test_room_without_floor_is_flagged() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 2))
	state.build.outline_rect_walls(rect, 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1, "una región cerrada es habitación aunque no tenga suelo")
	assert_false(rooms[0].has_complete_floor)
	state.build.fill_rect_floor(rect, 0)
	assert_true(RoomDetector.detect(state.grid, 0)[0].has_complete_floor)
	state.build.remove_floor(Vector2i(3, 3), 0)
	assert_false(RoomDetector.detect(state.grid, 0)[0].has_complete_floor, "un solo hueco basta")


func test_missing_wall_means_no_room() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(3, 3), Vector2i(2, 2))
	state.build.build_room(rect, 0)
	state.build.remove_wall(Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH), 0)
	assert_eq(RoomDetector.detect(state.grid, 0).size(), 0, "con un hueco la región escapa al exterior")


func test_door_keeps_the_room_closed_and_is_listed() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(3, 3), Vector2i(2, 2)), 0)
	var door: Edge = Edge.from_side(Vector2i(3, 3), Edge.Side.NORTH)
	state.build.place_door(door, 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0].get_area(), 4, "la puerta no fusiona la habitación con el exterior")
	assert_eq(rooms[0].doors.size(), 1)
	assert_true(rooms[0].doors[0].is_equal(door))


func test_two_rooms_sharing_a_wall() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(1, 1), Vector2i(2, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(3, 1), Vector2i(3, 2)), 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 2)
	assert_eq(rooms[0].get_area() + rooms[1].get_area(), 10)
	# Una puerta en la pared compartida la comparten las dos habitaciones, que siguen separadas.
	var shared: Edge = Edge.from_side(Vector2i(2, 1), Edge.Side.EAST)
	state.build.place_door(shared, 0)
	rooms = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 2, "la puerta no fusiona las habitaciones")
	assert_eq(rooms[0].doors.size(), 1)
	assert_eq(rooms[1].doors.size(), 1)


func test_room_against_map_border() -> void:
	var state := GameState.new(MAP_SIZE)
	var corner := Rect2i(MAP_SIZE - Vector2i(2, 2), Vector2i(2, 2))
	state.build.build_room(corner, 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0].get_area(), 4)


func test_whole_map_enclosed_is_a_single_room() -> void:
	var state := GameState.new(Vector2i(4, 3))
	state.build.outline_rect_walls(Rect2i(Vector2i.ZERO, Vector2i(4, 3)), 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0].get_area(), 12)


func test_l_shaped_room_is_not_rectangular() -> void:
	var state := GameState.new(MAP_SIZE)
	var a := Vector2i(2, 2)
	var b := Vector2i(3, 2)
	var c := Vector2i(2, 3)
	var perimeter: Array[Edge] = [
		Edge.from_side(a, Edge.Side.NORTH), Edge.from_side(b, Edge.Side.NORTH),
		Edge.from_side(b, Edge.Side.EAST), Edge.from_side(b, Edge.Side.SOUTH),
		Edge.from_side(c, Edge.Side.EAST), Edge.from_side(c, Edge.Side.SOUTH),
		Edge.from_side(a, Edge.Side.WEST), Edge.from_side(c, Edge.Side.WEST),
	]
	for edge: Edge in perimeter:
		state.build.place_wall(edge, 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 1)
	assert_eq(rooms[0].get_area(), 3)
	assert_false(rooms[0].is_rectangular())
	assert_eq(rooms[0].get_bounds().size, Vector2i(2, 2))


func test_nested_room_is_separate_from_the_outer_one() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(1, 1), Vector2i(5, 5)), 0)
	state.build.build_room(Rect2i(Vector2i(3, 3), Vector2i(1, 1)), 0)
	var rooms: Array[Room] = RoomDetector.detect(state.grid, 0)
	assert_eq(rooms.size(), 2)
	var areas: Array[int] = [rooms[0].get_area(), rooms[1].get_area()]
	areas.sort()
	assert_eq(areas, [1, 24] as Array[int], "la exterior no incluye la celda interior")


func test_levels_are_detected_independently() -> void:
	var state := GameState.new(MAP_SIZE)
	state.grid.add_level(1)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 1)
	assert_eq(RoomDetector.detect(state.grid, 0).size(), 0)
	assert_eq(RoomDetector.detect(state.grid, 1).size(), 1)
	assert_eq(RoomDetector.detect(state.grid, 1)[0].level, 1)
