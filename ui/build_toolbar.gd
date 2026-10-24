class_name BuildToolbar
extends PanelContainer
## Barra de herramientas de construcción. Solo elige la herramienta del BuildController; no
## conoce la simulación. Los botones de tipo de habitación se generan a partir del catálogo.

const HINT_TEXT: String = "Izq.: construir   Der.: quitar   Mayús+arrastrar: rectángulo   Esc: salir"

var _controller: BuildController
var _group: ButtonGroup
var _tool_buttons: Dictionary = {} # BuildController.Tool -> Button
var _type_buttons: Dictionary = {} # StringName (id del tipo) -> Button


func setup(controller: BuildController, catalog: RoomTypeCatalog) -> void:
	_controller = controller
	# Dos filas: los botones y, debajo, la ayuda.
	var rows := VBoxContainer.new()
	add_child(rows)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	rows.add_child(box)

	_group = ButtonGroup.new()
	_group.allow_unpress = true
	_add_tool_button(box, _group, "Suelo", BuildController.Tool.FLOOR)
	_add_tool_button(box, _group, "Pared", BuildController.Tool.WALL)
	_add_tool_button(box, _group, "Puerta", BuildController.Tool.DOOR)
	_add_tool_button(box, _group, "Habitación", BuildController.Tool.ROOM)

	if not catalog.get_types().is_empty():
		box.add_child(VSeparator.new())
		for type: RoomType in catalog.get_types():
			_add_type_button(box, _group, type)

	# Herramienta de desarrollo para crear, seleccionar y mandar agentes.
	box.add_child(VSeparator.new())
	_add_tool_button(box, _group, "Agente", BuildController.Tool.AGENT)

	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.modulate = Color(1, 1, 1, 0.7)
	rows.add_child(hint)

	controller.tool_changed.connect(_on_selection_changed)
	controller.room_type_selected.connect(_on_selection_changed)


func get_tool_button(build_tool: BuildController.Tool) -> Button:
	return _tool_buttons.get(build_tool) as Button


func get_type_button(type_id: StringName) -> Button:
	return _type_buttons.get(type_id) as Button


func _add_tool_button(parent: Control, group: ButtonGroup, label: String, build_tool: BuildController.Tool) -> void:
	var button: Button = _make_button(parent, group, label)
	button.toggled.connect(_on_tool_button_toggled.bind(build_tool))
	_tool_buttons[build_tool] = button


func _add_type_button(parent: Control, group: ButtonGroup, type: RoomType) -> void:
	var button: Button = _make_button(parent, group, type.display_name)
	button.tooltip_text = "Asignar tipo: %s" % type.display_name
	button.toggled.connect(_on_type_button_toggled.bind(type.id))
	_type_buttons[type.id] = button


func _make_button(parent: Control, group: ButtonGroup, label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE # que la barra espaciadora siga siendo del reloj
	parent.add_child(button)
	return button


func _on_tool_button_toggled(pressed: bool, build_tool: BuildController.Tool) -> void:
	if pressed:
		_controller.set_tool(build_tool)
	elif _controller.current_tool == build_tool and not _another_button_is_pressed():
		_controller.set_tool(BuildController.Tool.NONE)


func _on_type_button_toggled(pressed: bool, type_id: StringName) -> void:
	if pressed:
		_controller.select_room_type(type_id)
	elif _controller.current_tool == BuildController.Tool.TYPE and _controller.selected_type_id == type_id \
			and not _another_button_is_pressed():
		_controller.set_tool(BuildController.Tool.NONE)


## Al pasar de un botón a otro del grupo, Godot avisa primero de que el anterior se soltó cuando
## el nuevo ya está pulsado. Si se deseleccionara la herramienta en ese momento, la
## sincronización de botones desmarcaría el que se acaba de pulsar y la selección se perdería.
func _another_button_is_pressed() -> bool:
	return _group.get_pressed_button() != null


## Mantiene los botones sincronizados cuando la selección cambia desde fuera (Esc, código).
func _on_selection_changed(_value: Variant = null) -> void:
	var tool_now: BuildController.Tool = _controller.current_tool
	for build_tool: BuildController.Tool in _tool_buttons.keys():
		(_tool_buttons[build_tool] as Button).set_pressed_no_signal(build_tool == tool_now)
	for type_id: StringName in _type_buttons.keys():
		var selected: bool = tool_now == BuildController.Tool.TYPE and _controller.selected_type_id == type_id
		(_type_buttons[type_id] as Button).set_pressed_no_signal(selected)
