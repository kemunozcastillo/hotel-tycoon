extends TestCase
## Pruebas de la llegada de huéspedes, la cola de la recepción y el check-in.
## (La asignación de dormitorio y la estancia se prueban en test_room_assignment.gd.)


# --- Llegada ---------------------------------------------------------------------------------

func test_arrival_creates_a_guest_with_its_agent_at_the_entrance() -> void:
	var state := HotelFixture.build(0)
	var arrived: Array[Guest] = []
	state.guests.guest_arrived.connect(func(guest: Guest) -> void: arrived.append(guest))
	var guest: Guest = state.guests.arrive(0)
	assert_true(guest != null)
	assert_eq(arrived.size(), 1)
	assert_eq(guest.state, Guest.State.ARRIVING)
	assert_eq(guest.entrance_cell, HotelFixture.ENTRANCE)
	assert_eq(guest.reception_room_id, HotelFixture.reception(state).id)
	var agent: Agent = state.agents.get_agent(guest.agent_id)
	assert_eq(agent.get_cell(), HotelFixture.ENTRANCE)
	assert_false(agent.wanders, "un huésped no pasea por su cuenta")
	assert_eq(agent.state, Agent.State.WALKING, "ya va hacia la recepción")
	assert_eq(state.guests.get_guest_by_agent(agent.id), guest)
	assert_eq(state.guests.total_arrived, 1)
	assert_eq(guest.ticket, 1)
	assert_eq(state.guests.arrive(0).ticket, 2, "los turnos son correlativos")


func test_arrival_needs_a_valid_entrance() -> void:
	var state := HotelFixture.build(0)
	state.entrances.remove(HotelFixture.ENTRANCE, 0)
	assert_eq(state.guests.arrive(0), null, "sin entrada")
	state.entrances.add(HotelFixture.ENTRANCE, 0)
	state.build.remove_floor(HotelFixture.ENTRANCE, 0)
	assert_eq(state.guests.arrive(0), null, "entrada sin suelo")
	state.build.place_floor(HotelFixture.ENTRANCE, 0)
	assert_true(state.guests.arrive(0) != null, "al volver el suelo, vuelve a funcionar")


func test_arrival_needs_an_operational_reachable_reception() -> void:
	var state := HotelFixture.build(0)
	var reception: Room = HotelFixture.reception(state)

	state.rooms.set_room_type(reception.id, &"")
	assert_eq(state.guests.arrive(0), null, "habitación sin tipo Recepción")
	state.rooms.set_room_type(reception.id, GuestRegistry.RECEPTION_TYPE)
	assert_true(state.guests.arrive(0) != null)

	var closed := HotelFixture.build(0)
	closed.build.clear_edge(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0) # sin puerta
	closed.build.place_wall(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0)
	assert_eq(closed.guests.arrive(0), null, "una recepción sin puerta no es operativa")

	var isolated := HotelFixture.build(0)
	isolated.build.outline_rect_walls(Rect2i(HotelFixture.ENTRANCE, Vector2i.ONE), 0)
	assert_eq(isolated.guests.arrive(0), null, "entrada aislada: la recepción es inalcanzable")


func test_waiting_guests_are_capped() -> void:
	var state := HotelFixture.build(0)
	for i in range(GuestRegistry.MAX_WAITING):
		assert_true(state.guests.arrive(0) != null, "llegada %d" % i)
	assert_eq(state.guests.get_waiting_count(0), GuestRegistry.MAX_WAITING)
	assert_eq(state.guests.arrive(0), null, "ya hay demasiados esperando")
	var first: Guest = state.guests.get_guests()[0]
	state.agents.remove(first.agent_id)
	assert_true(state.guests.arrive(0) != null, "al irse uno, cabe otro")


