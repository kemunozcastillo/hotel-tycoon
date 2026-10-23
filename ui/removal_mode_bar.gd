class_name RemovalModeBar
extends PanelContainer
## Selector de qué se hace con lo que se quita: Vender (se recupera su valor) o Guardar (va al
## inventario). Centrado abajo, encima del selector de paredes. Solo emite el modo elegido.

## El jugador eligió un modo.
signal mode_selected(mode: Inventory.RemovalMode)

const MARGIN: float = 8.0
## Separación del borde de abajo: deja sitio al selector de paredes.
const BOTTOM_OFFSET: float = 54.0

var _buttons: Dictionary = {} # Inventory.RemovalMode -> Button


func setup(initial_mode: Inventory.RemovalMode) -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -BOTTOM_OFFSET
	offset_bottom = -BOTTOM_OFFSET
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var label := Label.new()
	label.text = "Al quitar (V):"
	label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(label)

	var group := ButtonGroup.new() # siempre hay uno elegido
	_add_button(box, group, "Vender", Inventory.RemovalMode.SELL,
			"Se recupera el valor de la pieza: el 100% si es nueva, menos si es usada")
	_add_button(box, group, "Guardar", Inventory.RemovalMode.STORE,
			"La pieza va al inventario y se puede reutilizar gratis (tecla I)")
	set_mode(initial_mode)


## Marca el botón del modo indicado sin emitir la señal (para seguir un cambio hecho desde fuera).
func set_mode(mode: Inventory.RemovalMode) -> void:
	for button_mode: Inventory.RemovalMode in _buttons.keys():
		(_buttons[button_mode] as Button).set_pressed_no_signal(button_mode == mode)


func get_button(mode: Inventory.RemovalMode) -> Button:
	return _buttons.get(mode) as Button


func _add_button(parent: Control, group: ButtonGroup, label: String, mode: Inventory.RemovalMode, tooltip: String) -> void:
	var button := Button.new()
	button.text = label
	button.tooltip_text = tooltip
	button.toggle_mode = true
	button.button_group = group
	button.focus_mode = Control.FOCUS_NONE # que la barra espaciadora siga siendo del reloj
	button.toggled.connect(_on_button_toggled.bind(mode))
	parent.add_child(button)
	_buttons[mode] = button


func _on_button_toggled(pressed: bool, mode: Inventory.RemovalMode) -> void:
	if pressed:
		mode_selected.emit(mode)
