extends SceneTree
## Verificación de entrada con ventana real (no es un test headless; necesita GPU):
##   godot --path . --script res://tests/interaction_check.gd -- <captura.png>
## Inyecta eventos de ratón/teclado en la escena principal y comprueba cámara, cursor y
## construcción de extremo a extremo. Imprime OK / FALLO por cada comprobación.

var _main: Node
var _failures: int = 0


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_main = load("res://view/main.tscn").instantiate()
	root.add_child(_main)
	await _frames(2)

	await _check_hover()
	await _check_camera()
	await _check_build()
	await _check_shapes()
	await _check_types()
	await _check_agents()
	await _check_clock()

	# Capturas del resaltado: modo celda (args[0]) y modo arista (args[1]).
	_main.cursor.edge_mode = false
	await _move_mouse_to_grid(Vector2(14.5, 12.5))
	_save(args, 1)
	_main.cursor.edge_mode = true
	await _move_mouse_to_grid(Vector2(14.5, 12.08))
	_save(args, 2)
	print("")
	print("%d fallos" % _failures)
	quit(1 if _failures > 0 else 0)


# --- Comprobaciones ---------------------------------------------------------------------

func _check_hover() -> void:
	print("== hover")
	var cursor: CellCursor = _main.cursor
	# Centro de una celda cualquiera.
	var target := Vector2i(13, 11)
	await _move_mouse_to_grid(Vector2(target) + Vector2(0.5, 0.5))
	_check(cursor.is_hovering and cursor.hover_cell == target, "celda bajo el cursor = %s (obtenida %s)" % [str(target), str(cursor.hover_cell)])

	# Cerca de la esquina de otra celda: debe resolver la celda correcta y su arista más cercana.
	await _move_mouse_to_grid(Vector2(13.5, 11.08))
	_check(cursor.hover_cell == Vector2i(13, 11), "celda con el cursor cerca del borde norte")
	_check(cursor.hover_edge.is_equal(Edge.new(Vector2i(13, 11), Edge.Axis.X)), "arista norte de (13,11)")

	await _move_mouse_to_grid(Vector2(13.93, 11.5))
	_check(cursor.hover_edge.is_equal(Edge.new(Vector2i(14, 11), Edge.Axis.Y)), "arista este de (13,11) = oeste de (14,11)")

	# Fuera del mapa.
	await _move_mouse_to_grid(Vector2(-3.5, 4.5))
	_check(not cursor.is_hovering, "fuera del mapa no hay celda señalada")


func _check_camera() -> void:
	print("== camara")
	var camera: IsoCamera = _main.camera
	var vp: Vector2 = root.get_visible_rect().size

	# Zoom con la rueda: el punto del mundo bajo el cursor no se mueve.
	var cursor_pos := Vector2(900, 200)
	await _send_mouse_motion(cursor_pos)
	var world_before: Vector2 = camera.screen_to_world(cursor_pos, vp)
	var zoom_before: float = camera.zoom.x
	await _send_wheel(cursor_pos, MOUSE_BUTTON_WHEEL_UP)
	await _send_wheel(cursor_pos, MOUSE_BUTTON_WHEEL_UP)
	var world_after: Vector2 = camera.screen_to_world(cursor_pos, vp)
	_check(camera.zoom.x > zoom_before, "la rueda arriba aumenta el zoom (%.2f -> %.2f)" % [zoom_before, camera.zoom.x])
	_check(world_before.distance_to(world_after) < 0.5, "el punto bajo el cursor se mantiene al hacer zoom")

	# Arrastre con el botón central.
	var position_before: Vector2 = camera.position
	await _send_mouse_button(MOUSE_BUTTON_MIDDLE, true, Vector2(600, 400))
	await _send_mouse_motion(Vector2(500, 400), Vector2(-100, 0))
	await _send_mouse_button(MOUSE_BUTTON_MIDDLE, false, Vector2(500, 400))
	_check(camera.position.x > position_before.x, "arrastrar a la izquierda mueve la cámara a la derecha")

	# Teclado: mantener D desplaza la cámara.
	position_before = camera.position
	var key := InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = true
	Input.parse_input_event(key)
	await _frames(10)
	key = InputEventKey.new()
	key.physical_keycode = KEY_D
	key.pressed = false
	Input.parse_input_event(key)
	await _frames(1)
	_check(camera.position.x > position_before.x, "mantener D mueve la cámara a la derecha")

	# Con la cámara ya con zoom y desplazada, la conversión pantalla -> celda debe seguir exacta.
	for target: Vector2i in [Vector2i(3, 20), Vector2i(25, 5), Vector2i(16, 16)]:
		await _move_mouse_to_grid(Vector2(target) + Vector2(0.5, 0.5))
		var cursor: CellCursor = _main.cursor
		_check(cursor.is_hovering and cursor.hover_cell == target, "con zoom %.2f: celda %s (obtenida %s)" % [camera.zoom.x, str(target), str(cursor.hover_cell)])

	# Devolver zoom y posición a un estado cómodo para capturas.
	camera.zoom = Vector2.ONE
	camera.position = IsoProjection.grid_to_world(Vector2(_main.state.grid.size) * 0.5)
	await _frames(2)


