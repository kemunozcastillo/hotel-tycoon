extends TestCase
## Pruebas de los textos y colores de las habitaciones (sin dibujar nada).

const MAP_SIZE := Vector2i(14, 10)


func _typed_room(size: Vector2i, type_id: StringName, with_door: bool = true) -> Array:
	var state := GameState.new(MAP_SIZE)
	var rect := Rect2i(Vector2i(2, 2), size)
	state.build.build_room(rect, 0)
	if with_door:
		state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	var room: Room = state.rooms.get_room_at(rect.position, 0)
	state.rooms.set_room_type(room.id, type_id)
	return [state, room]


func test_label_lines_for_untyped_room() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(3, 2)), 0)
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_eq(RoomTexts.label_lines(room, null, null), ["3×2"] as Array[String])
	state.build.remove_floor(Vector2i(2, 2), 0)
	var updated: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	assert_eq(RoomTexts.label_lines(updated, null, null), ["3×2 · falta suelo"] as Array[String])
	assert_eq(RoomOverlay.describe(updated), "3×2 · falta suelo")


func test_label_lines_for_operational_typed_room_has_one_line() -> void:
	var data: Array = _typed_room(Vector2i(2, 2), &"bathroom")
	var state: GameState = data[0]
	var room: Room = data[1]
	var lines: Array[String] = RoomTexts.label_lines(room, state.rooms.get_type_of(room), state.rooms.get_status(room))
	assert_eq(lines, ["Baño 2×2"] as Array[String])


func test_label_lines_for_typed_room_with_problem_adds_a_line() -> void:
	var data: Array = _typed_room(Vector2i(2, 2), &"bathroom", false)
	var state: GameState = data[0]
	var room: Room = data[1]
	var lines: Array[String] = RoomTexts.label_lines(room, state.rooms.get_type_of(room), state.rooms.get_status(room))
	assert_eq(lines, ["Baño 2×2", "Falta puerta"] as Array[String])


func test_problem_texts_for_each_kind() -> void:
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.MIN_AREA, false, 4, 6)), "Muy pequeña (4 de 6 celdas)")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.MAX_AREA, false, 12, 9)), "Demasiado grande (12 de 9 celdas)")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.MIN_SHORT_SIDE, false, 1, 2)), "Demasiado estrecha (lado 1, mín. 2)")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.MIN_DOORS, false, 0, 1)), "Falta puerta")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.MIN_DOORS, false, 1, 3)), "Faltan puertas (1 de 3)")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.COMPLETE_FLOOR, false, 1, 0)), "Falta suelo (1 celda)")
	assert_eq(RoomTexts.problem_text(RoomCheck.new(RoomCheck.Kind.COMPLETE_FLOOR, false, 3, 0)), "Falta suelo (3 celdas)")


func test_panel_for_untyped_room_invites_to_pick_a_type() -> void:
	var state := GameState.new(MAP_SIZE)
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	var room: Room = state.rooms.get_room_at(Vector2i(2, 2), 0)
	var text: String = RoomTexts.panel_bbcode(room, null, null)
	assert_true(text.contains("Sin tipo"))
	assert_true(text.contains("2×2 (4 celdas)"))
	assert_true(text.contains("Elige un tipo"))


func test_panel_lists_every_requirement_with_its_result() -> void:
	var data: Array = _typed_room(Vector2i(2, 2), &"bathroom", false)
	var state: GameState = data[0]
	var room: Room = data[1]
	var text: String = RoomTexts.panel_bbcode(room, state.rooms.get_type_of(room), state.rooms.get_status(room))
	assert_true(text.contains("Baño"))
	assert_true(text.contains("Área mínima: 4 celdas (tiene 4)"))
	assert_true(text.contains("Área máxima: 9 celdas (tiene 4)"))
	assert_true(text.contains("Lado corto mínimo: 2 (tiene 2)"))
	assert_true(text.contains("Puertas: mínimo 1 (tiene 0)"))
	assert_true(text.contains("Suelo completo"))
	assert_true(text.contains("No operativa"))
	assert_eq(text.count("[color=%s]OK[/color]" % RoomTexts.OK_COLOR), 4)
	assert_eq(text.count("[color=%s]NO[/color]" % RoomTexts.FAIL_COLOR), 1, "solo falla la puerta")


func test_panel_for_operational_room() -> void:
	var data: Array = _typed_room(Vector2i(2, 3), &"bedroom")
	var state: GameState = data[0]
	var room: Room = data[1]
	var text: String = RoomTexts.panel_bbcode(room, state.rooms.get_type_of(room), state.rooms.get_status(room))
	assert_true(text.contains("Operativa"))
	assert_false(text.contains("No operativa"))
	assert_eq(text.count("[color=%s]NO[/color]" % RoomTexts.FAIL_COLOR), 0)


func test_tint_uses_type_color_when_operational_and_warning_when_not() -> void:
	var good: Array = _typed_room(Vector2i(2, 2), &"bathroom")
	var good_state: GameState = good[0]
	var good_room: Room = good[1]
	var tint: Color = RoomOverlay.tint_of(good_room, good_state.rooms.get_type_of(good_room), good_state.rooms.get_status(good_room))
	var type_color: Color = good_state.rooms.get_type_of(good_room).color
	assert_eq(tint, Color(type_color, RoomOverlay.TINT_ALPHA))

	var bad: Array = _typed_room(Vector2i(2, 2), &"bathroom", false)
	var bad_state: GameState = bad[0]
	var bad_room: Room = bad[1]
	assert_eq(RoomOverlay.tint_of(bad_room, bad_state.rooms.get_type_of(bad_room), bad_state.rooms.get_status(bad_room)), RoomOverlay.INCOMPLETE_TINT)
