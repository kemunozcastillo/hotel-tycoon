class_name WallModeBar
extends PanelContainer
## Selector del modo de visualización de las paredes (Arriba / Corte / Bajas / Ocultas), centrado
## abajo. Solo emite el modo elegido; no conoce la vista que lo aplica.

## El jugador eligió un modo.
signal mode_selected(mode: WallViewMode.Mode)

const MARGIN: float = 8.0
const ALL_MODES: Array[WallViewMode.Mode] = [
	WallViewMode.Mode.UP, WallViewMode.Mode.CUTAWAY, WallViewMode.Mode.LOW, WallViewMode.Mode.DOWN,
]

var _buttons: Dictionary = {} # WallViewMode.Mode -> Button


func setup(initial_mode: WallViewMode.Mode) -> void:
	# Centrado abajo; al crecer el contenido se reparte a ambos lados y hacia arriba.
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -MARGIN
	offset_bottom = -MARGIN
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var label := Label.new()
	label.text = "Paredes (C):"
	label.modulate = Color(1, 1, 1, 0.75)
	box.add_child(label)

	var group := ButtonGroup.new() # siempre hay uno elegido: no se puede dejar sin modo
	for mode: WallViewMode.Mode in ALL_MODES:
		var button := Button.new()
		button.text = WallViewMode.label(mode)
		button.toggle_mode = true
		button.button_group = group
		button.focus_mode = Control.FOCUS_NONE # que la barra espaciadora siga siendo del reloj
		button.toggled.connect(_on_button_toggled.bind(mode))
		box.add_child(button)
		_buttons[mode] = button
	set_mode(initial_mode)


## Marca el botón del modo indicado sin emitir la señal (para seguir un cambio hecho desde fuera).
func set_mode(mode: WallViewMode.Mode) -> void:
	for button_mode: WallViewMode.Mode in _buttons.keys():
		(_buttons[button_mode] as Button).set_pressed_no_signal(button_mode == mode)


func get_button(mode: WallViewMode.Mode) -> Button:
	return _buttons.get(mode) as Button


func _on_button_toggled(pressed: bool, mode: WallViewMode.Mode) -> void:
	if pressed:
		mode_selected.emit(mode)
