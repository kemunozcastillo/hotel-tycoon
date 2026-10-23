extends TestCase
## Pruebas de RoomRegistry: identidad estable de las habitaciones y señales.

const MAP_SIZE := Vector2i(14, 10)

# Habitaciones recibidas por cada señal (se rellenan con _watch).
var _created: Array[Room] = []
var _changed: Array[Room] = []
var _removed: Array[Room] = []


func _watch(state: GameState) -> void:
	_created.clear()
	_changed.clear()
	_removed.clear()
	state.rooms.room_created.connect(func(room: Room) -> void: _created.append(room))
	state.rooms.room_changed.connect(func(room: Room) -> void: _changed.append(room))
	state.rooms.room_removed.connect(func(room: Room) -> void: _removed.append(room))


func test_building_a_room_emits_one_created_signal() -> void:
	var state := GameState.new(MAP_SIZE)
	_watch(state)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(4, 3)), 0)
	assert_eq(_created.size(), 0, "no se recalcula hasta refresh")
	state.rooms.refresh()
	assert_eq(_created.size(), 1, "una sola señal pese a decenas de cambios en el mapa")
	assert_true(_created[0].id > 0)
	assert_eq(_created[0].get_area(), 12)
	state.rooms.refresh()
	assert_eq(_created.size(), 1, "refrescar sin cambios no emite nada")
	assert_eq(_changed.size() + _removed.size(), 0)


func test_queries_refresh_lazily() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var room: Room = state.rooms.get_room_at(Vector2i(3, 3), 0)
	assert_true(room != null)
	assert_eq(state.rooms.get_rooms(0).size(), 1)
	assert_eq(state.rooms.get_room(room.id), room)
	assert_eq(state.rooms.get_room_at(Vector2i(8, 8), 0), null)


func test_game_state_tick_refreshes_rooms() -> void:
	var state := GameState.new(MAP_SIZE)
	_watch(state)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.tick(0.016)
	assert_eq(_created.size(), 1)


func test_growing_a_room_keeps_its_id() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var original_id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	_watch(state)
	# Ampliar a 3x2: se construye el rectángulo mayor y se abre la pared que ahora sobra.
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(3, 2)), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 2), Edge.Side.EAST), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 3), Edge.Side.EAST), 0)
	state.rooms.refresh()
	assert_eq(_created.size() + _removed.size(), 0, "sigue siendo la misma habitación")
	assert_eq(_changed.size(), 1)
	assert_eq(_changed[0].id, original_id)
	assert_eq(_changed[0].get_area(), 6)


func test_splitting_a_room_keeps_id_in_one_part() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(5, 2)), 0)
	var original_id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	_watch(state)
	# Un tabique entre las columnas 4 y 5 la divide en 3x2 y 2x2.
	state.build.place_wall(Edge.from_side(Vector2i(4, 2), Edge.Side.EAST), 0)
	state.build.place_wall(Edge.from_side(Vector2i(4, 3), Edge.Side.EAST), 0)
	state.rooms.refresh()
	assert_eq(_created.size(), 1)
	assert_eq(_changed.size(), 1)
	assert_eq(_removed.size(), 0)
	assert_eq(_changed[0].id, original_id)
	assert_eq(_changed[0].get_area(), 6, "la parte con más celdas conserva la identidad")
	assert_eq(_created[0].get_area(), 4)
	assert_true(_created[0].id != original_id)


func test_merging_rooms_removes_the_smaller_one() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(4, 2), Vector2i(3, 2)), 0)
	var small_id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	var big_id: int = state.rooms.get_room_at(Vector2i(5, 2), 0).id
	_watch(state)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 2), Edge.Side.EAST), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 3), Edge.Side.EAST), 0)
	state.rooms.refresh()
	assert_eq(_removed.size(), 1)
	assert_eq(_removed[0].id, small_id)
	assert_eq(_changed.size(), 1)
	assert_eq(_changed[0].id, big_id)
	assert_eq(_changed[0].get_area(), 10)
	assert_eq(_created.size(), 0)


func test_demolishing_removes_the_room() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	state.build.build_room(rect, 0)
	var id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	_watch(state)
	state.build.demolish_room(rect, 0)
	state.rooms.refresh()
	assert_eq(_removed.size(), 1)
	assert_eq(_removed[0].id, id)
	assert_eq(state.rooms.get_rooms(0).size(), 0)
	assert_eq(state.rooms.get_room(id), null)


func test_adding_a_door_or_removing_floor_reports_a_change() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	_watch(state)
	state.build.place_door(Edge.from_side(Vector2i(2, 2), Edge.Side.NORTH), 0)
	state.rooms.refresh()
	assert_eq(_changed.size(), 1, "una puerta nueva")
	assert_eq(_changed[0].id, room.id)
	assert_eq(_changed[0].doors.size(), 1)
	state.build.remove_floor(Vector2i(3, 3), 0)
	state.rooms.refresh()
	assert_eq(_changed.size(), 2, "perder suelo")
	assert_false(_changed[1].has_complete_floor)


func test_ids_are_never_reused() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	state.build.build_room(rect, 0)
	var first_id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	state.build.demolish_room(rect, 0)
	state.rooms.refresh()
	state.build.build_room(rect, 0)
	var second_id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	assert_true(second_id != first_id, "una habitación nueva no hereda el id de una derribada")


func test_other_rooms_are_untouched_by_a_change() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(1, 1), Vector2i(2, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(8, 1), Vector2i(2, 2)), 0)
	var untouched: Room = state.rooms.get_room_at(Vector2i(8, 1), 0)
	_watch(state)
	state.build.place_door(Edge.from_side(Vector2i(1, 1), Edge.Side.NORTH), 0)
	state.rooms.refresh()
	assert_eq(_changed.size(), 1)
	assert_eq(state.rooms.get_room_at(Vector2i(8, 1), 0), untouched, "la otra habitación conserva su objeto")
