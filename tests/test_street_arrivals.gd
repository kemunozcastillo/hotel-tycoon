extends TestCase
## Pruebas de las llegadas desde la calle: los huéspedes aparecen en la acera, entran al hotel por
## una puerta al exterior, y vuelven a la calle al irse.

const RECEPTION: Rect2i = Rect2i(Vector2i(8, 22), Vector2i(4, 3))
const BEDROOM: Rect2i = Rect2i(Vector2i(14, 22), Vector2i(3, 2))


func _rules() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 100000
	return rules


## Un hotel sobre el césped: recepción y un dormitorio con su puerta hacia el sur (la calle).
## Con `with_doors` false las puertas se quedan sin poner y el edificio queda cerrado.
func _hotel(with_doors: bool = true, seed_value: int = 3) -> GameState:
	var state := GameState.new_hotel_game(_rules())
	state.guests.set_seed(seed_value)
	state.spawner.enabled = false
	state.build.build_room(RECEPTION, 0)
	state.build.build_room(BEDROOM, 0)
	if with_doors:
		state.build.place_door(Edge.from_side(Vector2i(9, RECEPTION.end.y - 1), Edge.Side.SOUTH), 0)
		state.build.place_door(Edge.from_side(Vector2i(15, BEDROOM.end.y - 1), Edge.Side.SOUTH), 0)
	state.rooms.set_room_type(state.rooms.get_room_at(RECEPTION.position, 0).id, GuestRegistry.RECEPTION_TYPE)
	state.rooms.set_room_type(state.rooms.get_room_at(BEDROOM.position, 0).id, GuestRegistry.BEDROOM_TYPE)
	return state


func _arrivals(state: GameState) -> Array[Vector2i]:
	return TerrainGenerator.arrival_cells(state.grid.size)


func test_a_guest_appears_on_the_sidewalk() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	assert_true(guest != null)
	var cell: Vector2i = state.agents.get_agent(guest.agent_id).get_cell()
	assert_true(_arrivals(state).has(cell), "en un extremo de la acera: %s" % str(cell))
	assert_eq(state.grid.get_terrain_type(cell, 0).id, TerrainGenerator.SIDEWALK)
	assert_eq(guest.entrance_cell, cell)


func test_both_ends_of_the_sidewalk_are_used() -> void:
	var state := _hotel(true, 7)
	var seen: Dictionary = {}
	for i in range(12):
		var guest: Guest = state.guests.arrive(0)
		if guest != null:
			seen[guest.entrance_cell] = true
			state.guests.get_guest(guest.id)
			state.agents.remove(guest.agent_id)
			state.guests.tick(0.0)
	assert_eq(seen.size(), 2, "llegan por los dos lados")


func test_the_whole_stay_happens_between_the_street_and_the_hotel() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	var street: int = state.grid.terrain.index_of(TerrainGenerator.STREET)
	var stepped_on_street: bool = false
	var was_staying: bool = false
	for i in range(8000):
		state.tick(0.1)
		var agent: Agent = state.agents.get_agent(guest.agent_id)
		if agent == null:
			break
		if state.grid.get_terrain_index(agent.get_cell(), 0) == street:
			stepped_on_street = true
		if guest.state == Guest.State.STAYING:
			was_staying = true
	assert_true(was_staying, "llegó a alojarse")
	assert_false(stepped_on_street, "nunca pisó la calle: va por la acera y el césped")
	assert_eq(state.guests.total_left_happy, 1, "y se fue contento")
	assert_eq(state.guests.get_guest_count(), 0, "desapareció al llegar a la calle")
	assert_eq(state.agents.get_agents().size(), 0)


func test_a_closed_building_has_no_operational_reception() -> void:
	var state := _hotel(false)
	assert_false(state.guests.has_operational_reception(0), "sin ninguna puerta no es operativa")
	assert_eq(state.guests.arrive(0), null)


## Una recepción operativa (tiene una puerta) pero encerrada en el edificio: la única puerta da a
## otra habitación que no tiene salida.
func _walled_in_reception() -> GameState:
	var state := _hotel(false)
	state.build.build_room(Rect2i(Vector2i(12, 22), Vector2i(2, 3)), 0)
	state.build.place_door(Edge.from_side(Vector2i(11, 23), Edge.Side.EAST), 0)
	return state


func test_a_reception_with_no_way_out_is_not_reachable_from_the_street() -> void:
	var state := _walled_in_reception()
	assert_true(state.guests.has_operational_reception(0), "la recepción existe y es operativa...")
	assert_false(state.guests.is_reception_reachable(0), "...pero no se llega a ella desde la calle")
	assert_eq(state.guests.arrive(0), null)
	assert_true(GuestTexts.hotel_summary(0, 0, 0, 1, true, true, false).contains("puerta al exterior"))


func test_the_status_label_text_reacts_to_the_missing_outside_door() -> void:
	var state := _walled_in_reception()
	var label := HotelStatusLabel.new()
	label.setup(state, 0)
	assert_true(label.text.contains("puerta al exterior"), label.text)
	state.build.place_door(Edge.from_side(Vector2i(12, 24), Edge.Side.SOUTH), 0) # la sala de al lado sale a la calle
	label._refresh()
	assert_true(label.text.begins_with("Huéspedes"), label.text)
	label.free()


func test_building_the_outside_door_makes_the_reception_reachable_again() -> void:
	var state := _hotel(false)
	assert_false(state.guests.is_reception_reachable(0))
	state.build.place_door(Edge.from_side(Vector2i(9, RECEPTION.end.y - 1), Edge.Side.SOUTH), 0)
	assert_true(state.guests.is_reception_reachable(0), "se recalcula al cambiar el mapa")
	state.build.remove_door(Edge.from_side(Vector2i(9, RECEPTION.end.y - 1), Edge.Side.SOUTH), 0)
	assert_false(state.guests.is_reception_reachable(0))


func test_changing_the_room_type_updates_reachability() -> void:
	var state := _hotel()
	assert_true(state.guests.is_reception_reachable(0))
	state.rooms.set_room_type(state.rooms.get_room_at(RECEPTION.position, 0).id, &"")
	assert_false(state.guests.is_reception_reachable(0), "sin tipo ya no es una recepción")


func test_the_bedroom_is_reached_through_its_own_outside_door() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	var minutes: float = HotelFixture.run_until(state, func() -> bool: return guest.state == Guest.State.STAYING, 600.0)
	assert_true(minutes >= 0.0, "llegó al dormitorio")
	assert_eq(state.guests.occupancy.room_of(guest.id), state.rooms.get_room_at(BEDROOM.position, 0).id)


func test_leaving_walks_back_to_the_street_and_vanishes_there() -> void:
	var state := _hotel()
	var guest: Guest = state.guests.arrive(0)
	var entrance: Vector2i = guest.entrance_cell
	HotelFixture.run_until(state, func() -> bool: return guest.state == Guest.State.LEAVING, 1000.0)
	assert_eq(guest.state, Guest.State.LEAVING)
	var agent: Agent = state.agents.get_agent(guest.agent_id)
	assert_eq(guest.target_cell, entrance, "se va por donde llegó")
	assert_true(agent.get_cell() != entrance, "todavía está dentro")
	HotelFixture.run_until(state, func() -> bool: return state.guests.get_guest_count() == 0, 400.0)
	assert_eq(state.guests.get_guest_count(), 0)