func _check_build() -> void:
	print("== construccion")
	var state: GameState = _main.state
	var controller: BuildController = _main.build_controller
	var vp: Vector2 = root.get_visible_rect().size

	# Sin herramienta, un clic no construye.
	await _click_grid(Vector2(10.5, 10.5), MOUSE_BUTTON_LEFT)
	_check(state.grid.get_floor_type(Vector2i(10, 10), 0) == CellTypes.FloorType.NONE, "sin herramienta el clic no construye")

	# Suelo: clic y arrastre.
	controller.set_tool(BuildController.Tool.FLOOR)
	await _click_grid(Vector2(10.5, 10.5), MOUSE_BUTTON_LEFT)
	_check(state.grid.get_floor_type(Vector2i(10, 10), 0) == CellTypes.FloorType.BASIC, "clic izquierdo coloca suelo")
	await _drag_grid([Vector2(10.5, 11.5), Vector2(11.5, 11.5), Vector2(12.5, 11.5)], MOUSE_BUTTON_LEFT)
	var painted: bool = true
	for x in range(10, 13):
		painted = painted and state.grid.get_floor_type(Vector2i(x, 11), 0) == CellTypes.FloorType.BASIC
	_check(painted, "arrastrar pinta tres celdas de suelo seguidas")
	_check(state.grid.get_floor_type(Vector2i(13, 11), 0) == CellTypes.FloorType.NONE, "no pinta de más")
	await _click_grid(Vector2(11.5, 11.5), MOUSE_BUTTON_RIGHT)
	_check(state.grid.get_floor_type(Vector2i(11, 11), 0) == CellTypes.FloorType.NONE, "clic derecho quita suelo")
	_check(state.grid.get_floor_type(Vector2i(10, 11), 0) == CellTypes.FloorType.BASIC, "y deja el resto intacto")

	# Esc deselecciona.
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	await _frames(2)
	_check(controller.current_tool == BuildController.Tool.NONE, "Esc deselecciona la herramienta")

	# Un clic sobre la barra de herramientas no construye (la interfaz lo absorbe).
	controller.set_tool(BuildController.Tool.FLOOR)
	var camera: IsoCamera = _main.camera
	var over_toolbar := Vector2(40, 20)
	camera.position = IsoProjection.grid_to_world(Vector2(5.5, 5.5)) - (over_toolbar - vp * 0.5) / camera.zoom.x
	await _send_mouse_motion(over_toolbar)
	_check(not _main.cursor.is_hovering, "sobre la barra no se resalta ninguna celda")
	await _send_mouse_button(MOUSE_BUTTON_LEFT, true, over_toolbar)
	await _send_mouse_button(MOUSE_BUTTON_LEFT, false, over_toolbar)
	_check(state.grid.get_floor_type(Vector2i(5, 5), 0) == CellTypes.FloorType.NONE, "un clic sobre la barra no construye debajo")
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	await _frames(3)

	# Paredes: un baño de 2x2 con ocho clics sobre las aristas del perímetro.
	controller.set_tool(BuildController.Tool.WALL)
	var origin := Vector2i(16, 10)
	var clicks: Array[Vector2] = []
	for i in range(2):
		clicks.append(Vector2(origin) + Vector2(i + 0.5, 0.03)) # norte
		clicks.append(Vector2(origin) + Vector2(i + 0.5, 2 - 0.03)) # sur
		clicks.append(Vector2(origin) + Vector2(0.03, i + 0.5)) # oeste
		clicks.append(Vector2(origin) + Vector2(2 - 0.03, i + 0.5)) # este
	for point: Vector2 in clicks:
		await _click_grid(point, MOUSE_BUTTON_LEFT)
	var expected: Array[Edge] = []
	for i in range(2):
		expected.append(Edge.from_side(origin + Vector2i(i, 0), Edge.Side.NORTH))
		expected.append(Edge.from_side(origin + Vector2i(i, 1), Edge.Side.SOUTH))
		expected.append(Edge.from_side(origin + Vector2i(0, i), Edge.Side.WEST))
		expected.append(Edge.from_side(origin + Vector2i(1, i), Edge.Side.EAST))
	var all_present: bool = true
	for edge: Edge in expected:
		all_present = all_present and state.grid.has_wall(edge, 0)
	_check(all_present, "ocho clics colocan las ocho aristas del perímetro del baño 2x2")
	_check(GridTestHelpers.count_walls(state.grid) == 8, "hay exactamente 8 paredes en el mapa (hay %d)" % GridTestHelpers.count_walls(state.grid))
	_check(GridTestHelpers.flood_fill(state.grid, origin).size() == 4, "el baño encierra exactamente 4 celdas")

	# Arrastrar pinta una línea de paredes; clic derecho quita una (la puerta).
	await _drag_grid([Vector2(20.5, 10.03), Vector2(21.5, 10.03), Vector2(22.5, 10.03)], MOUSE_BUTTON_LEFT)
	_check(GridTestHelpers.count_walls(state.grid) == 11, "arrastrar añade tres paredes (hay %d)" % GridTestHelpers.count_walls(state.grid))
	await _click_grid(Vector2(16.5, 10.03), MOUSE_BUTTON_RIGHT)
	_check(GridTestHelpers.count_walls(state.grid) == 10, "clic derecho quita una pared (la puerta)")
	_check(GridTestHelpers.flood_fill(state.grid, origin).size() > 4, "con la puerta abierta la habitación deja de estar cerrada")

	# Capturas del resultado. Se deja la herramienta de paredes para ver la arista resaltada.
	await _move_mouse_to_grid(Vector2(18.5, 12.03))
	_save_args(0)
	controller.set_tool(BuildController.Tool.NONE)


