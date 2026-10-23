extends TestCase
## Pruebas del mantenimiento diario de las habitaciones y de la venta de piezas del inventario.

const MINUTES_PER_DAY: float = 24.0 * 60.0


func _rules() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 1000000
	return rules


## Un hotel con la recepción (30 al día) y N dormitorios (20 al día cada uno).
func _hotel(bedrooms: int = 2) -> GameState:
	return HotelFixture.build(bedrooms, 1, false, _rules())


func _upkeep_on(state: GameState, day: int) -> int:
	return state.ledger.get_day_total(day, Ledger.Category.UPKEEP)


## Avanza el reloj en pasos grandes (sin llegadas ni nada más que el reloj y el mantenimiento).
func _run_days(state: GameState, minutes: float) -> void:
	var steps: int = roundi(minutes / 10.0)
	for i in range(steps):
		state.tick(10.0)


# --- Mantenimiento ------------------------------------------------------------------------------

func test_daily_upkeep_is_the_sum_of_every_typed_room() -> void:
	var state := _hotel(2)
	assert_eq(state.economy.daily_upkeep(), 2 * 20 + 30)
	var rect := Rect2i(Vector2i(14, 9), Vector2i(2, 2))
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	assert_eq(state.economy.daily_upkeep(), 70, "una habitación sin tipo no cuesta nada")
	state.rooms.set_room_type(state.rooms.get_room_at(rect.position, 0).id, &"bathroom")
	assert_eq(state.economy.daily_upkeep(), 80, "un baño cuesta 10")


func test_upkeep_is_charged_when_a_new_day_starts_and_not_before() -> void:
	var state := _hotel(2)
	var first_day: int = state.clock.get_day()
	_run_days(state, 15.0 * 60.0) # de las 08:00 a las 23:00 del primer día
	assert_eq(state.clock.get_day(), first_day)
	assert_eq(_upkeep_on(state, first_day), 0, "el primer día no se cobra nada al empezar")
	_run_days(state, 2.0 * 60.0) # pasada la medianoche
	assert_eq(state.clock.get_day(), first_day + 1)
	assert_eq(_upkeep_on(state, first_day + 1), -70, "al empezar el día 2 se cobran las tres habitaciones")


func test_every_new_day_charges_again() -> void:
	var state := _hotel(2)
	var first_day: int = state.clock.get_day()
	_run_days(state, 3.0 * MINUTES_PER_DAY)
	for day in range(first_day + 1, first_day + 4):
		assert_eq(_upkeep_on(state, day), -70, "día %d" % day)
	assert_eq(_upkeep_on(state, first_day), 0)


func test_jumping_several_days_charges_each_one_in_its_own_day() -> void:
	var state := _hotel(2)
	var first_day: int = state.clock.get_day()
	var balance: int = state.ledger.balance
	state.clock.total_minutes += 3.0 * MINUTES_PER_DAY
	state.tick(0.1)
	for day in range(first_day + 1, first_day + 4):
		assert_eq(_upkeep_on(state, day), -70, "día %d" % day)
	assert_eq(state.ledger.balance, balance - 3 * 70, "se cobraron los tres días")
	state.tick(0.1)
	assert_eq(state.ledger.balance, balance - 3 * 70, "y no se vuelve a cobrar")


func test_the_charge_follows_the_rooms_that_exist_that_day() -> void:
	var state := _hotel(2)
	var first_day: int = state.clock.get_day()
	_run_days(state, 17.0 * 60.0) # pasa a día 2
	assert_eq(_upkeep_on(state, first_day + 1), -70)
	state.build.demolish_room(HotelFixture.bedroom_rect(1), 0)
	_run_days(state, MINUTES_PER_DAY)
	assert_eq(_upkeep_on(state, first_day + 2), -50, "con un dormitorio menos")


func test_a_typed_room_that_is_not_operational_still_costs_upkeep() -> void:
	var state := _hotel(1)
	state.build.place_wall(Edge.from_side(HotelFixture.bedroom_rect(0).position, Edge.Side.NORTH), 0) # sin puerta
	assert_false(state.rooms.get_status(HotelFixture.bedroom(state, 0)).is_operational())
	assert_eq(state.economy.daily_upkeep(), 50)


func test_upkeep_can_leave_the_balance_negative() -> void:
	var state := _hotel(2)
	state.ledger.record(Ledger.Category.SALE, -(state.ledger.balance - 50), "se deja casi sin dinero")
	assert_eq(state.ledger.balance, 50)
	_run_days(state, 17.0 * 60.0)
	assert_eq(state.ledger.balance, -20, "el mantenimiento sí puede dejar el saldo en negativo")


func test_without_charges_there_is_no_upkeep() -> void:
	var state := HotelFixture.build(2) # reglas sin costes
	_run_days(state, 3.0 * MINUTES_PER_DAY)
	assert_eq(state.ledger.balance, 0)
	assert_eq(state.ledger.get_recent(10).size(), 0)


func test_the_upkeep_entry_is_labelled() -> void:
	var state := _hotel(1)
	_run_days(state, 17.0 * 60.0)
	var recent: Array[Dictionary] = state.ledger.get_recent(1)
	assert_eq(recent[0]["category"], Ledger.Category.UPKEEP)
	assert_eq(recent[0]["note"], "Mantenimiento diario")


# --- Venta de piezas del inventario ------------------------------------------------------------------

func test_selling_new_stock_pays_the_full_price() -> void:
	var state := _hotel(0)
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 3)
	var balance: int = state.ledger.balance
	assert_eq(state.economy.sell_stock(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 3), 30)
	assert_eq(state.ledger.balance, balance + 30)
	assert_eq(state.inventory.total(BuildItem.Kind.FLOOR), 0)
	assert_eq(state.ledger.get_recent(1)[0]["category"], Ledger.Category.SALE)


func test_selling_used_stock_pays_85_percent() -> void:
	var state := _hotel(0)
	state.inventory.add(BuildItem.Kind.DOOR, BuildItem.Condition.USED, 2)
	state.inventory.add(BuildItem.Kind.WALL, BuildItem.Condition.USED, 4)
	assert_eq(state.economy.sell_stock(BuildItem.Kind.DOOR, BuildItem.Condition.USED, 2), 2 * 21)
	assert_eq(state.economy.sell_stock(BuildItem.Kind.WALL, BuildItem.Condition.USED, 4), 4 * 7)


func test_selling_more_than_there_is_does_nothing() -> void:
	var state := _hotel(0)
	state.inventory.add(BuildItem.Kind.WALL, BuildItem.Condition.NEW, 2)
	var balance: int = state.ledger.balance
	assert_eq(state.economy.sell_stock(BuildItem.Kind.WALL, BuildItem.Condition.NEW, 3), 0)
	assert_eq(state.economy.sell_stock(BuildItem.Kind.WALL, BuildItem.Condition.USED, 1), 0, "de otro estado")
	assert_eq(state.economy.sell_stock(BuildItem.Kind.WALL, BuildItem.Condition.NEW, 0), 0)
	assert_eq(state.inventory.count(BuildItem.Kind.WALL, BuildItem.Condition.NEW), 2)
	assert_eq(state.ledger.balance, balance)


func test_selling_from_stock_never_beats_the_purchase_price() -> void:
	var state := _hotel(0)
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 1)
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.USED, 1)
	var rules: EconomyRules = state.rules
	var total: int = state.economy.sell_stock(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 1) \
			+ state.economy.sell_stock(BuildItem.Kind.FLOOR, BuildItem.Condition.USED, 1)
	assert_true(total <= 2 * rules.floor_price)
	assert_eq(total, 10 + 9)
