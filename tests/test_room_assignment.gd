extends TestCase
## Pruebas de la ocupación de habitaciones, la asignación de dormitorio, la reasignación, la
## estancia y la salida de los huéspedes.


func _stage(state: GameState, guest: Guest, stage: Guest.State) -> float:
	return HotelFixture.run_until(state, func() -> bool: return guest.state == stage, 600.0)


# --- RoomOccupancy -----------------------------------------------------------------------

func test_occupancy_reserve_and_release() -> void:
	var occupancy := RoomOccupancy.new()
	var changes: Array[int] = [0]
	occupancy.occupancy_changed.connect(func() -> void: changes[0] += 1)
	assert_true(occupancy.is_free(5))
	assert_true(occupancy.reserve(5, 10))
	assert_false(occupancy.is_free(5))
	assert_eq(occupancy.occupant_of(5), 10)
	assert_eq(occupancy.room_of(10), 5)
	assert_false(occupancy.reserve(5, 11), "la habitación ya está ocupada")
	assert_false(occupancy.reserve(6, 10), "el huésped ya tiene otra habitación")
	assert_eq(occupancy.release_guest(10), 5)
	assert_eq(occupancy.release_guest(10), 0, "ya no tenía")
	assert_true(occupancy.is_free(5))
	assert_eq(occupancy.occupant_of(5), 0)
	assert_eq(occupancy.room_of(10), 0)
	assert_eq(changes[0], 2, "una señal por reserva y otra por liberación")
	occupancy.reserve(8, 1)
	occupancy.reserve(3, 2)
	assert_eq(occupancy.get_occupied_room_ids(), [3, 8] as Array[int])


# --- Asignación ------------------------------------------------------------------------------

func test_full_stay_nearest_bedroom_then_leaves_happy() -> void:
	var state := HotelFixture.build(3)
	var guest: Guest = state.guests.arrive(0)
	var checked_in: Array[Guest] = []
	state.guests.guest_checked_in.connect(func(g: Guest) -> void: checked_in.append(g))
	_stage(state, guest, Guest.State.CHECKING_IN)
	var origin: Vector2i = state.agents.get_agent(guest.agent_id).get_cell()
	_stage(state, guest, Guest.State.GOING_TO_ROOM)

	# El elegido es el dormitorio más cercano al puesto del check-in (cálculo independiente).
	var costs: Dictionary = Pathfinder.reachable_costs(state.grid, 0, origin)
	var expected: Room = null
	var expected_cost: float = INF
	for i in range(3):
		var room: Room = HotelFixture.bedroom(state, i)
		for cell: Vector2i in room.cells:
			if costs.has(cell) and float(costs[cell]) < expected_cost:
				expected_cost = costs[cell]
				expected = room
	assert_eq(guest.room_id, expected.id, "el más cercano")
	assert_eq(state.guests.occupancy.occupant_of(expected.id), guest.id)
	assert_eq(state.guests.occupancy.room_of(guest.id), expected.id)
	assert_true(expected.contains(guest.target_cell), "va a una celda del dormitorio")
	assert_eq(checked_in.size(), 1)
	assert_eq(state.guests.total_checked_in, 1)
	assert_eq(state.guests.count_bedrooms(0), Vector2i(2, 3), "queda una ocupada de tres")

	# Llega y se aloja durante entre 2 y 6 horas de juego.
	assert_true(_stage(state, guest, Guest.State.STAYING) > 0.0)
	assert_true(expected.contains(state.agents.get_agent(guest.agent_id).get_cell()), "está dentro")
	var stay: float = _stage(state, guest, Guest.State.LEAVING)
	assert_true(stay >= GuestRegistry.STAY_MIN_MINUTES - 0.3 and stay <= GuestRegistry.STAY_MAX_MINUTES + 0.3, "estancia de %.1f min" % stay)
	assert_true(state.guests.occupancy.is_free(expected.id), "al irse, libera la habitación")
	assert_eq(guest.room_id, 0)
	assert_false(guest.left_unhappy)

	var gone: float = HotelFixture.run_until(state, func() -> bool: return state.guests.get_guest_count() == 0, 300.0)
	assert_true(gone >= 0.0, "sale por la entrada")
	assert_eq(state.guests.total_left_happy, 1)
	assert_eq(state.guests.total_left_unhappy, 0)
	assert_eq(state.agents.get_agents().size(), 0)
	assert_eq(state.guests.count_bedrooms(0), Vector2i(3, 3))


