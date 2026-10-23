class_name BuildToolbar
extends PanelContainer
## Barra de herramientas de construcción. Solo elige la herramienta del BuildController;
## no conoce la simulación.

const HINT_TEXT: String = "Clic izq.: construir   Clic der.: quitar   Esc: salir"

var _controller: BuildController
var _buttons: Dictionary = {} # BuildController.Tool -> Button


func setup(controller: BuildController) -> void:
	_controller = controller
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var group := ButtonGroup.new()
	group.allow_unpress = true
	_add_tool_button(box, group, "Suelo", BuildController.Tool.FLOOR)
	_add_tool_button(box, group, "Pared", BuildController.Tool.WALL)

	var hint := Label.new()
	hint.text = HINT_TEXT
	hint.modulate = Color(1, 1, 1, 0.7)
	box.add_child(hint)

	controller.tool_changed.connect(_on_tool_changed)


func _add_tool_button(parent: Control, group: ButtonGroup, label: String, build_tool: BuildController.Tool) -> void:
	var button := Button.new()
	button.text = label
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE # que la barra espaciadora siga siendo del reloj
	button.toggled.connect(_on_button_toggled.bind(build_tool))
	parent.add_child(button)
	_buttons[build_tool] = button


func _on_button_toggled(pressed: bool, build_tool: BuildController.Tool) -> void:
	if pressed:
		_controller.set_tool(build_tool)
	elif _controller.current_tool == build_tool:
		# Solo se deselecciona si no se acaba de elegir otra herramienta.
		_controller.set_tool(BuildController.Tool.NONE)


## Mantiene los botones sincronizados cuando la herramienta cambia desde fuera (Esc).
func _on_tool_changed(new_tool: BuildController.Tool) -> void:
	for build_tool: BuildController.Tool in _buttons.keys():
		(_buttons[build_tool] as Button).set_pressed_no_signal(build_tool == new_tool)
