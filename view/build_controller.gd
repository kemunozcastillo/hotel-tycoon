class_name BuildController
extends Node
## Traduce la entrada del jugador en órdenes de construcción. No toca la vista: llama a
## BuildCommands (sim/) y la vista se actualiza sola por las señales del mapa.
##
## Clic izquierdo coloca, clic derecho quita; se puede arrastrar para pintar varias celdas
## o aristas. Esc deselecciona la herramienta.

enum Tool { NONE, FLOOR, WALL }

signal tool_changed(new_tool: Tool)

var current_tool: Tool = Tool.NONE

var _state: GameState
var _cursor: CellCursor
var _level: int = 0
# Botón del ratón con el que empezó la pincelada en curso (0 = ninguna).
var _stroke_button: int = 0


func setup(state: GameState, cursor: CellCursor, level: int) -> void:
	_state = state
	_cursor = cursor
	_level = level
	cursor.hover_changed.connect(_on_hover_changed)


func set_tool(new_tool: Tool) -> void:
	if new_tool == current_tool:
		return
	current_tool = new_tool
	_stroke_button = 0
	# En modo pared se resalta la arista; con las demás herramientas, la celda.
	_cursor.edge_mode = new_tool == Tool.WALL
	tool_changed.emit(new_tool)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
			return
		if button.pressed:
			if current_tool != Tool.NONE:
				_stroke_button = button.button_index
				_apply_at_hover()
		elif button.button_index == _stroke_button:
			_stroke_button = 0
	elif event.is_action_pressed("ui_cancel"):
		set_tool(Tool.NONE)


func _process(_delta: float) -> void:
	# Por si el soltado del botón lo consumió la interfaz y nunca llegó aquí.
	if _stroke_button != 0 and not Input.is_mouse_button_pressed(_stroke_button as MouseButton):
		_stroke_button = 0


func _on_hover_changed() -> void:
	if _stroke_button != 0:
		_apply_at_hover()


func _apply_at_hover() -> void:
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