func test_two_guests_never_get_the_same_bedroom() -> void:
	var state := HotelFixture.build(2)
	var first: Guest = state.guests.arrive(0)
	var second: Guest = state.guests.arrive(0)
	_stage(state, first, Guest.State.GOING_TO_ROOM)
	_stage(state, second, Guest.State.GOING_TO_ROOM)
	assert_true(first.room_id != 0 and second.room_id != 0)
	assert_true(first.room_id != second.room_id, "cada uno su dormitorio")
	assert_eq(state.guests.count_bedrooms(0), Vector2i(0, 2))


func test_without_free_bedrooms_the_oldest_waiting_guest_gets_the_next_one() -> void:
	var state := HotelFixture.build(1)
	var first: Guest = state.guests.arrive(0)
	var second: Guest = state.guests.arrive(0)
	var third: Guest = state.guests.arrive(0)
	_stage(state, first, Guest.State.STAYING)
	_stage(state, third, Guest.State.WAITING_ROOM)
	assert_eq(second.room_id, 0)
	assert_eq(third.room_id, 0)
	# El primero se marcha (aquí, retirando su agente): queda libre la habitación.
	var room_id: int = first.room_id
	state.agents.remove(first.agent_id)
	HotelFixture.run(state, 0.5)
	assert_eq(second.room_id, room_id, "el más antiguo en espera la recibe")
	assert_eq(second.state, Guest.State.GOING_TO_ROOM)
	assert_eq(third.room_id, 0)
	assert_eq(third.state, Guest.State.WAITING_ROOM)


func test_unusable_bedrooms_are_skipped_and_used_once_they_are_fixed() -> void:
	var state := HotelFixture.build(2)
	state.rooms.set_room_type(HotelFixture.bedroom(state, 0).id, &"") # sin tipo
	var door: Edge = Edge.from_side(HotelFixture.bedroom_rect(1).position, Edge.Side.NORTH)
	state.build.place_wall(door, 0) # sin puerta: no es operativo
	assert_eq(state.guests.count_bedrooms(0), Vector2i(0, 0))
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.WAITING_ROOM)
	HotelFixture.run(state, 2.0)
	assert_eq(guest.state, Guest.State.WAITING_ROOM, "no hay dormitorio utilizable")
	assert_eq(guest.room_id, 0)

	state.build.place_door(door, 0) # se arregla: el huésped que esperaba lo recibe sin más
	HotelFixture.run(state, 0.5)
	assert_eq(guest.state, Guest.State.GOING_TO_ROOM)
	assert_eq(guest.room_id, HotelFixture.bedroom(state, 1).id)


func test_unreachable_bedrooms_are_skipped() -> void:
	var state := HotelFixture.build(0)
	# Un recinto cerrado sin puerta con un dormitorio operativo dentro: inalcanzable.
	state.build.build_room(Rect2i(Vector2i(20, 2), Vector2i(6, 5)), 0)
	var inner := Rect2i(Vector2i(22, 3), Vector2i(3, 2))
	state.build.build_room(inner, 0)
	state.build.place_door(Edge.from_side(inner.position, Edge.Side.NORTH), 0)
	var bedroom: Room = state.rooms.get_room_at(inner.position, 0)
	state.rooms.set_room_type(bedroom.id, GuestRegistry.BEDROOM_TYPE)
	assert_true(state.rooms.get_status(bedroom).is_operational(), "el dormitorio sellado cumple los requisitos")
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.WAITING_ROOM)
	HotelFixture.run(state, 3.0)
	assert_eq(guest.room_id, 0, "no se asigna un dormitorio al que no se puede llegar")