func _check_shapes() -> void:
	print("== formas")
	var state: GameState = _main.state
	var controller: BuildController = _main.build_controller
	var preview: ShapePreview = _main.shape_preview
	var walls_before: int = GridTestHelpers.count_walls(state.grid)

	# Suelo con Mayús: rectángulo relleno, con vista previa durante el arrastre.
	controller.set_tool(BuildController.Tool.FLOOR)
	await _begin_drag_grid([_center(Vector2i(4, 20)), _center(Vector2i(6, 21))], MOUSE_BUTTON_LEFT, true)
	_check(preview.is_active() and preview.get_rect() == Rect2i(Vector2i(4, 20), Vector2i(3, 2)), "la vista previa muestra el rectángulo 3x2 mientras se arrastra")
	_check(state.grid.get_floor_type(Vector2i(4, 20), 0) == CellTypes.FloorType.NONE, "no se construye hasta soltar")
	await _end_drag_grid(_center(Vector2i(6, 21)), MOUSE_BUTTON_LEFT, true)
	var filled: int = 0
	for cell: Vector2i in GridShapes.rect_cells(Rect2i(Vector2i(4, 20), Vector2i(3, 2))):
		if state.grid.get_floor_type(cell, 0) == CellTypes.FloorType.BASIC:
			filled += 1
	_check(filled == 6, "Mayús+arrastrar rellena 6 celdas de suelo (%d)" % filled)
	_check(not preview.is_active(), "la vista previa desaparece al soltar")
	_check(state.grid.get_floor_type(Vector2i(7, 20), 0) == CellTypes.FloorType.NONE, "no se sale del rectángulo")

	# Clic derecho con Mayús quita el rectángulo.
	await _drag_grid([_center(Vector2i(4, 20)), _center(Vector2i(6, 21))], MOUSE_BUTTON_RIGHT, true)
	_check(state.grid.get_floor_type(Vector2i(5, 20), 0) == CellTypes.FloorType.NONE, "Mayús+clic derecho quita el rectángulo de suelo")

	# Pared con Mayús: perímetro. El arrastre empieza en la esquina contraria (orden inverso).
	controller.set_tool(BuildController.Tool.WALL)
	await _drag_grid([_center(Vector2i(9, 21)), _center(Vector2i(8, 20))], MOUSE_BUTTON_LEFT, true)
	_check(GridTestHelpers.count_walls(state.grid) == walls_before + 8, "Mayús+arrastrar con Pared dibuja el perímetro (8 paredes)")
	_check(GridTestHelpers.flood_fill(state.grid, Vector2i(8, 20)).size() == 4, "el perímetro 2x2 encierra 4 celdas")
	await _drag_grid([_center(Vector2i(9, 21)), _center(Vector2i(8, 20))], MOUSE_BUTTON_RIGHT, true)
	_check(GridTestHelpers.count_walls(state.grid) == walls_before, "Mayús+clic derecho quita el perímetro")

	# Herramienta Habitación: suelo y paredes de un golpe, y vista previa a mitad de arrastre.
	# La cámara se centra en la zona para que las capturas muestren el resultado.
	var camera: IsoCamera = _main.camera
	camera.position = IsoProjection.grid_to_world(Vector2(8, 24))
	await _frames(3)
	controller.set_tool(BuildController.Tool.ROOM)
	await _begin_drag_grid([_center(Vector2i(4, 24)), _center(Vector2i(6, 26))], MOUSE_BUTTON_LEFT)
	_check(preview.is_active() and preview.get_rect().size == Vector2i(3, 3), "la herramienta Habitación previsualiza 3x3 sin necesitar Mayús")
	_save_args(3)
	await _end_drag_grid(_center(Vector2i(6, 26)), MOUSE_BUTTON_LEFT)
	_check(GridTestHelpers.count_walls(state.grid) == walls_before + 12, "la habitación 3x3 añade 12 paredes")
	_check(GridTestHelpers.flood_fill(state.grid, Vector2i(5, 25)).size() == 9, "y encierra 9 celdas")
	var floors_ok: bool = true
	for cell: Vector2i in GridShapes.rect_cells(Rect2i(Vector2i(4, 24), Vector2i(3, 3))):
		floors_ok = floors_ok and state.grid.get_floor_type(cell, 0) == CellTypes.FloorType.BASIC
	_check(floors_ok, "con suelo en todas sus celdas")

	# Esc a mitad de un arrastre cancela sin construir.
	await _begin_drag_grid([_center(Vector2i(12, 24)), _center(Vector2i(14, 26))], MOUSE_BUTTON_LEFT)
	await _press_key(KEY_ESCAPE)
	_check(not preview.is_active(), "Esc cancela la vista previa")
	await _end_drag_grid(_center(Vector2i(14, 26)), MOUSE_BUTTON_LEFT)
	_check(state.grid.get_floor_type(Vector2i(13, 25), 0) == CellTypes.FloorType.NONE, "el arrastre cancelado no construye")
	_check(controller.current_tool == BuildController.Tool.ROOM, "el primer Esc solo cancela el arrastre, la herramienta sigue")

	# El registro detecta la habitación recién construida y la vista la muestra.
	var overlay: RoomOverlay = _main.room_overlay
	var built_room: Room = state.rooms.get_room_at(Vector2i(5, 25), 0)
	_check(built_room != null and built_room.get_area() == 9 and built_room.is_rectangular(), "se detecta la habitación 3x3 recién construida")
	_check(overlay.get_room_count() == _count_rooms(state) and overlay.get_room_count() >= 1, "la vista de habitaciones refleja el registro (%d)" % overlay.get_room_count())

	# Puertas: la herramienta Puerta sustituye una pared por una puerta transitable.
	controller.set_tool(BuildController.Tool.DOOR)
	var door_edge: Edge = Edge.from_side(Vector2i(5, 26), Edge.Side.SOUTH)
	await _click_grid(Vector2(5.5, 26.97), MOUSE_BUTTON_LEFT)
	_check(state.grid.get_edge_type(door_edge, 0) == CellTypes.EdgeType.DOOR, "clic con Puerta sobre una pared coloca una puerta")
	_check(GridTestHelpers.count_walls(state.grid) == walls_before + 11, "la puerta sustituye a una de las 12 paredes")
	_check(GridTestHelpers.flood_fill(state.grid, Vector2i(5, 25)).size() > 9, "por la puerta se puede salir de la habitación")
	_check(state.grid.is_room_boundary(Vector2i(5, 26), Vector2i(5, 27), 0), "la puerta sigue separando la habitación")
	await _move_mouse_to_grid(Vector2(5.5, 26.97)) # para que la captura muestre la arista de puerta resaltada
	_save_args(4)

	# Reconstruir la habitación (herramienta Habitación) no tapa la puerta.
	controller.set_tool(BuildController.Tool.ROOM)
	await _drag_grid([_center(Vector2i(4, 24)), _center(Vector2i(6, 26))], MOUSE_BUTTON_LEFT)
	_check(state.grid.has_door(door_edge, 0), "reconstruir la habitación respeta la puerta")

	# Clic derecho con Puerta quita la puerta; con Pared no la toca.
	controller.set_tool(BuildController.Tool.WALL)
	await _click_grid(Vector2(5.5, 26.97), MOUSE_BUTTON_RIGHT)
	_check(state.grid.has_door(door_edge, 0), "clic derecho con Pared no quita puertas")
	controller.set_tool(BuildController.Tool.DOOR)
	await _click_grid(Vector2(5.5, 26.97), MOUSE_BUTTON_RIGHT)
	_check(state.grid.get_edge_type(door_edge, 0) == CellTypes.EdgeType.NONE, "clic derecho con Puerta la quita")

	# Una puerta puesta de nuevo se derriba junto con la habitación.
	await _click_grid(Vector2(5.5, 26.97), MOUSE_BUTTON_LEFT)
	_check(state.grid.has_door(door_edge, 0), "(control) puerta colocada otra vez")
	state.rooms.refresh()
	_check(state.rooms.get_room_at(Vector2i(5, 25), 0).doors.size() == 1, "la habitación registra su puerta")
	controller.set_tool(BuildController.Tool.ROOM)

	# Derribar la habitación con clic derecho.
	await _drag_grid([_center(Vector2i(4, 24)), _center(Vector2i(6, 26))], MOUSE_BUTTON_RIGHT)
	_check(GridTestHelpers.count_walls(state.grid) == walls_before, "clic derecho con Habitación derriba paredes")
	_check(GridTestHelpers.count_edges(state.grid, CellTypes.EdgeType.DOOR) == 0, "y puertas")
	state.rooms.refresh()
	_check(state.rooms.get_room_at(Vector2i(5, 25), 0) == null, "la habitación derribada desaparece del registro")
	_check(state.grid.get_floor_type(Vector2i(5, 25), 0) == CellTypes.FloorType.NONE, "y suelo")
	controller.set_tool(BuildController.Tool.NONE)
	camera.position = IsoProjection.grid_to_world(Vector2(_main.state.grid.size) * 0.5)
	await _frames(3)


