extends TestCase
## Pruebas de la asignación de tipos de habitación en RoomRegistry.

const MAP_SIZE := Vector2i(14, 10)


func _bathroom_state() -> GameState:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	return state


func test_assign_and_clear_room_type() -> void:
	var state := _bathroom_state()
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_eq(room.type_id, &"", "empieza sin tipo")
	assert_eq(state.rooms.get_type_of(room), null)
	assert_eq(state.rooms.get_status(room), null, "sin tipo no hay estado")
	var events: Array[Room] = []
	state.rooms.room_type_changed.connect(func(changed_room: Room) -> void: events.append(changed_room))

	assert_true(state.rooms.set_room_type(room.id, &"bathroom"))
	assert_eq(room.type_id, &"bathroom")
	assert_eq(state.rooms.get_type_of(room).display_name, "Baño")
	assert_eq(events.size(), 1)
	assert_eq(events[0].id, room.id)
	assert_false(state.rooms.set_room_type(room.id, &"bathroom"), "mismo tipo: sin cambio")
	assert_eq(events.size(), 1, "y sin señal")

	assert_true(state.rooms.set_room_type(room.id, &""), "una cadena vacía quita el tipo")
	assert_eq(room.type_id, &"")
	assert_eq(events.size(), 2)
	assert_false(state.rooms.set_room_type(room.id, &""), "ya estaba sin tipo")


func test_invalid_assignments_are_rejected() -> void:
	var state := _bathroom_state()
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_false(state.rooms.set_room_type(room.id, &"spa"), "tipo que no existe")
	assert_eq(room.type_id, &"")
	assert_false(state.rooms.set_room_type(999, &"bathroom"), "habitación que no existe")


func test_status_follows_the_room() -> void:
	var state := _bathroom_state()
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	state.rooms.set_room_type(room.id, &"bathroom")
	assert_false(state.rooms.get_status(room).is_operational(), "sin puerta no es operativa")
	state.build.place_door(Edge.from_side(Vector2i(2, 2), Edge.Side.NORTH), 0)
	var updated: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_true(state.rooms.get_status(updated).is_operational(), "con puerta pasa a operativa")
	assert_eq(updated.type_id, &"bathroom", "y conserva el tipo")


func test_type_survives_growth() -> void:
	var state := _bathroom_state()
	var id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	state.rooms.set_room_type(id, &"bathroom")
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(3, 2)), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 2), Edge.Side.EAST), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 3), Edge.Side.EAST), 0)
	var grown: Room = state.rooms.get_room_at(Vector2i(4, 2), 0)
	assert_eq(grown.id, id)
	assert_eq(grown.type_id, &"bathroom", "ampliar no pierde el tipo")


func test_split_keeps_type_on_larger_part_and_new_part_is_untyped() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(5, 2)), 0)
	var id: int = state.rooms.get_room_at(Vector2i(2, 2), 0).id
	state.rooms.set_room_type(id, &"bedroom")
	state.build.place_wall(Edge.from_side(Vector2i(4, 2), Edge.Side.EAST), 0)
	state.build.place_wall(Edge.from_side(Vector2i(4, 3), Edge.Side.EAST), 0)
	var big: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	var small: Room = state.rooms.get_room_at(Vector2i(6, 2), 0)
	assert_eq(big.id, id)
	assert_eq(big.type_id, &"bedroom")
	assert_true(small.id != id)
	assert_eq(small.type_id, &"", "la parte nueva no hereda el tipo")


func test_merge_keeps_the_survivors_type() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.build.build_room(Rect2i(Vector2i(4, 2), Vector2i(3, 2)), 0)
	state.rooms.set_room_type(state.rooms.get_room_at(Vector2i(2, 2), 0).id, &"bathroom")
	state.rooms.set_room_type(state.rooms.get_room_at(Vector2i(5, 2), 0).id, &"bedroom")
	state.build.clear_edge(Edge.from_side(Vector2i(3, 2), Edge.Side.EAST), 0)
	state.build.clear_edge(Edge.from_side(Vector2i(3, 3), Edge.Side.EAST), 0)
	var merged: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_eq(merged.get_area(), 10)
	assert_eq(merged.type_id, &"bedroom", "gana el tipo de la habitación mayor, que conserva el id")


func test_demolishing_drops_the_type_for_good() -> void:
	var state := _bathroom_state()
	state.rooms.set_room_type(state.rooms.get_room_at(Vector2i(2, 2), 0).id, &"bathroom")
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 2))
	state.build.demolish_room(rect, 0)
	state.rooms.refresh()
	state.build.build_room(rect, 0)
	assert_eq(state.rooms.get_room_at(Vector2i(2, 2), 0).type_id, &"", "la habitación reconstruida no recuerda el tipo")


func test_registry_uses_the_catalog_it_was_given() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(
		'{"room_types": [{"id": "almacen", "name": "Almacén", "min_area": 2}]}')
	var state := GameState.new(MAP_SIZE, catalog)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_false(state.rooms.set_room_type(room.id, &"bathroom"), "no está en este catálogo")
	assert_true(state.rooms.set_room_type(room.id, &"almacen"))
	assert_true(state.rooms.get_status(room).is_operational())