func test_reassigned_when_the_room_is_demolished_on_the_way() -> void:
	var state := HotelFixture.build(2)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.GOING_TO_ROOM)
	var lost_id: int = guest.room_id
	var lost_index: int = 0 if HotelFixture.bedroom(state, 0).id == lost_id else 1
	state.build.demolish_room(HotelFixture.bedroom_rect(lost_index), 0)
	HotelFixture.run(state, 0.3)
	assert_true(guest.room_id != lost_id and guest.room_id != 0, "le dan el otro dormitorio")
	assert_eq(guest.state, Guest.State.GOING_TO_ROOM)
	assert_true(state.guests.occupancy.is_free(lost_id), "la habitación perdida queda libre")
	assert_eq(state.guests.occupancy.room_of(guest.id), guest.room_id)

	# Si tampoco queda el otro, espera con la paciencia renovada.
	state.build.demolish_room(HotelFixture.bedroom_rect(1 - lost_index), 0)
	HotelFixture.run(state, 0.3)
	assert_eq(guest.state, Guest.State.WAITING_ROOM)
	assert_eq(guest.room_id, 0)
	assert_true(guest.waited_minutes < 1.0, "paciencia renovada")
	assert_eq(state.guests.occupancy.get_occupied_room_ids().size(), 0)


func test_staying_guest_is_moved_when_his_room_stops_being_operational() -> void:
	var state := HotelFixture.build(2)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	var first_room: int = guest.room_id
	# Se cambia el tipo de su habitación: deja de ser un dormitorio (y el huésped no queda encerrado).
	state.rooms.set_room_type(first_room, &"bathroom")
	HotelFixture.run(state, 0.3)
	assert_true(guest.room_id != first_room and guest.room_id != 0, "le dan el otro dormitorio")
	assert_eq(guest.state, Guest.State.GOING_TO_ROOM)
	assert_true(state.guests.occupancy.is_free(first_room))
	assert_eq(state.guests.occupancy.room_of(guest.id), guest.room_id)


func test_guest_trapped_on_the_way_gives_up_the_room_and_later_leaves() -> void:
	var state := HotelFixture.build(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.GOING_TO_ROOM)
	# Se cierra la puerta de la recepción con el huésped dentro: no puede salir.
	state.build.place_wall(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0)
	HotelFixture.run(state, GuestRegistry.BLOCKED_PATIENCE_MINUTES + 3.0)
	assert_eq(guest.state, Guest.State.WAITING_ROOM, "renuncia a una habitación a la que no llega")
	assert_eq(guest.room_id, 0)
	assert_true(state.guests.occupancy.is_free(HotelFixture.bedroom(state, 0).id))
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES + 5.0)
	assert_eq(state.guests.get_guest(guest.id), null, "y acaba marchándose")
	assert_eq(state.guests.total_left_unhappy, 1)


func test_guest_sealed_inside_his_room_cannot_be_reassigned_and_gives_up_waiting() -> void:
	var state := HotelFixture.build(2)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	var first_room: int = guest.room_id
	var index: int = 0 if HotelFixture.bedroom(state, 0).id == first_room else 1
	# Se tapia la puerta con el huésped dentro: pierde la habitación y no puede llegar a la otra.
	state.build.place_wall(Edge.from_side(HotelFixture.bedroom_rect(index).position, Edge.Side.NORTH), 0)
	HotelFixture.run(state, 0.3)
	assert_eq(guest.state, Guest.State.WAITING_ROOM)
	assert_eq(guest.room_id, 0)
	assert_true(state.guests.occupancy.is_free(first_room))
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES + 2.0)
	assert_eq(state.guests.get_guest(guest.id), null, "encerrado, acaba desapareciendo")
	assert_eq(state.guests.total_left_unhappy, 1)


