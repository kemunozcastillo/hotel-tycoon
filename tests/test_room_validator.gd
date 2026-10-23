extends TestCase
## Pruebas del validador de requisitos de tipos de habitación.

const MAP_SIZE := Vector2i(16, 12)

var _catalog: RoomTypeCatalog = RoomTypeCatalog.load_default()


## Construye una habitación del tamaño dado en (2,2), con una puerta si `with_door`.
func _room(size: Vector2i, with_door: bool = true) -> Room:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), size)
	state.build.build_room(rect, 0)
	if with_door:
		state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	return RoomDetector.detect(state.grid, 0)[0]


func _kinds_failed(status: RoomStatus) -> Array[int]:
	var kinds: Array[int] = []
	for check: RoomCheck in status.get_failed():
		kinds.append(check.kind)
	return kinds


func test_2x2_bathroom_with_door_is_operational() -> void:
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(2, 2)), _catalog.get_type(&"bathroom"))
	assert_true(status.is_operational())
	assert_eq(status.get_failed().size(), 0)
	assert_eq(status.get_first_failed(), null)


func test_checks_are_listed_in_fixed_order_with_values() -> void:
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(2, 2)), _catalog.get_type(&"bathroom"))
	var kinds: Array[int] = []
	for check: RoomCheck in status.checks:
		kinds.append(check.kind)
	assert_eq(kinds, [
		RoomCheck.Kind.MIN_AREA, RoomCheck.Kind.MAX_AREA, RoomCheck.Kind.MIN_SHORT_SIDE,
		RoomCheck.Kind.MIN_DOORS, RoomCheck.Kind.COMPLETE_FLOOR,
	] as Array[int])
	assert_eq(status.checks[0].actual, 4)
	assert_eq(status.checks[0].required, 4)
	assert_eq(status.checks[3].actual, 1)
	assert_eq(status.checks[3].required, 1)


func test_bathroom_without_door_fails_doors() -> void:
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(2, 2), false), _catalog.get_type(&"bathroom"))
	assert_false(status.is_operational())
	assert_eq(_kinds_failed(status), [RoomCheck.Kind.MIN_DOORS] as Array[int])
	assert_eq(status.get_first_failed().actual, 0)


func test_too_small_and_too_large_boundaries() -> void:
	var bathroom: RoomType = _catalog.get_type(&"bathroom")
	assert_true(RoomValidator.evaluate(_room(Vector2i(3, 3)), bathroom).is_operational(), "9 celdas = máximo exacto")
	var large: RoomStatus = RoomValidator.evaluate(_room(Vector2i(2, 5)), bathroom)
	assert_eq(_kinds_failed(large), [RoomCheck.Kind.MAX_AREA] as Array[int], "10 celdas supera el máximo")
	var bedroom: RoomType = _catalog.get_type(&"bedroom")
	assert_true(RoomValidator.evaluate(_room(Vector2i(2, 3)), bedroom).is_operational(), "6 celdas = mínimo exacto")
	var small: RoomStatus = RoomValidator.evaluate(_room(Vector2i(2, 2)), bedroom)
	assert_eq(_kinds_failed(small), [RoomCheck.Kind.MIN_AREA] as Array[int])
	assert_eq(small.get_first_failed().actual, 4)
	assert_eq(small.get_first_failed().required, 6)


func test_narrow_room_fails_short_side_even_with_enough_area() -> void:
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(1, 6)), _catalog.get_type(&"bedroom"))
	assert_eq(_kinds_failed(status), [RoomCheck.Kind.MIN_SHORT_SIDE] as Array[int])
	assert_eq(status.get_first_failed().actual, 1)


func test_missing_floor_reports_how_many_cells() -> void:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 2))
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	state.build.remove_floor(Vector2i(2, 2), 0)
	state.build.remove_floor(Vector2i(4, 3), 0)
	var room: Room = RoomDetector.detect(state.grid, 0)[0]
	var status: RoomStatus = RoomValidator.evaluate(room, _catalog.get_type(&"bedroom"))
	assert_eq(_kinds_failed(status), [RoomCheck.Kind.COMPLETE_FLOOR] as Array[int])
	assert_eq(status.get_first_failed().actual, 2)
	assert_eq(room.missing_floor_cells, 2)
	assert_false(room.has_complete_floor)


func test_several_failures_are_all_reported_first_failed_follows_order() -> void:
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(1, 2), false), _catalog.get_type(&"bedroom"))
	assert_eq(_kinds_failed(status), [
		RoomCheck.Kind.MIN_AREA, RoomCheck.Kind.MIN_SHORT_SIDE, RoomCheck.Kind.MIN_DOORS,
	] as Array[int])
	assert_eq(status.get_first_failed().kind, RoomCheck.Kind.MIN_AREA)


func test_requirements_left_undefined_are_not_checked() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(
		'{"room_types": [{"id": "libre", "name": "Libre", "min_area": 1, "requires_complete_floor": false}]}')
	var status: RoomStatus = RoomValidator.evaluate(_room(Vector2i(1, 1), false), catalog.get_type(&"libre"))
	assert_eq(status.checks.size(), 1, "solo el área mínima")
	assert_true(status.is_operational())
	assert_true(RoomValidator.evaluate(_room(Vector2i(8, 8), false), catalog.get_type(&"libre")).is_operational(), "sin máximo")


func test_room_short_side_and_same_as_include_floor() -> void:
	var room: Room = _room(Vector2i(3, 2))
	assert_eq(room.get_short_side(), 2)
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), Vector2i(3, 2))
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	var same: Room = RoomDetector.detect(state.grid, 0)[0]
	assert_true(room.is_same_as(same))
	state.build.remove_floor(Vector2i(3, 3), 0)
	assert_false(room.is_same_as(RoomDetector.detect(state.grid, 0)[0]), "perder suelo cuenta como cambio")
