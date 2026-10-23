extends TestCase
## Pruebas del pago de las estancias: anticipo al hacer el check-in, resto al terminar y
## devolución del anticipo si la estancia no se completa.

const NEW := BuildItem.Condition.NEW


func _rules() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 1000000
	return rules


func _hotel(bedrooms: int = 2) -> GameState:
	return HotelFixture.build(bedrooms, 1, false, _rules())


## Total acumulado de una categoría en todos los días.
func _total(state: GameState, category: Ledger.Category) -> int:
	var sum: int = 0
	for day: int in state.ledger.get_days():
		sum += state.ledger.get_day_total(day, category)
	return sum


func _stay_money(state: GameState) -> int:
	return _total(state, Ledger.Category.STAY_DEPOSIT) + _total(state, Ledger.Category.STAY_FINAL) \
			+ _total(state, Ledger.Category.DEPOSIT_REFUND)


func _stage(state: GameState, guest: Guest, stage: Guest.State) -> float:
	return HotelFixture.run_until(state, func() -> bool: return guest.state == stage, 600.0)


# --- Anticipo y liquidación --------------------------------------------------------------------

func test_half_is_paid_at_check_in() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	assert_eq(_total(state, Ledger.Category.STAY_DEPOSIT), 0, "al llegar todavía no ha pagado")
	_stage(state, guest, Guest.State.GOING_TO_ROOM)
	assert_eq(guest.stay_price, 40)
	assert_eq(guest.deposit_paid, 20)
	assert_eq(_total(state, Ledger.Category.STAY_DEPOSIT), 20, "el anticipo se cobra al asignarle dormitorio")
	assert_eq(_total(state, Ledger.Category.STAY_FINAL), 0)


func test_the_rest_is_paid_when_the_stay_is_completed() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	assert_eq(_total(state, Ledger.Category.STAY_FINAL), 0, "durante la estancia solo hay anticipo")
	_stage(state, guest, Guest.State.LEAVING)
	assert_true(guest.stay_completed)
	assert_eq(_total(state, Ledger.Category.STAY_FINAL), 20)
	assert_eq(_stay_money(state), 40, "en total, el precio entero")
	HotelFixture.run_until(state, func() -> bool: return state.guests.get_guest_count() == 0, 300.0)
	assert_eq(_stay_money(state), 40, "irse no cobra ni devuelve nada más")
	assert_eq(_total(state, Ledger.Category.DEPOSIT_REFUND), 0)


func test_an_odd_price_rounds_the_deposit_down_and_the_rest_makes_up_the_difference() -> void:
	var state := _hotel(1)
	state.room_types.get_type(&"bedroom").stay_price = 41
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.LEAVING)
	assert_eq(_total(state, Ledger.Category.STAY_DEPOSIT), 20)
	assert_eq(_total(state, Ledger.Category.STAY_FINAL), 21)
	assert_eq(_stay_money(state), 41)


func test_bigger_bedrooms_cost_more() -> void:
	var state := _hotel(0)
	var rect := Rect2i(Vector2i(14, 9), Vector2i(3, 3)) # 9 celdas: 3 por encima del mínimo de 6
	state.build.build_room(rect, 0)
	state.build.place_door(Edge.from_side(rect.position, Edge.Side.NORTH), 0)
	var room: Room = state.rooms.get_room_at(rect.position, 0)
	state.rooms.set_room_type(room.id, GuestRegistry.BEDROOM_TYPE)
	assert_eq(state.economy.stay_price_of(room), 40 + 3 * 5)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.LEAVING)
	assert_eq(guest.stay_price, 55)
	assert_eq(_stay_money(state), 55, "55 = 27 de anticipo + 28 al final")


func test_the_price_is_fixed_when_the_room_is_assigned() -> void:
	var state := _hotel(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.GOING_TO_ROOM)
	state.room_types.get_type(&"bedroom").stay_price = 100 # sube el precio con el huésped ya dentro
	_stage(state, guest, Guest.State.LEAVING)
	assert_eq(_stay_money(state), 40, "paga lo que se acordó")


func test_stay_price_of_unknown_or_untyped_rooms_is_zero() -> void:
	var state := _hotel(0)
	var rect := Rect2i(Vector2i(14, 9), Vector2i(3, 2))
	state.build.build_room(rect, 0)
	var room: Room = state.rooms.get_room_at(rect.position, 0)
	assert_eq(state.economy.stay_price_of(room), 0, "sin tipo")
	state.rooms.set_room_type(room.id, &"bathroom")
	assert_eq(state.economy.stay_price_of(room), 0, "un baño no se alquila")