func test_removing_a_staying_guests_agent_frees_the_room() -> void:
	var state := HotelFixture.build(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	var room_id: int = guest.room_id
	state.agents.remove(guest.agent_id)
	assert_true(state.guests.occupancy.is_free(room_id))
	assert_eq(state.guests.count_bedrooms(0), Vector2i(1, 1))


func test_bedroom_counts_follow_the_rooms() -> void:
	var state := HotelFixture.build(3)
	assert_eq(state.guests.count_bedrooms(0), Vector2i(3, 3))
	state.build.place_wall(Edge.from_side(HotelFixture.bedroom_rect(2).position, Edge.Side.NORTH), 0)
	assert_eq(state.guests.count_bedrooms(0), Vector2i(2, 2), "uno dejó de ser operativo")
	state.rooms.set_room_type(HotelFixture.bedroom(state, 0).id, &"bathroom")
	assert_eq(state.guests.count_bedrooms(0), Vector2i(1, 1), "y otro cambió de tipo")


# --- Invariantes y determinismo ----------------------------------------------------------------

func test_invariants_hold_over_a_long_busy_simulation() -> void:
	var state := HotelFixture.build(3, 11)
	var max_checking: int = 0
	for step in range(7000): # 700 minutos de juego
		if step % 70 == 0:
			state.guests.arrive(0) # un intento de llegada cada 7 minutos
		state.tick(0.1)
		max_checking = maxi(max_checking, state.guests.count_in_state(Guest.State.CHECKING_IN))
		_assert_consistent(state, step)
	assert_true(state.guests.total_arrived > 30, "llegaron huéspedes (%d)" % state.guests.total_arrived)
	assert_true(state.guests.total_checked_in > 5, "se alojaron (%d)" % state.guests.total_checked_in)
	assert_true(state.guests.total_left_happy > 0, "algunos terminaron su estancia (%d)" % state.guests.total_left_happy)
	assert_true(state.guests.total_left_unhappy > 0, "otros se cansaron de esperar (%d)" % state.guests.total_left_unhappy)
	assert_true(max_checking <= 1, "un solo check-in a la vez")


func _assert_consistent(state: GameState, step: int) -> void:
	var seen_rooms: Dictionary = {}
	for guest: Guest in state.guests.get_guests():
		var has_room: bool = guest.state == Guest.State.GOING_TO_ROOM or guest.state == Guest.State.STAYING
		if has_room != (guest.room_id != 0):
			assert_true(false, "paso %d: huésped %d en %d con habitación %d" % [step, guest.id, guest.state, guest.room_id])
			return
		if guest.room_id == 0:
			continue
		if seen_rooms.has(guest.room_id):
			assert_true(false, "paso %d: dos huéspedes en la habitación %d" % [step, guest.room_id])
			return
		seen_rooms[guest.room_id] = true
		if state.guests.occupancy.occupant_of(guest.room_id) != guest.id:
			assert_true(false, "paso %d: la ocupación no coincide para %d" % [step, guest.id])
			return
		var room: Room = state.rooms.get_room(guest.room_id)
		if room == null or room.type_id != GuestRegistry.BEDROOM_TYPE:
			assert_true(false, "paso %d: la habitación %d no es un dormitorio" % [step, guest.room_id])
			return
	var occupied: Array[int] = state.guests.occupancy.get_occupied_room_ids()
	if occupied.size() != seen_rooms.size():
		assert_true(false, "paso %d: %d ocupadas en el registro y %d con huésped" % [step, occupied.size(), seen_rooms.size()])
		return
	assert_true(true)


func test_the_same_seed_gives_the_same_hotel_history() -> void:
	var results: Array[Array] = []
	for run in range(2):
		var state := HotelFixture.build(2, 99)
		for step in range(4000):
			if step % 60 == 0:
				state.guests.arrive(0)
			state.tick(0.1)
		results.append([state.guests.total_arrived, state.guests.total_checked_in, state.guests.total_left_happy,
				state.guests.total_left_unhappy, state.guests.get_guest_count()])
	assert_eq(results[0], results[1])