func _count_rooms(state: GameState) -> int:
	return state.rooms.get_rooms(0).size()


func _check_types() -> void:
	print("== tipos de habitacion")
	var state: GameState = _main.state
	var controller: BuildController = _main.build_controller
	var toolbar: BuildToolbar = _main.toolbar
	var panel: RoomInfoPanel = _main.room_info_panel
	var camera: IsoCamera = _main.camera
	camera.position = IsoProjection.grid_to_world(Vector2(23, 21))
	await _frames(3)

	# Botones de la barra con clics reales: herramienta, des-seleccionar y cambiar de herramienta.
	var floor_button: Button = toolbar.get_tool_button(BuildController.Tool.FLOOR)
	await _click_button(floor_button)
	_check(controller.current_tool == BuildController.Tool.FLOOR and floor_button.button_pressed, "el botón Suelo selecciona la herramienta")
	await _click_button(floor_button)
	_check(controller.current_tool == BuildController.Tool.NONE and not floor_button.button_pressed, "pulsarlo otra vez la deselecciona")
	await _click_button(floor_button)
	# Regresión: cambiar directamente de una herramienta a otra no debe perder la selección.
	var wall_button: Button = toolbar.get_tool_button(BuildController.Tool.WALL)
	await _click_button(wall_button)
	_check(controller.current_tool == BuildController.Tool.WALL and wall_button.button_pressed and not floor_button.button_pressed, "pasar de Suelo a Pared con un clic")
	await _click_button(floor_button)
	_check(controller.current_tool == BuildController.Tool.FLOOR and floor_button.button_pressed, "y de Pared a Suelo")
	var bathroom_button: Button = toolbar.get_type_button(&"bathroom")
	await _click_button(bathroom_button)
	_check(controller.current_tool == BuildController.Tool.TYPE and controller.selected_type_id == &"bathroom", "el botón Baño activa la herramienta Tipo")
	_check(bathroom_button.button_pressed and not floor_button.button_pressed, "y desmarca el botón anterior")

	# Un baño de 2x2 y un dormitorio de 2x3 construidos con la herramienta Habitación.
	controller.set_tool(BuildController.Tool.ROOM)
	await _drag_grid([_center(Vector2i(20, 20)), _center(Vector2i(21, 21))], MOUSE_BUTTON_LEFT)
	await _drag_grid([_center(Vector2i(24, 20)), _center(Vector2i(25, 22))], MOUSE_BUTTON_LEFT)
	state.build.place_door(Edge.from_side(Vector2i(24, 22), Edge.Side.SOUTH), 0)
	await _frames(2)
	_check(state.rooms.get_room_at(Vector2i(20, 20), 0) != null and state.rooms.get_room_at(Vector2i(24, 20), 0) != null, "se detectan el baño y el dormitorio")

	# Asignar el tipo Baño haciendo clic dentro de la habitación.
	await _click_button(bathroom_button)
	await _click_grid(_center(Vector2i(20, 20)), MOUSE_BUTTON_LEFT)
	var bathroom: Room = state.rooms.get_room_at(Vector2i(20, 20), 0)
	_check(bathroom.type_id == &"bathroom", "clic con la herramienta Tipo asigna Baño")
	await _move_mouse_to_grid(_center(Vector2i(21, 20)))
	_check(panel.visible, "el panel aparece sobre una habitación")
	var text: String = panel.get_plain_text()
	_check(text.contains("Baño") and text.contains("2×2") and text.contains("Puertas: mínimo 1 (tiene 0)"), "el panel describe el baño y sus requisitos")
	_check(text.contains("No operativa"), "sin puerta el baño no es operativa")
	_check(not state.rooms.get_status(bathroom).is_operational(), "el estado del registro coincide")
	_save_args(5)

	# Con una puerta pasa a operativa; el tipo se conserva.
	state.build.place_door(Edge.from_side(Vector2i(20, 20), Edge.Side.NORTH), 0)
	await _frames(3)
	text = panel.get_plain_text()
	_check(text.contains("Operativa") and not text.contains("No operativa"), "con puerta el panel dice Operativa")
	_check(state.rooms.get_room_at(Vector2i(20, 20), 0).type_id == &"bathroom", "y el tipo se conserva")

	# Dormitorio: bien asignado al dormitorio, y mal asignado al baño (2x2 es pequeño).
	var bedroom_button: Button = toolbar.get_type_button(&"bedroom")
	await _click_button(bedroom_button)
	_check(controller.selected_type_id == &"bedroom" and bedroom_button.button_pressed and not bathroom_button.button_pressed, "cambiar de tipo en la paleta")
	await _click_grid(_center(Vector2i(24, 20)), MOUSE_BUTTON_LEFT)
	_check(state.rooms.get_room_at(Vector2i(24, 20), 0).type_id == &"bedroom", "clic asigna Dormitorio")
	_check(state.rooms.get_status(state.rooms.get_room_at(Vector2i(24, 20), 0)).is_operational(), "el dormitorio de 2x3 con puerta es operativo")
	await _click_grid(_center(Vector2i(20, 20)), MOUSE_BUTTON_LEFT)
	await _frames(2)
	var small_bedroom: Room = state.rooms.get_room_at(Vector2i(20, 20), 0)
	_check(small_bedroom.type_id == &"bedroom" and not state.rooms.get_status(small_bedroom).is_operational(), "un baño de 2x2 como dormitorio no es operativo")
	_check(panel.get_plain_text().contains("Área mínima: 6 celdas (tiene 4)"), "el panel indica el requisito incumplido")
	_save_args(6)

	# Clic derecho quita el tipo; sobre suelo vacío no hace nada.
	await _click_grid(_center(Vector2i(20, 20)), MOUSE_BUTTON_RIGHT)
	_check(state.rooms.get_room_at(Vector2i(20, 20), 0).type_id == &"", "clic derecho quita el tipo")
	await _click_grid(_center(Vector2i(28, 28)), MOUSE_BUTTON_LEFT)
	_check(state.rooms.get_rooms(0).size() == 2, "clic fuera de las habitaciones no hace nada")

	# Esc desmarca la herramienta y el botón.
	await _press_key(KEY_ESCAPE)
	_check(controller.current_tool == BuildController.Tool.NONE and not bedroom_button.button_pressed, "Esc desmarca la herramienta Tipo y su botón")

	# Limpieza para no influir en las comprobaciones siguientes.
	controller.set_tool(BuildController.Tool.ROOM)
	await _drag_grid([_center(Vector2i(20, 20)), _center(Vector2i(21, 21))], MOUSE_BUTTON_RIGHT)
	await _drag_grid([_center(Vector2i(24, 20)), _center(Vector2i(25, 22))], MOUSE_BUTTON_RIGHT)
	controller.set_tool(BuildController.Tool.NONE)
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	await _frames(3)


