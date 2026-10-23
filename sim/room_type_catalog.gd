class_name RoomTypeCatalog
extends RefCounted
## Catálogo de tipos de habitación cargado desde un JSON. Un tipo mal formado se descarta y
## queda anotado en `warnings`; nunca impide arrancar el juego.
##
## Nota para la exportación: los .json no son recursos de Godot, así que hay que incluir
## `data/*.json` en el filtro de exportación del preset.

const DEFAULT_PATH: String = "res://data/room_types.json"

## Problemas encontrados al cargar (vacío si todo estaba bien).
var warnings: Array[String] = []

var _types: Array[RoomType] = []
var _by_id: Dictionary = {}


## Carga data/room_types.json y muestra los avisos en la consola.
static func load_default() -> RoomTypeCatalog:
	return load_file(DEFAULT_PATH)


## Con `report_warnings` los avisos también se escriben en la consola (push_warning).
static func load_file(path: String, report_warnings: bool = true) -> RoomTypeCatalog:
	var catalog: RoomTypeCatalog
	if not FileAccess.file_exists(path):
		catalog = RoomTypeCatalog.new()
		catalog.warnings.append("no existe el archivo de tipos de habitación: %s" % path)
	else:
		catalog = parse(FileAccess.get_file_as_string(path))
	if report_warnings:
		for warning: String in catalog.warnings:
			push_warning("room_types: %s" % warning)
	return catalog


## Interpreta el texto de un JSON. No escribe nada en la consola (los avisos van en `warnings`).
static func parse(text: String) -> RoomTypeCatalog:
	var catalog := RoomTypeCatalog.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		catalog.warnings.append("JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return catalog
	var root: Variant = json.data
	if typeof(root) != TYPE_DICTIONARY or typeof((root as Dictionary).get("room_types")) != TYPE_ARRAY:
		catalog.warnings.append("se esperaba un objeto con la lista \"room_types\"")
		return catalog

	var entries: Array = (root as Dictionary)["room_types"]
	for i in range(entries.size()):
		if typeof(entries[i]) != TYPE_DICTIONARY:
			catalog.warnings.append("entrada %d: no es un objeto" % i)
			continue
		var errors: Array[String] = []
		var type: RoomType = RoomType.from_dict(entries[i] as Dictionary, errors)
		if type == null:
			for error: String in errors:
				catalog.warnings.append("entrada %d descartada: %s" % [i, error])
		elif catalog._by_id.has(type.id):
			catalog.warnings.append("entrada %d descartada: el id '%s' está repetido" % [i, type.id])
		else:
			catalog._types.append(type)
			catalog._by_id[type.id] = type
	return catalog


func has_type(id: StringName) -> bool:
	return _by_id.has(id)


## El tipo con ese id, o null si no existe.
func get_type(id: StringName) -> RoomType:
	return _by_id.get(id) as RoomType


## Todos los tipos, en el orden del archivo.
func get_types() -> Array[RoomType]:
	return _types.duplicate()
