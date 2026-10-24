extends TestCase
## Pruebas de los textos de huéspedes y del resumen del hotel.


func _guest(state: Guest.State) -> Guest:
	var guest := Guest.new(7, 70, 0)
	guest.state = state
	return guest


func test_state_text_for_every_state() -> void:
	var guest: Guest = _guest(Guest.State.ARRIVING)
	assert_eq(GuestTexts.state_text(guest), "Llega a la recepción")

	guest = _guest(Guest.State.QUEUED)
	guest.waited_minutes = 4.4
	assert_eq(GuestTexts.state_text(guest), "Espera su turno de check-in (lleva 4 min)")

	guest = _guest(Guest.State.CHECKING_IN)
	guest.timer_minutes = 1.2
	assert_eq(GuestTexts.state_text(guest), "Hace el check-in (quedan 2 min)")

	guest = _guest(Guest.State.WAITING_ROOM)
	guest.waited_minutes = 25.0
	assert_eq(GuestTexts.state_text(guest), "Sin dormitorio libre: espera (paciencia 25 de 60 min)")

	guest = _guest(Guest.State.GOING_TO_ROOM)
	guest.room_id = 12
	assert_eq(GuestTexts.state_text(guest), "Va a su dormitorio (habitación 12)")

	guest = _guest(Guest.State.STAYING)
	guest.room_id = 12
	guest.timer_minutes = 150.0
	assert_eq(GuestTexts.state_text(guest), "Alojado en la habitación 12 (quedan 2 h 30 min)")
	guest.timer_minutes = 45.2
	assert_eq(GuestTexts.state_text(guest), "Alojado en la habitación 12 (quedan 46 min)")

	guest = _guest(Guest.State.LEAVING)
	assert_eq(GuestTexts.state_text(guest), "Se marcha")
	guest.left_unhappy = true
	assert_eq(GuestTexts.state_text(guest), "Se marcha enfadado")


func test_describe_includes_the_guest_id() -> void:
	var guest: Guest = _guest(Guest.State.ARRIVING)
	assert_eq(GuestTexts.describe(guest), "Huésped 7\nLlega a la recepción")


func test_agent_panel_text_uses_guest_text_when_the_agent_is_a_guest() -> void:
	var agent := Agent.new(70, 0, Vector2(1.5, 1.5))
	var plain: String = AgentInfoPanel.describe(agent)
	assert_true(plain.begins_with("Agente 70"), plain)
	var guest: Guest = _guest(Guest.State.QUEUED)
	var as_guest: String = AgentInfoPanel.describe(agent, guest)
	assert_true(as_guest.begins_with("Huésped 7"), as_guest)
	assert_true(as_guest.contains("Espera su turno"))
	assert_false(as_guest.contains("Agente"))


func test_hotel_summary_asks_for_what_is_missing_first() -> void:
	assert_true(GuestTexts.hotel_summary(0, 0, 0, 0, false, false).contains("punto de llegada"), "sin punto de llegada")
	assert_true(GuestTexts.hotel_summary(0, 0, 0, 0, true, false).contains("recepción"), "sin recepción")
	assert_true(GuestTexts.hotel_summary(0, 0, 0, 0, true, true, false).contains("puerta al exterior"), "recepción inalcanzable")
	assert_eq(GuestTexts.hotel_summary(5, 2, 1, 4, true, true),
			"Huéspedes 5  ·  En espera 2  ·  Dormitorios libres 1/4")


func test_hotel_summary_matches_a_real_state() -> void:
	var state := HotelFixture.build(3)
	var bedrooms: Vector2i = state.guests.count_bedrooms(0)
	var text: String = GuestTexts.hotel_summary(
			state.guests.get_guest_count(), state.guests.get_waiting_count(0), bedrooms.x, bedrooms.y,
			not state.entrances.get_valid(0).is_empty(), state.guests.has_operational_reception(0))
	assert_eq(text, "Huéspedes 0  ·  En espera 0  ·  Dormitorios libres 3/3")
	state.entrances.remove(HotelFixture.ENTRANCE, 0)
	assert_false(state.entrances.get_valid(0).size() > 0)
	state.rooms.set_room_type(HotelFixture.reception(state).id, &"")
	assert_false(state.guests.has_operational_reception(0))


func test_room_occupancy_line() -> void:
	assert_eq(RoomTexts.occupancy_line(0), "Libre")
	assert_eq(RoomTexts.occupancy_line(4), "Ocupado por el huésped 4")
