class_name BuildController
extends Node
## Traduce la entrada del jugador en órdenes de construcción. No toca la vista: llama a
## BuildCommands (sim/) y la vista se actualiza sola por las señales del mapa.
##
## Clic izquierdo coloca, clic derecho quita. Con Suelo y Pared se pinta arrastrando
## (pincel); con Shift pulsado al empezar, el arrastre define un rectángulo (suelo relleno o
## perímetro de paredes). La herramienta Habitación siempre usa un rectángulo y crea suelo y
## paredes a la vez. La herramienta Puerta coloca o quita puertas sobre las aristas. La
## herramienta Tipo asigna a la habitación pulsada el tipo elegido (clic derecho lo quita).
## La herramienta Agente (de desarrollo) selecciona un agente con clic izquierdo, o crea uno si
## la celda está libre; clic derecho lo manda a la celda pulsada y Supr lo elimina.
## Esc cancela el arrastre en curso o, si no hay, deselecciona la herramienta.

enum Tool { NONE, FLOOR, WALL, DOOR, ROOM, TYPE, AGENT }

signal tool_changed(new_tool: Tool)
## Se eligió otro tipo de habitación para la herramienta Tipo.
signal room_type_selected(type_id: StringName)
## Cambió el agente seleccionado (0 = ninguno).
signal agent_selected(agent_id: int)

var current_tool: Tool = Tool.NONE
## Tipo que asigna la herramienta Tipo.
var selected_type_id: StringName = &""
## Agente seleccionado con la herramienta Agente (0 = ninguno).
var selected_agent_id: int = 0

var _state: GameState
var _cursor: CellCursor
var _preview: ShapePreview
var _level: int = 0
# Botón del ratón con el que empezó el arrastre en curso (0 = ninguno).
var _stroke_button: int = 0
# true si el arrastre en curso define un rectángulo en vez de pintar con pincel.
var _shape_mode: bool = false
var _shape_start: Vector2i = Vector2i.ZERO
var _shape_end: Vector2i = Vector2i.ZERO
# true solo en el instante de pulsar el botón: las herramientas de un solo clic (Agente) no se
# repiten al arrastrar por otras celdas.
var _stroke_fresh: bool = false


func setup(state: GameState, cursor: CellCursor, preview: ShapePreview, level: int) -> void:
	_state = state
	_cursor = cursor
	_preview = preview
	_level = level
	cursor.hover_changed.connect(_on_hover_changed)
	state.agents.agent_removed.connect(_on_agent_removed)


func set_tool(new_tool: Tool) -> void:
	if new_tool == current_tool:
		return
	current_tool = new_tool
	_cancel_stroke()
	if new_tool != Tool.AGENT:
		select_agent(0)
	tool_changed.emit(new_tool)


## Selecciona un agente (0 = ninguno).
func select_agent(agent_id: int) -> void:
	if agent_id == selected_agent_id:
		return
	selected_agent_id = agent_id
	agent_selected.emit(agent_id)


func _on_agent_removed(agent: Agent) -> void:
	if agent.id == selected_agent_id:
		select_agent(0)


## Activa la herramienta Tipo con el tipo de habitación indicado.
func select_room_type(type_id: StringName) -> void:
	var changed: bool = type_id != selected_type_id
	selected_type_id = type_id
	if current_tool == Tool.TYPE:
		if changed:
			room_type_selected.emit(type_id)
	else:
		set_tool(Tool.TYPE)
		room_type_selected.emit(type_id)


func is_dragging_shape() -> bool:
	return _stroke_button != 0 and _shape_mode


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
			return
		if button.pressed:
			if current_tool != Tool.NONE and _stroke_button == 0:
				_begin_stroke(button.button_index, button.shift_pressed)
		elif button.button_index == _stroke_button:
			_end_stroke()
	elif event.is_action_pressed("ui_cancel"):
		if _stroke_button != 0:
			_cancel_stroke()
		else:
			set_tool(Tool.NONE)
	elif event is InputEventKey and (event as InputEventKey).pressed and (event as InputEventKey).keycode == KEY_DELETE:
		if current_tool == Tool.AGENT and selected_agent_id != 0:
			_state.agents.remove(selected_agent_id)


func _process(_delta: float) -> void:
	# Por si el soltado del botón lo consumió la interfaz y nunca llegó aquí: se cancela.
	if _stroke_button != 0 and not Input.is_mouse_button_pressed(_stroke_button as MouseButton):
		_cancel_stroke()
	_update_cursor_mode()


func _on_hover_changed() -> void:
	if _stroke_button == 0:
		return
	if _shape_mode:
		if _cursor.is_hovering:
			_shape_end = _cursor.hover_cell
			_update_preview()
	else:
		_apply_brush()


# --- Arrastres ---------------------------------------------------------------------------

