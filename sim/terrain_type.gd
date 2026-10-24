class_name TerrainType
extends RefCounted
## Un tipo de terreno exterior (calle, acera, césped...) y lo que permite. Son datos: se leen de
## data/terrain_types.json mediante TerrainCatalog.

var id: StringName = &""
var display_name: String = ""
## Si los agentes pueden pisarlo (sin suelo construido encima).
var walkable: bool = true
## Coste de pisar una celda de este terreno, como multiplicador de la distancia (>= 1.0: 1.0 es lo
## normal y más es "preferir no pasar por aquí").
var cost: float = 1.0
## Si se pueden construir suelos y paredes sobre él.
var buildable: bool = true
## Color con el que lo dibuja la vista.
var color: Color = Color.WHITE


## Crea un tipo a partir de un diccionario del JSON. Si es inválido devuelve null y añade los
## motivos a `errors`.
static func from_dict(data: Dictionary, errors: Array[String]) -> TerrainType:
	var type := TerrainType.new()
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

	type.walkable = _read_bool(data, "walkable", true, label, errors)
	type.buildable = _read_bool(data, "buildable", true, label, errors)

	var raw_cost: Variant = data.get("cost", 1.0)
	if (typeof(raw_cost) != TYPE_INT and typeof(raw_cost) != TYPE_FLOAT) or float(raw_cost) < 1.0 or float(raw_cost) > 1000.0:
		errors.append("'%s': 'cost' debe ser un número entre 1 y 1000" % label)
	else:
		type.cost = float(raw_cost)

	return type if errors.size() == count_before else null


static func _read_bool(data: Dictionary, key: String, default_value: bool, label: String, errors: Array[String]) -> bool:
	if not data.has(key):
		return default_value
	if typeof(data[key]) != TYPE_BOOL:
		errors.append("'%s': '%s' debe ser true o false" % [label, key])
		return default_value
	return data[key] as bool