func _check_agents() -> void:
	print("== agentes")
	var state: GameState = _main.state
	var controller: BuildController = _main.build_controller
	var toolbar: BuildToolbar = _main.toolbar
	var panel: AgentInfoPanel = _main.agent_info_panel
	var layer: AgentsLayer = _main.agents_layer
	var camera: IsoCamera = _main.camera
	var floor_rect := Rect2i(Vector2i(16, 16), Vector2i(15, 12))
	state.build.fill_rect_floor(floor_rect, 0)
	state.build.build_room(Rect2i(Vector2i(21, 19), Vector2i(4, 3)), 0)
	state.build.place_door(Edge.from_side(Vector2i(22, 21), Edge.Side.SOUTH), 0)
	camera.position = IsoProjection.grid_to_world(Vector2(23, 21))
	await _frames(3)

	# Herramienta Agente: el botón de la barra, crear, seleccionar y no repetir al arrastrar.
	var agent_button: Button = toolbar.get_tool_button(BuildController.Tool.AGENT)
	await _click_button(agent_button)
	_check(controller.current_tool == BuildController.Tool.AGENT and agent_button.button_pressed, "el botón Agente activa la herramienta")
	await _click_grid(_center(Vector2i(18, 17)), MOUSE_BUTTON_LEFT)
	_check(state.agents.get_agents().size() == 1, "clic sobre suelo libre crea un agente")
	var agent: Agent = state.agents.get_agents()[0]
	agent.wanders = false
	_check(controller.selected_agent_id == agent.id and layer.get_view_count() == 1, "queda seleccionado y con su vista")
	_check(panel.visible and panel.get_plain_text().contains("Agente %d" % agent.id) and panel.get_plain_text().contains("Quieto"), "el panel muestra su estado")
	await _click_grid(_center(Vector2i(18, 17)), MOUSE_BUTTON_LEFT)
	_check(state.agents.get_agents().size() == 1, "clic sobre un agente lo selecciona, no crea otro")
	await _drag_grid([_center(Vector2i(18, 17)), _center(Vector2i(19, 17)), _center(Vector2i(20, 17))], MOUSE_BUTTON_LEFT)
	_check(state.agents.get_agents().size() == 1, "arrastrar con la herramienta Agente no crea agentes")
	await _click_grid(_center(Vector2i(28, 17)), MOUSE_BUTTON_LEFT)
	_check(state.agents.get_agents().size() == 2, "otro clic en suelo libre crea un segundo agente")
	var second: Agent = state.agents.get_agents()[1]
	second.wanders = false
	_check(controller.selected_agent_id == second.id, "el nuevo queda seleccionado")
	await _click_grid(_center(Vector2i(18, 17)), MOUSE_BUTTON_LEFT)
	_check(controller.selected_agent_id == agent.id, "volver a pulsar al primero lo selecciona")
	await _click_grid(_center(Vector2i(2, 2)), MOUSE_BUTTON_LEFT)
	_check(state.agents.get_agents().size() == 2, "clic sin suelo no crea agentes")

	# Enviarlo con clic derecho; el reloj a x3 para que no tarde. Se vigila cada fotograma que
	# solo pise suelo y no cruce paredes.
	state.clock.set_speed(GameClock.Speed.X3)
	await _click_grid(_center(Vector2i(28, 25)), MOUSE_BUTTON_RIGHT)
	_check(agent.state == Agent.State.WALKING and agent.destination == Vector2i(28, 25), "clic derecho lo manda a la celda")
	_check(panel.get_plain_text().contains("Camina hacia (28, 25)"), "el panel indica el destino")
	var start_position: Vector2 = agent.position
	await _frames(20)
	_check(agent.position != start_position, "se mueve")
	_save_args(7)
	await _walk_until_idle(agent, 900)
	_check(agent.state == Agent.State.IDLE and agent.get_cell() == Vector2i(28, 25), "llega a su destino")
	_check(panel.get_plain_text().contains("Quieto"), "el panel vuelve a Quieto")

	# Entrar en la habitación solo por su puerta.
	await _click_grid(_center(Vector2i(22, 20)), MOUSE_BUTTON_RIGHT)
	_check(agent.state == Agent.State.WALKING, "se le manda al interior de la habitación")
	await _walk_until_idle(agent, 900)
	_check(agent.get_cell() == Vector2i(22, 20), "llega dentro de la habitación sin atravesar paredes")

	# Una pared nueva en su camino: rodea o, si cierra el paso, queda bloqueado.
	state.build.place_door(Edge.from_side(Vector2i(22, 21), Edge.Side.SOUTH), 0) # sigue abierta
	await _click_grid(_center(Vector2i(16, 16)), MOUSE_BUTTON_RIGHT)
	await _frames(10)
	state.build.place_wall(Edge.from_side(Vector2i(22, 21), Edge.Side.SOUTH), 0) # se cierra la puerta
	await _frames(5)
	_check(agent.state == Agent.State.BLOCKED, "con la puerta cerrada queda bloqueado")
	_check(panel.get_plain_text().contains("Bloqueado"), "y el panel lo dice")
	_save_args(8)
	state.build.place_door(Edge.from_side(Vector2i(22, 21), Edge.Side.SOUTH), 0)
	await _frames(5)
	_check(agent.state == Agent.State.WALKING, "al reabrir la puerta reanuda solo")
	await _walk_until_idle(agent, 900)
	_check(agent.get_cell() == Vector2i(16, 16), "y llega a su destino")

	# Eliminar con Supr.
	var removed_id: int = agent.id
	await _press_key(KEY_DELETE)
	_check(state.agents.get_agent(removed_id) == null and state.agents.get_agents().size() == 1, "Supr elimina al seleccionado")
	_check(layer.get_view_count() == 1 and not panel.visible, "su vista y el panel desaparecen")

	# Ordenación con las paredes: un agente justo detrás de una pared queda tapado y uno justo
	# delante se ve. Se comprueba mirando el color real de los píxeles.
	state.clock.set_speed(GameClock.Speed.PAUSED)
	state.agents.remove(second.id)
	for x in range(26, 30):
		state.build.place_wall(Edge.new(Vector2i(x, 18), Edge.Axis.X), 0)
	var behind: Agent = state.agents.spawn(Vector2i(26, 17), 0)
	var front: Agent = state.agents.spawn(Vector2i(29, 18), 0)
	behind.wanders = false
	front.wanders = false
	behind.position = Vector2(26.5, 17.8) # 0,2 celdas al norte de la pared: detrás
	front.position = Vector2(29.5, 18.2) # 0,2 celdas al sur: delante
	camera.position = IsoProjection.grid_to_world(Vector2(28, 18))
	await _frames(4)
	var screenshot: Image = root.get_texture().get_image()
	var behind_pixel: Color = _pixel_at_body(screenshot, behind)
	var front_pixel: Color = _pixel_at_body(screenshot, front)
	_check(_close(front_pixel, AgentView.body_color_of(front)), "el agente delante de la pared se ve (%s)" % str(front_pixel))
	_check(_close(behind_pixel, TilesetFactory.WALL_FACE_X), "el agente detrás de la pared queda tapado por ella (%s)" % str(behind_pixel))
	_save_args(9)

	# Y al revés, con la pared del lado oeste (eje Y): detrás es "oeste", delante es "este".
	for x in range(26, 30):
		state.build.remove_wall(Edge.new(Vector2i(x, 18), Edge.Axis.X), 0)
	for y in range(18, 22):
		state.build.place_wall(Edge.new(Vector2i(27, y), Edge.Axis.Y), 0)
	behind.position = Vector2(26.8, 19.5) # 0,2 celdas al oeste de la pared: detrás
	front.position = Vector2(27.2, 21.5) # 0,2 celdas al este: delante
	camera.position = IsoProjection.grid_to_world(Vector2(27, 20))
	await _frames(4)
	screenshot = root.get_texture().get_image()
	_check(_close(_pixel_at_body(screenshot, front), AgentView.body_color_of(front)), "pared del eje Y: el agente delante se ve")
	_check(_close(_pixel_at_body(screenshot, behind), TilesetFactory.WALL_FACE_Y), "pared del eje Y: el agente detrás queda tapado (%s)" % str(_pixel_at_body(screenshot, behind)))
	_save_args(10)

	# Limpieza.
	for placed in state.agents.get_agents():
		state.agents.remove(placed.id)
	for y in range(18, 22):
		state.build.remove_wall(Edge.new(Vector2i(27, y), Edge.Axis.Y), 0)
	controller.set_tool(BuildController.Tool.NONE)
	state.build.clear_rect_floor(floor_rect, 0)
	state.build.demolish_room(Rect2i(Vector2i(21, 19), Vector2i(4, 3)), 0)
	state.clock.set_speed(GameClock.Speed.X1)
	camera.position = IsoProjection.grid_to_world(Vector2(state.grid.size) * 0.5)
	await _frames(3)


