extends TestCase
## Pruebas de las llegadas automáticas de huéspedes.


## Avanza `ticks` pasos de 0,1 s reales retirando a cada huésped en cuanto llega (así la cola
## nunca se llena y solo se mide el ritmo de llegadas). Devuelve los minutos de juego de cada llegada.
func _arrival_times(state: GameState, ticks: int) -> Array[float]:
	var times: Array[float] = []
	# Se captura solo el reloj: capturar `state` crearía un ciclo de referencias (y fugas al cerrar).
	var clock: GameClock = state.clock
	state.guests.guest_arrived.connect(func(_guest: Guest) -> void: times.append(clock.total_minutes))
	for i in range(ticks):
		state.tick(0.1)
		for guest: Guest in state.guests.get_guests():
			state.agents.remove(guest.agent_id)
	return times


func test_arrivals_come_every_15_to_45_minutes() -> void:
	var state := HotelFixture.build(2, 5, true)
	var start: float = state.clock.total_minutes
	var times: Array[float] = _arrival_times(state, 6000) # 600 minutos
	assert_true(times.size() >= 12 and times.size() <= 40, "llegadas en 600 min: %d" % times.size())
	assert_true(times[0] - start >= GuestSpawner.MIN_INTERVAL_MINUTES - 0.2 and times[0] - start <= GuestSpawner.MAX_INTERVAL_MINUTES + 0.2, "la primera, a los %.1f min" % (times[0] - start))
	for i in range(1, times.size()):
		var gap: float = times[i] - times[i - 1]
		assert_true(gap >= GuestSpawner.MIN_INTERVAL_MINUTES - 0.2 and gap <= GuestSpawner.MAX_INTERVAL_MINUTES + 0.2, "intervalo %d de %.1f min" % [i, gap])


func test_nobody_arrives_without_an_entrance_or_a_reception() -> void:
	var no_entrance := HotelFixture.build(2, 5, true)
	no_entrance.entrances.remove(HotelFixture.ENTRANCE, 0)
	assert_eq(_arrival_times(no_entrance, 3000).size(), 0, "sin entrada")

	var no_reception := HotelFixture.build(2, 5, true)
	no_reception.rooms.set_room_type(HotelFixture.reception(no_reception).id, &"")
	assert_eq(_arrival_times(no_reception, 3000).size(), 0, "sin recepción")

	var no_bedrooms := HotelFixture.build(0, 5, true)
	assert_true(_arrival_times(no_bedrooms, 3000).size() > 0, "sin dormitorios sí llegan (esperan y se van)")


func test_disabled_and_paused_spawner_brings_nobody() -> void:
	var disabled := HotelFixture.build(2, 5, true)
	disabled.spawner.enabled = false
	assert_eq(_arrival_times(disabled, 3000).size(), 0)
	var paused := HotelFixture.build(2, 5, true)
	paused.clock.set_speed(GameClock.Speed.PAUSED)
	assert_eq(_arrival_times(paused, 3000).size(), 0)


func test_arrivals_follow_the_clock_speed() -> void:
	var normal := HotelFixture.build(2, 5, true)
	var fast := HotelFixture.build(2, 5, true)
	fast.clock.set_speed(GameClock.Speed.X3)
	var normal_count: int = _arrival_times(normal, 4000).size()
	var fast_count: int = _arrival_times(fast, 4000).size()
	assert_true(normal_count > 5, "referencia (%d)" % normal_count)
	var ratio: float = float(fast_count) / float(normal_count)
	assert_true(ratio > 2.0 and ratio < 4.0, "a x3 llegan unas tres veces más (%d frente a %d)" % [fast_count, normal_count])


func test_the_same_seed_gives_the_same_arrivals() -> void:
	var first: Array[float] = _arrival_times(HotelFixture.build(2, 77, true), 3000)
	var second: Array[float] = _arrival_times(HotelFixture.build(2, 77, true), 3000)
	assert_eq(first, second)
	var other: Array[float] = _arrival_times(HotelFixture.build(2, 78, true), 3000)
	assert_true(other != first, "otra semilla, otras llegadas")


func test_a_rejected_arrival_is_lost_and_the_next_is_scheduled() -> void:
	var state := HotelFixture.build(0, 5, true)
	# Con la cola llena, la llegada que toca se pierde.
	for i in range(GuestRegistry.MAX_WAITING):
		state.guests.arrive(0)
	var arrived_before: int = state.guests.total_arrived
	HotelFixture.run(state, GuestSpawner.MAX_INTERVAL_MINUTES + 1.0)
	# Pueden haberse ido algunos por paciencia, pero no hubo más llegadas de las posibles.
	assert_true(state.guests.get_waiting_count(0) <= GuestRegistry.MAX_WAITING)
	assert_true(state.spawner.get_minutes_until_next() > 0.0)
	assert_true(state.guests.total_arrived >= arrived_before)


func test_a_busy_hotel_with_automatic_arrivals_stays_consistent() -> void:
	var state := HotelFixture.build(3, 21, true)
	for step in range(12000): # 1.200 minutos: más de dos días de juego
		state.tick(0.1)
		var rooms: Dictionary = {}
		for guest: Guest in state.guests.get_guests():
			if guest.room_id != 0:
				assert_false(rooms.has(guest.room_id), "dos huéspedes en la misma habitación")
				rooms[guest.room_id] = true
		assert_true(state.guests.count_in_state(Guest.State.CHECKING_IN) <= 1)
		assert_true(state.guests.get_waiting_count(0) <= GuestRegistry.MAX_WAITING)
	assert_true(state.guests.total_arrived > 20, "llegadas (%d)" % state.guests.total_arrived)
	assert_true(state.guests.total_checked_in > 5, "alojados (%d)" % state.guests.total_checked_in)
	assert_true(state.guests.total_left_happy > 0, "estancias completas (%d)" % state.guests.total_left_happy)
