class_name RoomType
extends RefCounted
## Definición de un tipo de habitación (dormitorio, baño...) y sus requisitos.
## Son datos: se leen de data/room_types.json mediante RoomTypeCatalog.

var id: StringName = &""
var display_name: String = ""
## Color asociado al tipo (lo usa la vista para teñir la habitación).
var color: Color = Color.WHITE
## Celdas mínimas.
var min_area: int = 1
## Celdas máximas (0 = sin límite).
var max_area: int = 0
## Lado corto mínimo del rectángulo que contiene la habitación (0 = sin requisito).
var min_short_side: int = 0
## Puertas mínimas en el perímetro (0 = sin requisito).
var min_doors: int = 0
var requires_complete_floor: bool = true
## Precio de una estancia en una habitación de este tipo (solo los dormitorios lo usan; 0 = no se
## alquila).
var stay_price: int = 0
## Extra por cada celda por encima de `min_area`: las habitaciones grandes rinden más.
var stay_price_per_extra_cell: int = 0
## Mantenimiento diario de cada habitación de este tipo (se paga siempre, sea o no operativa).
var daily_upkeep: int = 0


## Crea un tipo a partir de un diccionario del JSON. Si es inválido devuelve null y añade los
## motivos a `errors`.
static func from_dict(data: Dictionary, errors: Array[String]) -> RoomType:
	var type := RoomType.new()
	var count_before: int = errors.size()

	var raw_id: Variant = data.get("id")
	if typeof(raw_id) != TYPE_STRING or (raw_id as String).strip_edges().is_empty():
		errors.append("falta 'id' (texto no vacío)")
	else:
		type.id = StringName((raw_id as String).strip_edges())
	var label: String = str(type.id) if type.id != &"" else "?"

	var raw_name: Variant = data.get("name")
	if typeof(raw_name) != TYPE_STRING or (raw_name as String).strip_edges().is_empty():
		errors.append("'%s': falta 'name' (texto no vacío)" % label)
	else:
		type.display_name = (raw_name as String).strip_edges()

	var raw_color: Variant = data.get("color", "#ffffff")
	if typeof(raw_color) != TYPE_STRING or not Color.html_is_valid(raw_color as String):
		errors.append("'%s': 'color' no es un color HTML válido (ej. \"#5b8def\")" % label)
	else:
		type.color = Color.html(raw_color as String)

	type.min_area = _read_int(data, "min_area", 1, 1, label, errors)
	type.max_area = _read_int(data, "max_area", 0, 0, label, errors)
	type.min_short_side = _read_int(data, "min_short_side", 0, 0, label, errors)
	type.min_doors = _read_int(data, "min_doors", 0, 0, label, errors)
	type.stay_price = _read_int(data, "stay_price", 0, 0, label, errors)
	type.stay_price_per_extra_cell = _read_int(data, "stay_price_per_extra_cell", 0, 0, label, errors)
	type.daily_upkeep = _read_int(data, "daily_upkeep", 0, 0, label, errors)

	var raw_floor: Variant = data.get("requires_complete_floor", true)
	if typeof(raw_floor) != TYPE_BOOL:
		errors.append("'%s': 'requires_complete_floor' debe ser true o false" % label)
	else:
		type.requires_complete_floor = raw_floor as bool

	if type.max_area != 0 and type.max_area < type.min_area:
		errors.append("'%s': 'max_area' (%d) es menor que 'min_area' (%d)" % [label, type.max_area, type.min_area])

	return type if errors.size() == count_before else null


## Lee un entero >= minimum. JSON no distingue enteros de decimales, así que se acepta un
## número sin parte fraccionaria.
static func _read_int(data: Dictionary, key: String, default_value: int, minimum: int, label: String, errors: Array[String]) -> int:
	if not data.has(key):
		return default_value
	var raw: Variant = data[key]
	var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
	if not is_number or float(raw) != floorf(float(raw)) or int(raw) < minimum:
		errors.append("'%s': '%s' debe ser un entero >= %d" % [label, key, minimum])
		return default_value
	return int(raw)