## Avanza fotogramas hasta que el agente deja de caminar, comprobando en cada uno que está sobre
## suelo y que no ha cruzado ninguna pared.
func _walk_until_idle(agent: Agent, max_frames: int) -> void:
	var state: GameState = _main.state
	var previous: Vector2i = agent.get_cell()
	var frames: int = 0
	while agent.state == Agent.State.WALKING and frames < max_frames:
		await _frames(1)
		frames += 1
		var cell: Vector2i = agent.get_cell()
		if not state.grid.is_walkable(cell, 0):
			_check(false, "el agente pisó %s sin suelo" % str(cell))
			return
		if cell != previous:
			if not Pathfinder.is_step_legal(state.grid, 0, previous, cell):
				_check(false, "el agente cruzó una pared: %s -> %s" % [str(previous), str(cell)])
				return
			previous = cell


## Color del píxel en el centro del cuerpo del agente.
func _pixel_at_body(screenshot: Image, agent: Agent) -> Color:
	var feet: Vector2 = _screen_of_grid(agent.position)
	var body_center: Vector2 = feet + Vector2(0, -9.5)
	return screenshot.get_pixelv(Vector2i(body_center))


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.12


func _click_button(button: Button) -> void:
	var position: Vector2 = button.get_global_rect().get_center()
	await _send_mouse_motion(position)
	await _send_mouse_button(MOUSE_BUTTON_LEFT, true, position)
	await _send_mouse_button(MOUSE_BUTTON_LEFT, false, position)


