extends TestCase
## Pruebas del reloj de juego: pausa, velocidades y conversión de tiempo.


func test_starts_running_at_x1_on_day_one_morning() -> void:
	var clock := GameClock.new()
	assert_eq(clock.speed, GameClock.Speed.X1)
	assert_false(clock.is_paused())
	assert_eq(clock.get_day(), 1)
	assert_eq(clock.get_hour(), 8)
	assert_eq(clock.get_minute(), 0)


func test_tick_scales_with_speed() -> void:
	var clock := GameClock.new()
	var start: float = clock.total_minutes
	assert_near(clock.tick(1.0), 1.0, "x1: un segundo real = un minuto de juego")
	clock.set_speed(GameClock.Speed.X2)
	assert_near(clock.tick(1.0), 2.0, "x2")
	clock.set_speed(GameClock.Speed.X3)
	assert_near(clock.tick(1.0), 3.0, "x3")
	assert_near(clock.total_minutes - start, 6.0, "el total acumula lo devuelto")


func test_pause_stops_time() -> void:
	var clock := GameClock.new()
	clock.set_speed(GameClock.Speed.PAUSED)
	var before: float = clock.total_minutes
	assert_near(clock.tick(10.0), 0.0)
	assert_eq(clock.total_minutes, before)
	assert_true(clock.is_paused())


func test_toggle_pause_remembers_previous_speed() -> void:
	var clock := GameClock.new()
	clock.set_speed(GameClock.Speed.X3)
	clock.toggle_pause()
	assert_eq(clock.speed, GameClock.Speed.PAUSED)
	clock.toggle_pause()
	assert_eq(clock.speed, GameClock.Speed.X3, "vuelve a x3, no a x1")
	# Cambiar de velocidad estando en pausa reanuda a esa velocidad.
	clock.toggle_pause()
	clock.set_speed(GameClock.Speed.X2)
	assert_false(clock.is_paused())
	clock.toggle_pause()
	clock.toggle_pause()
	assert_eq(clock.speed, GameClock.Speed.X2)


func test_speed_changed_signal_only_on_change() -> void:
	var clock := GameClock.new()
	var events: Array[int] = []
	clock.speed_changed.connect(func(new_speed: GameClock.Speed) -> void: events.append(new_speed))
	clock.set_speed(GameClock.Speed.X1) # ya estaba en x1: sin señal
	clock.set_speed(GameClock.Speed.X2)
	clock.toggle_pause()
	clock.toggle_pause()
	assert_eq(events, [GameClock.Speed.X2, GameClock.Speed.PAUSED, GameClock.Speed.X2] as Array[int])


func test_day_hour_minute_rollover() -> void:
	var clock := GameClock.new()
	clock.total_minutes = 0.0
	assert_eq([clock.get_day(), clock.get_hour(), clock.get_minute()], [1, 0, 0])
	clock.total_minutes = 23.0 * 60 + 59
	assert_eq([clock.get_day(), clock.get_hour(), clock.get_minute()], [1, 23, 59])
	clock.total_minutes = 24.0 * 60
	assert_eq([clock.get_day(), clock.get_hour(), clock.get_minute()], [2, 0, 0], "medianoche pasa al día 2")
	clock.total_minutes = 3.0 * 24 * 60 + 14 * 60 + 5.9
	assert_eq([clock.get_day(), clock.get_hour(), clock.get_minute()], [4, 14, 5])


func test_game_state_ticks_its_clock() -> void:
	var state := GameState.new(Vector2i(4, 4))
	var before: float = state.clock.total_minutes
	state.tick(2.0)
	assert_near(state.clock.total_minutes - before, 2.0)
	state.clock.set_speed(GameClock.Speed.PAUSED)
	state.tick(2.0)
	assert_near(state.clock.total_minutes - before, 2.0, "en pausa no avanza")
