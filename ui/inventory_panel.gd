class_name InventoryPanel
extends PanelContainer
## Las piezas guardadas, por tipo y estado (nuevas o usadas), con lo que valdrían al venderlas y un
## botón para venderlas. Se abre y se cierra con la tecla I. Al venderlas entra dinero y la pieza
## sale del inventario.

const PANEL_WIDTH: float = 520.0

var _inventory: Inventory
var _economy: Economy
var _rules: EconomyRules
var _content: VBoxContainer
var _rows: Array[Dictionary] = []


func setup(inventory: Inventory, economy: Economy, rules: EconomyRules, storage: StorageCapacity) -> void:
	_inventory = inventory
	_economy = economy
	_rules = rules
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.08, 0.10, 0.95)
	background.set_content_margin_all(14.0)
	background.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", background)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)
	visible = false
	inventory.stock_changed.connect(_on_stock_changed)
	storage.capacity_changed.connect(_on_capacity_changed)


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	visible = open
	if open:
		_rebuild()


func toggle() -> void:
	set_open(not visible)


## Las filas con existencias: tipo, estado, cuántas y lo que valdrían (ordenadas por tipo y,
## dentro de cada tipo, nuevas antes que usadas). Es lo que muestra el panel.
static func stock_rows(inventory: Inventory, rules: EconomyRules) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for kind in range(BuildItem.KIND_COUNT):
		for condition: BuildItem.Condition in [BuildItem.Condition.NEW, BuildItem.Condition.USED]:
			var count: int = inventory.count(kind as BuildItem.Kind, condition)
			if count > 0:
				rows.append({
					"kind": kind, "condition": condition, "count": count,
					"value": count * rules.sale_value(kind as BuildItem.Kind, condition),
				})
	return rows


## Texto del panel sin formato y botones (para comprobaciones).
func get_plain_text() -> String:
	var parts: Array[String] = []
	for child in _content.get_children():
		if child is Label:
			parts.append((child as Label).text)
		elif child is HBoxContainer:
			for inner in child.get_children():
				if inner is Label:
					parts.append((inner as Label).text)
	return "\n".join(parts)


## Los botones de vender de cada fila, en el orden de las filas (para pulsarlos en las pruebas).
func get_sell_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child in _content.get_children():
		if child is HBoxContainer:
			for inner in child.get_children():
				if inner is Button:
					buttons.append(inner as Button)
	return buttons


func _on_stock_changed() -> void:
	if visible:
		_rebuild()


func _on_capacity_changed(_capacity: int) -> void:
	if visible:
		_rebuild()


func _rebuild() -> void:
	for child in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	_rows = stock_rows(_inventory, _rules)

	var title := Label.new()
	title.text = "Inventario"
	title.add_theme_font_size_override("font_size", 18)
	_content.add_child(title)

	var used: int = _inventory.total_items()
	var capacity: int = _inventory.get_capacity()
	var capacity_line: String = MoneyTexts.capacity_text(used, capacity)
	if not capacity_line.is_empty():
		var capacity_label := Label.new()
		capacity_label.text = capacity_line
		capacity_label.modulate = Color(1, 0.6, 0.45) if used > capacity or capacity == 0 else Color(1, 1, 1, 0.75)
		_content.add_child(capacity_label)

	if _rows.is_empty():
		var empty := Label.new()
		empty.text = "Vacío. Con «Al quitar: Guardar» (tecla V), las piezas que quites vienen aquí\ny se pueden reutilizar gratis o vender cuando quieras."
		empty.modulate = Color(1, 1, 1, 0.75)
		_content.add_child(empty)
		return

	var total_value: int = 0
	for i in range(_rows.size()):
		var row: Dictionary = _rows[i]
		total_value += int(row["value"])
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 12)
		var text := Label.new()
		text.text = MoneyTexts.stock_row_text(row["kind"], row["condition"], row["count"], row["value"])
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.add_child(text)
		var button := Button.new()
		button.text = "Vender (%s)" % MoneyTexts.signed(int(row["value"]))
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_sell_row.bind(i))
		line.add_child(button)
		_content.add_child(line)

	var footer := Label.new()
	footer.text = "Valor de todo el inventario: %s" % MoneyTexts.format(total_value)
	footer.modulate = Color(1, 1, 1, 0.75)
	_content.add_child(footer)


## Vende todas las piezas de una fila. Al cambiar el inventario el panel se reconstruye solo.
func _sell_row(index: int) -> void:
	if index < 0 or index >= _rows.size():
		return
	var row: Dictionary = _rows[index]
	_economy.sell_stock(row["kind"], row["condition"], row["count"])
