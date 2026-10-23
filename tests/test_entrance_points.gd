extends TestCase
## Pruebas de los marcadores de entrada de huéspedes.

const MAP_SIZE := Vector2i(10, 8)


func _state() -> GameState:
	var state := GameState.new(MAP_SIZE)
	state.build.fill_rect_floor(Rect2i(Vector2i.ZERO, Vector2i(6, 6)), 0)
	return state


func test_add_requires_a_walkable_cell() -> void:
	var state := _state()
	assert_true(state.entrances.add(Vector2i(1, 1), 0))
	assert_false(state.entrances.add(Vector2i(8, 7), 0), "sin suelo")
	assert_false(state.entrances.add(Vector2i(-1, 0), 0), "fuera del mapa")
	assert_false(state.entrances.add(Vector2i(1, 1), 3), "nivel inexistente")
	assert_false(state.entrances.add(Vector2i(1, 1), 0), "ya era una entrada")
	assert_eq(state.entrances.get_all(0), [Vector2i(1, 1)] as Array[Vector2i])


func test_remove_and_has() -> void:
	var state := _state()
	state.entrances.add(Vector2i(2, 2), 0)
	assert_true(state.entrances.has(Vector2i(2, 2), 0))
	assert_true(state.entrances.remove(Vector2i(2, 2), 0))
	assert_false(state.entrances.has(Vector2i(2, 2), 0))
	assert_false(state.entrances.remove(Vector2i(2, 2), 0), "ya no está")


func test_entrances_keep_placement_order() -> void:
	var state := _state()
	for cell: Vector2i in [Vector2i(3, 0), Vector2i(0, 3), Vector2i(5, 5)]:
		state.entrances.add(cell, 0)
	assert_eq(state.entrances.get_all(0), [Vector2i(3, 0), Vector2i(0, 3), Vector2i(5, 5)] as Array[Vector2i])


func test_losing_the_floor_makes_the_entrance_invalid_but_keeps_it() -> void:
	var state := _state()
	state.entrances.add(Vector2i(2, 2), 0)
	state.entrances.add(Vector2i(3, 3), 0)
	state.build.remove_floor(Vector2i(2, 2), 0)
	assert_eq(state.entrances.get_all(0).size(), 2, "se conserva")
	assert_eq(state.entrances.get_valid(0), [Vector2i(3, 3)] as Array[Vector2i], "pero no es válida")
	state.build.place_floor(Vector2i(2, 2), 0)
	assert_eq(state.entrances.get_valid(0).size(), 2, "al volver el suelo, vuelve a valer")


func test_levels_are_independent_and_results_are_copies() -> void:
	var state := _state()
	state.grid.add_level(1)
	state.build.place_floor(Vector2i(1, 1), 1)
	state.entrances.add(Vector2i(1, 1), 0)
	state.entrances.add(Vector2i(1, 1), 1)
	state.entrances.remove(Vector2i(1, 1), 0)
	assert_eq(state.entrances.get_all(0).size(), 0)
	assert_eq(state.entrances.get_all(1).size(), 1)
	state.entrances.get_all(1).clear()
	assert_eq(state.entrances.get_all(1).size(), 1, "get_all devuelve una copia")


func test_signal_only_on_real_changes() -> void:
	var state := _state()
	var count: Array[int] = [0]
	state.entrances.entrances_changed.connect(func() -> void: count[0] += 1)
	state.entrances.add(Vector2i(1, 1), 0)
	state.entrances.add(Vector2i(1, 1), 0)
	state.entrances.add(Vector2i(9, 9), 0)
	state.entrances.remove(Vector2i(1, 1), 0)
	state.entrances.remove(Vector2i(1, 1), 0)
	assert_eq(count[0], 2)
