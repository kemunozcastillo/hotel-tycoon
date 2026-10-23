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
	_check(_count_walls(state.grid) == 8, "hay exactamente 8 paredes en el mapa (hay %d)" % _count_walls(state.grid))
	_check(_flood_size(state.grid, origin) == 4, "el baño encierra exactamente 4 celdas")

	# Arrastrar pinta una línea de paredes; clic derecho quita una (la puerta).
	await _drag_grid([Vector2(20.5, 10.03), Vector2(21.5, 10.03), Vector2(22.5, 10.03)], MOUSE_BUTTON_LEFT)
	_check(_count_walls(state.grid) == 11, "arrastrar añade tres paredes (hay %d)" % _count_walls(state.grid))
	await _click_grid(Vector2(16.5, 10.03), MOUSE_BUTTON_RIGHT)
	_check(_count_walls(state.grid) == 10, "clic derecho quita una pared (la puerta)")
	_check(_flood_size(state.grid, origin) > 4, "con la puerta abierta la habitación deja de estar cerrada")

	# Capturas del resultado. Se deja la herramienta de paredes para ver la arista resaltada.
	await _move_mouse_to_grid(Vector2(18.5, 12.03))
	_save_args(0)
	controller.set_tool(BuildController.Tool.NONE)


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
func _drag_grid(points: Array[Vector2], button: MouseButton) -> void:
	await _move_mouse_to_grid(points[0])
	await _send_mouse_button(button, true, _screen_of_grid(points[0]))
	for i in range(1, points.size()):
		await _move_mouse_to_grid(points[i])
	await _send_mouse_button(button, false, _screen_of_grid(points[points.size() - 1]))


func _count_walls(grid: GridMap2D) -> int:
	var count: int = 0
	for y in range(grid.size.y + 1):
		for x in range(grid.size.x + 1):
			for axis: Edge.Axis in [Edge.Axis.X, Edge.Axis.Y]:
				var edge := Edge.new(Vector2i(x, y), axis)
				if grid.is_edge_valid(edge, 0) and grid.has_wall(edge, 0):
					count += 1
	return count


func _flood_size(grid: GridMap2D, start: Vector2i) -> int:
	var visited: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_back()
		for offset: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = current + offset
			if not visited.has(next) and not grid.is_blocked_between(current, next, 0):
				visited[next] = true
				queue.append(next)
	return visited.size()


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


func _send_mouse_button(button: MouseButton, pressed: bool, screen_pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = screen_pos
	event.global_position = screen_pos
	Input.parse_input_event(event)
	await _frames(2)


func _send_wheel(screen_pos: Vector2, button: MouseButton) -> void:
	await _send_mouse_button(button, true, screen_pos)
	await _send_mouse_button(button, false, screen_pos)