func test_arrival_picks_the_nearest_operational_reception() -> void:
	var state := HotelFixture.build(0)
	# Una segunda recepción lejos de la entrada.
	var far_rect := Rect2i(Vector2i(20, 2), Vector2i(4, 3))
	state.build.build_room(far_rect, 0)
	state.build.place_door(Edge.from_side(Vector2i(20, 3), Edge.Side.WEST), 0)
	state.rooms.set_room_type(state.rooms.get_room_at(far_rect.position, 0).id, GuestRegistry.RECEPTION_TYPE)
	var guest: Guest = state.guests.arrive(0)
	assert_eq(guest.reception_room_id, HotelFixture.reception(state).id, "la más cercana a la entrada")
	# Si la cercana deja de ser operativa, se usa la otra.
	state.build.clear_edge(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0)
	state.build.place_wall(Edge.from_side(Vector2i(8, 3), Edge.Side.WEST), 0)
	var second: Guest = state.guests.arrive(0)
	assert_eq(second.reception_room_id, state.rooms.get_room_at(far_rect.position, 0).id)


# --- Cola y check-in -------------------------------------------------------------------------

func test_guest_walks_to_reception_queues_and_checks_in_in_three_minutes() -> void:
	var state := HotelFixture.build(0)
	var guest: Guest = state.guests.arrive(0)
	var reception: Room = HotelFixture.reception(state)

	var to_check_in: float = HotelFixture.run_until(state, func() -> bool: return guest.state == Guest.State.CHECKING_IN)
	assert_true(to_check_in > 0.0, "llega y empieza el check-in (%.1f min)" % to_check_in)
	assert_true(reception.contains(state.agents.get_agent(guest.agent_id).get_cell()), "ya está dentro de la recepción")
	var check_in: float = HotelFixture.run_until(state, func() -> bool: return guest.state == Guest.State.WAITING_ROOM)
	assert_near(check_in, GuestRegistry.CHECK_IN_MINUTES, "el check-in dura 3 minutos", 0.15)


func test_check_in_is_one_at_a_time_and_in_arrival_order() -> void:
	var state := HotelFixture.build(0)
	var started: Array[int] = []
	state.guests.guest_state_changed.connect(func(guest: Guest) -> void:
		if guest.state == Guest.State.CHECKING_IN:
			started.append(guest.ticket))
	for i in range(3):
		state.guests.arrive(0)
	var most_at_once: int = 0
	for i in range(400): # 40 minutos: de sobra para tres check-ins y antes de que se acabe la paciencia
		state.tick(0.1)
		most_at_once = maxi(most_at_once, state.guests.count_in_state(Guest.State.CHECKING_IN))
	assert_eq(started, [1, 2, 3] as Array[int], "por orden de llegada")
	assert_eq(most_at_once, 1, "nunca dos a la vez")
	assert_eq(state.guests.count_in_state(Guest.State.WAITING_ROOM), 3, "los tres acaban registrados")


func test_each_waiting_guest_has_its_own_spot_in_the_reception() -> void:
	var state := HotelFixture.build(0)
	var guests: Array[Guest] = []
	for i in range(3):
		guests.append(state.guests.arrive(0))
	var targets: Dictionary = {}
	for guest: Guest in guests:
		targets[guest.target_cell] = true
	assert_eq(targets.size(), 3, "tres puestos distintos")
	var reception: Room = HotelFixture.reception(state)
	for guest: Guest in guests:
		assert_true(reception.contains(guest.target_cell), "dentro de la recepción")
	HotelFixture.run(state, 40.0)
	var cells: Dictionary = {}
	for guest: Guest in guests:
		cells[state.agents.get_agent(guest.agent_id).get_cell()] = true
	assert_eq(cells.size(), 3, "y acaban en celdas distintas")


func test_line_advances_when_the_head_finishes_check_in() -> void:
	var state := HotelFixture.build(0)
	var first: Guest = state.guests.arrive(0)
	var second: Guest = state.guests.arrive(0)
	var counter_spot: Vector2i = first.target_cell
	assert_true(second.target_cell != counter_spot, "el segundo no está en el mostrador")
	HotelFixture.run_until(state, func() -> bool: return first.state == Guest.State.WAITING_ROOM)
	assert_eq(second.target_cell, counter_spot, "al acabar el primero, el segundo ocupa el mostrador")
	assert_true(first.target_cell != counter_spot, "el que espera habitación se aparta")