# --- Devoluciones ----------------------------------------------------------------------------

func test_losing_the_room_on_the_way_refunds_the_deposit_and_a_new_room_charges_a_new_one() -> void:
	var state := _hotel(2)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.GOING_TO_ROOM)
	var lost_id: int = guest.room_id
	var lost_index: int = 0 if HotelFixture.bedroom(state, 0).id == lost_id else 1
	state.build.demolish_room(HotelFixture.bedroom_rect(lost_index), 0)
	HotelFixture.run(state, 0.3)
	assert_eq(_total(state, Ledger.Category.DEPOSIT_REFUND), -20, "se devuelve el anticipo del dormitorio perdido")
	assert_true(guest.room_id != 0 and guest.room_id != lost_id, "y le dan el otro")
	assert_eq(_total(state, Ledger.Category.STAY_DEPOSIT), 40, "con un anticipo nuevo")
	assert_eq(guest.deposit_paid, 20)
	assert_eq(_stay_money(state), 20, "a la vista solo hay un anticipo pagado")


func test_losing_the_room_while_staying_also_refunds() -> void:
	var state := _hotel(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	state.rooms.set_room_type(guest.room_id, &"bathroom") # su habitación deja de ser dormitorio
	HotelFixture.run(state, 0.3)
	assert_eq(guest.state, Guest.State.WAITING_ROOM)
	assert_eq(guest.deposit_paid, 0)
	assert_eq(_stay_money(state), 0, "anticipo cobrado y devuelto: ni un céntimo")


func test_a_guest_removed_while_staying_gets_his_deposit_back() -> void:
	var state := _hotel(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.STAYING)
	assert_eq(_stay_money(state), 20)
	state.agents.remove(guest.agent_id)
	assert_eq(_total(state, Ledger.Category.DEPOSIT_REFUND), -20)
	assert_eq(_stay_money(state), 0)


func test_a_guest_who_already_paid_in_full_is_not_refunded_when_leaving() -> void:
	var state := _hotel(1)
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.LEAVING)
	state.agents.remove(guest.agent_id) # desaparece de camino a la salida
	assert_eq(_total(state, Ledger.Category.DEPOSIT_REFUND), 0)
	assert_eq(_stay_money(state), 40)


func test_a_guest_who_gives_up_waiting_never_paid_anything() -> void:
	var state := _hotel(0) # sin dormitorios
	var guest: Guest = state.guests.arrive(0)
	HotelFixture.run(state, GuestRegistry.PATIENCE_MINUTES + 15.0)
	assert_eq(state.guests.get_guest(guest.id), null, "se fue enfadado")
	assert_eq(_stay_money(state), 0)
	assert_eq(_total(state, Ledger.Category.STAY_DEPOSIT), 0)
	assert_eq(_total(state, Ledger.Category.DEPOSIT_REFUND), 0)


func test_without_charges_guests_do_not_pay() -> void:
	var state := HotelFixture.build(1) # reglas sin costes
	var guest: Guest = state.guests.arrive(0)
	_stage(state, guest, Guest.State.LEAVING)
	assert_eq(state.ledger.get_recent(10).size(), 0)
	assert_eq(state.ledger.balance, 0)
	assert_eq(guest.deposit_paid, 0)


# --- Conservación del dinero en una simulación larga ------------------------------------------------

func test_every_euro_paid_is_accounted_for_in_a_long_busy_simulation() -> void:
	var state := HotelFixture.build(3, 7, true, _rules())
	for step in range(12000): # 1.200 minutos
		state.tick(0.1)
		if step % 3000 == 2999:
			_assert_stay_money_matches(state, step)
	assert_true(state.guests.total_left_happy > 3, "terminaron estancias (%d)" % state.guests.total_left_happy)
	_assert_stay_money_matches(state, 12000)


## El dinero de estancias (anticipos + restos - devoluciones) debe ser exactamente: 40 por cada
## estancia completada, más lo que ya han pagado los huéspedes que siguen aquí.
func _assert_stay_money_matches(state: GameState, step: int) -> void:
	var expected: int = 40 * state.guests.total_left_happy
	for guest: Guest in state.guests.get_guests():
		if guest.stay_completed:
			expected += guest.stay_price
		else:
			expected += guest.deposit_paid
	assert_eq(_stay_money(state), expected, "paso %d: el dinero de estancias no cuadra" % step)
