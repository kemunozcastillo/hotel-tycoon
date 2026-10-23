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

	# Capturas del resaltado: modo celda (args[0]) y modo arista (args[1]).
	_main.cursor.edge_mode = false
	await _move_mouse_to_grid(Vector2(14.5, 12.5))
	_save(args, 0)
	_main.cursor.edge_mode = true
	await _move_mouse_to_grid(Vector2(14.5, 12.08))
	_save(args, 1)
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


# --- Utilidades -------------------------------------------------------------------------

func _check(condition: bool, message: String) -> void:
	if condition:
		print("  OK    %s" % message)
	else:
		_failures += 1
		print("  FALLO %s" % message)


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