func _check_clock() -> void:
	print("== reloj")
	var clock: GameClock = _main.state.clock
	var label: ClockLabel = _main.clock_label
	await _frames(1)
	var started: float = clock.total_minutes
	await _frames(20)
	_check(clock.total_minutes > started, "el reloj avanza con el tiempo real")
	_check(label.text.contains("Día 1") and label.text.contains("[x1]"), "la etiqueta muestra día y velocidad: '%s'" % label.text)

	await _press_key(KEY_SPACE)
	_check(clock.is_paused() and label.text.contains("[Pausa]"), "Espacio pausa: '%s'" % label.text)
	var paused_at: float = clock.total_minutes
	await _frames(20)
	_check(clock.total_minutes == paused_at, "en pausa el tiempo no avanza")

	await _press_key(KEY_3)
	_check(clock.speed == GameClock.Speed.X3 and label.text.contains("[x3]"), "la tecla 3 elige x3")
	await _press_key(KEY_2)
	_check(clock.speed == GameClock.Speed.X2, "la tecla 2 elige x2")
	await _press_key(KEY_1)
	_check(clock.speed == GameClock.Speed.X1, "la tecla 1 elige x1")
	await _press_key(KEY_SPACE)
	await _press_key(KEY_SPACE)
	_check(clock.speed == GameClock.Speed.X1, "pausar y reanudar vuelve a la velocidad anterior")