func test_removing_a_guests_agent_frees_the_line() -> void:
	var state := HotelFixture.build(0)
	var first: Guest = state.guests.arrive(0)
	var second: Guest = state.guests.arrive(0)
	var counter_spot: Vector2i = first.target_cell
	var left: Array[Guest] = []
	state.guests.guest_left.connect(func(guest: Guest) -> void: left.append(guest))
	state.agents.remove(first.agent_id)
	assert_eq(state.guests.get_guest_count(), 1)
	assert_eq(state.guests.get_guest(first.id), null)
	assert_eq(left.size(), 1)
	assert_eq(second.target_cell, counter_spot, "el siguiente avanza")
	assert_eq(state.guests.total_left_happy + state.guests.total_left_unhappy, 0, "una retirada externa no cuenta como salida")


# --- Paciencia y salida ----------------------------------------------------------------------

func test_guest_without_a_room_loses_patience_and_leaves_unhappy() -> void:
	var state := HotelFixture.build(0) # sin dormitorios
	var guest: Guest = state.guests.arrive(0)
	var left: Array[Guest] = []
	state.guests.guest_left.connect(func(gone: Guest) -> void: left.append(gone))
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES - 2.0)
	assert_eq(guest.state, Guest.State.WAITING_ROOM, "sigue esperando antes de que se acabe la paciencia")
	HotelFixture.run(state, 3.0)
	assert_eq(guest.state, Guest.State.LEAVING)
	assert_true(guest.left_unhappy)
	assert_eq(state.agents.get_agent(guest.agent_id).destination, HotelFixture.ENTRANCE, "se va por la entrada")
	HotelFixture.run_until(state, func() -> bool: return state.guests.get_guest_count() == 0)
	assert_eq(left.size(), 1)
	assert_true(left[0].left_unhappy)
	assert_eq(state.guests.total_left_unhappy, 1)
	assert_eq(state.agents.get_agents().size(), 0, "el agente desaparece al llegar a la entrada")


func test_leaving_without_a_valid_entrance_vanishes_on_the_spot() -> void:
	var state := HotelFixture.build(0)
	var guest: Guest = state.guests.arrive(0)
	HotelFixture.run(state, 20.0)
	state.entrances.remove(HotelFixture.ENTRANCE, 0)
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES - 19.0)
	assert_eq(state.guests.get_guest(guest.id), null, "no hay por dónde salir: desaparece")
	assert_eq(state.guests.total_left_unhappy, 1)
	assert_eq(state.agents.get_agents().size(), 0)


func test_guest_that_cannot_reach_the_reception_eventually_gives_up() -> void:
	var state := HotelFixture.build(0)
	var guest: Guest = state.guests.arrive(0)
	# Se emparedan las celdas junto a la entrada: el huésped queda encerrado.
	state.build.outline_rect_walls(Rect2i(HotelFixture.ENTRANCE, Vector2i.ONE), 0)
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES + 5.0)
	assert_eq(state.guests.get_guest(guest.id), null, "se cansa de esperar")
	assert_eq(state.guests.total_left_unhappy, 1)


# --- Reloj -----------------------------------------------------------------------------------

func test_everything_scales_with_the_clock_and_stops_when_paused() -> void:
	var normal := HotelFixture.build(0)
	var fast := HotelFixture.build(0)
	fast.clock.set_speed(GameClock.Speed.X3)
	var paused := HotelFixture.build(0)
	paused.clock.set_speed(GameClock.Speed.PAUSED)
	var ticks: Dictionary = {}
	for pair: Array in [["normal", normal], ["fast", fast]]:
		var state: GameState = pair[1]
		var guest: Guest = state.guests.arrive(0)
		var count: int = 0
		while guest.state != Guest.State.WAITING_ROOM and count < 3000:
			state.tick(0.1)
			count += 1
		ticks[pair[0]] = count
	assert_true(float(ticks["normal"]) / float(ticks["fast"]) > 2.5 and float(ticks["normal"]) / float(ticks["fast"]) < 3.5,
			"a x3 tarda un tercio (%d frente a %d)" % [ticks["normal"], ticks["fast"]])

	var frozen: Guest = paused.guests.arrive(0)
	var start: Vector2 = paused.agents.get_agent(frozen.agent_id).position
	for i in range(300):
		paused.tick(0.1)
	assert_eq(frozen.state, Guest.State.ARRIVING)
	assert_eq(paused.agents.get_agent(frozen.agent_id).position, start)
	assert_near(frozen.waited_minutes, 0.0)