func _begin_stroke(button_index: int, shift_held: bool) -> void:
	var wants_shape: bool = current_tool == Tool.ROOM \
			or (shift_held and (current_tool == Tool.FLOOR or current_tool == Tool.WALL))
	if wants_shape:
		if not _cursor.is_hovering:
			return
		_stroke_button = button_index
		_shape_mode = true
		_shape_start = _cursor.hover_cell
		_shape_end = _shape_start
		_update_preview()
	else:
		_stroke_button = button_index
		_shape_mode = false
		_stroke_fresh = true
		_apply_brush()
		_stroke_fresh = false


func _end_stroke() -> void:
	if _shape_mode:
		_apply_shape()
	_cancel_stroke()


func _cancel_stroke() -> void:
	_stroke_button = 0
	_shape_mode = false
	if _preview != null:
		_preview.clear()


# --- Aplicar órdenes ---------------------------------------------------------------------

func _apply_brush() -> void:
	var removing: bool = _stroke_button == MOUSE_BUTTON_RIGHT
	match current_tool:
		Tool.FLOOR:
			if not _cursor.is_hovering:
				return
			if removing:
				_state.build.remove_floor(_cursor.hover_cell, _level)
			else:
				_state.build.place_floor(_cursor.hover_cell, _level)
		Tool.WALL:
			if not _cursor.has_hover_edge:
				return
			if removing:
				_state.build.remove_wall(_cursor.hover_edge, _level)
			else:
				_state.build.place_wall(_cursor.hover_edge, _level)
		Tool.DOOR:
			if not _cursor.has_hover_edge:
				return
			if removing:
				_state.build.remove_door(_cursor.hover_edge, _level)
			else:
				_state.build.place_door(_cursor.hover_edge, _level)
		Tool.TYPE:
			if not _cursor.is_hovering:
				return
			var room: Room = _state.rooms.get_room_at(_cursor.hover_cell, _level)
			if room == null:
				return
			_state.rooms.set_room_type(room.id, &"" if removing else selected_type_id)
		Tool.AGENT:
			if not _stroke_fresh or not _cursor.is_hovering:
				return
			if removing:
				# Clic derecho: enviar al agente seleccionado a esta celda.
				if selected_agent_id != 0:
					_state.agents.set_destination(selected_agent_id, _cursor.hover_cell)
			else:
				# Clic izquierdo: seleccionar al agente de la celda o, si no hay, crear uno.
				var agent: Agent = _state.agents.get_agent_at(_cursor.hover_cell, _level)
				if agent == null:
					agent = _state.agents.spawn(_cursor.hover_cell, _level)
				if agent != null:
					select_agent(agent.id)


func _apply_shape() -> void:
	var rect: Rect2i = GridShapes.rect_between(_shape_start, _shape_end)
	_state.build.execute(_shape_plan(rect, _stroke_button == MOUSE_BUTTON_RIGHT))


## Las operaciones que haría la herramienta actual sobre el rectángulo. La vista previa y la
## ejecución usan este mismo plan, así que el coste mostrado es el que se cobra.
func _shape_plan(rect: Rect2i, removing: bool) -> Array[BuildOp]:
	match current_tool:
		Tool.FLOOR:
			if removing:
				return _state.build.plan_clear_rect_floor(rect, _level)
			return _state.build.plan_fill_rect_floor(rect, _level)
		Tool.WALL:
			if removing:
				return _state.build.plan_clear_outline_walls(rect, _level)
			return _state.build.plan_outline_rect_walls(rect, _level)
		Tool.ROOM:
			if removing:
				return _state.build.plan_demolish_room(rect, _level)
			return _state.build.plan_build_room(rect, _level)
	return []


# --- Vista previa y cursor ---------------------------------------------------------------

func _update_preview() -> void:
	var kind: ShapePreview.Kind = ShapePreview.Kind.FILL
	match current_tool:
		Tool.WALL:
			kind = ShapePreview.Kind.OUTLINE
		Tool.ROOM:
			kind = ShapePreview.Kind.ROOM
	var rect: Rect2i = GridShapes.rect_between(_shape_start, _shape_end)
	var removing: bool = _stroke_button == MOUSE_BUTTON_RIGHT
	var quote: BuildQuote = _state.build.quote(_shape_plan(rect, removing))
	_preview.show_shape(rect, kind, removing, MoneyTexts.quote_text(quote), quote.affordable)


## La arista se resalta con Puerta y con Pared en modo pincel; cuando se va a dibujar un
## rectángulo (Shift pulsado o arrastre en curso) se resalta la celda de la esquina.
func _update_cursor_mode() -> void:
	var shape_pending: bool = _shape_mode or Input.is_key_pressed(KEY_SHIFT)
	var wants_edge: bool = current_tool == Tool.DOOR or (current_tool == Tool.WALL and not shape_pending)
	if _cursor.edge_mode != wants_edge:
		_cursor.edge_mode = wants_edge