func _press_key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	Input.parse_input_event(event)
	await _frames(2)
	event = InputEventKey.new()
	event.keycode = keycode
	event.pressed = false
	Input.parse_input_event(event)
	await _frames(1)


# --- Utilidades -------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK    %s" % message)
	else:
		_failures += 1
		print("  FALLO %s" % message)


func _save_args(index: int) -> void:
	_save(OS.get_cmdline_user_args(), index)


func _click_grid(grid_pos: Vector2, button: MouseButton) -> void:
	await _move_mouse_to_grid(grid_pos)
	var screen: Vector2 = _screen_of_grid(grid_pos)
	await _send_mouse_button(button, true, screen)
	await _send_mouse_button(button, false, screen)


## Mantiene el botón pulsado mientras el ratón pasa por los puntos indicados.
func _drag_grid(points: Array[Vector2], button: MouseButton, shift: bool = false) -> void:
	await _begin_drag_grid(points, button, shift)
	await _end_drag_grid(points[points.size() - 1], button, shift)


## Pulsa y mueve por los puntos sin soltar (para poder comprobar cosas a mitad del arrastre).
func _begin_drag_grid(points: Array[Vector2], button: MouseButton, shift: bool = false) -> void:
	await _move_mouse_to_grid(points[0])
	await _send_mouse_button(button, true, _screen_of_grid(points[0]), shift)
	for i in range(1, points.size()):
		await _move_mouse_to_grid(points[i])


func _end_drag_grid(end_point: Vector2, button: MouseButton, shift: bool = false) -> void:
	await _send_mouse_button(button, false, _screen_of_grid(end_point), shift)


func _center(cell: Vector2i) -> Vector2:
	return Vector2(cell) + Vector2(0.5, 0.5)


func _save(args: PackedStringArray, index: int) -> void:
	if args.size() <= index:
		return
	root.get_texture().get_image().save_png(args[index])
	print("captura: %s" % args[index])


func _frames(count: int) -> void:
	for i in range(count):
		await process_frame


## Posición de pantalla correspondiente a un punto fraccionario de la cuadrícula.
func _screen_of_grid(grid_pos: Vector2) -> Vector2:
	var camera: IsoCamera = _main.camera
	var vp: Vector2 = root.get_visible_rect().size
	return (IsoProjection.grid_to_world(grid_pos) - camera.position) * camera.zoom.x + vp * 0.5


func _move_mouse_to_grid(grid_pos: Vector2) -> void:
	await _send_mouse_motion(_screen_of_grid(grid_pos))


func _send_mouse_motion(screen_pos: Vector2, relative: Vector2 = Vector2.ZERO) -> void:
	var event := InputEventMouseMotion.new()
	event.position = screen_pos
	event.global_position = screen_pos
	event.relative = relative
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		event.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	Input.parse_input_event(event)
	await _frames(2)


func _send_mouse_button(button: MouseButton, pressed: bool, screen_pos: Vector2, shift: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.shift_pressed = shift
	event.button_index = button
	event.pressed = pressed
	event.position = screen_pos
	event.global_position = screen_pos
	Input.parse_input_event(event)
	await _frames(2)


func _send_wheel(screen_pos: Vector2, button: MouseButton) -> void:
	await _send_mouse_button(button, true, screen_pos)
	await _send_mouse_button(button, false, screen_pos)
