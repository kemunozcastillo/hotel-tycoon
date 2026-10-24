class_name TerrainCatalog
extends RefCounted
## Catálogo de terrenos exteriores cargado desde un JSON. Un tipo mal formado se descarta y queda
## anotado en `warnings`; nunca impide arrancar el juego.
##
## El índice 0 es siempre "sin terreno" (`NONE_ID`): no se puede pisar, se puede construir encima y
## no se dibuja. Es lo que había antes de existir el exterior, y lo que tiene cualquier celda de un
## mapa sin trazado (las pruebas). Los tipos del archivo van a partir del índice 1, en su orden; un
## terreno cabe en un byte, así que hay un máximo de 255.
##
## Nota para la exportación: los .json no son recursos de Godot, así que hay que incluir
## `data/*.json` en el filtro de exportación del preset.

const DEFAULT_PATH: String = "res://data/terrain_types.json"
const NONE_ID: StringName = &"none"
const MAX_TYPES: int = 255

## Problemas encontrados al cargar (vacío si todo estaba bien).
var warnings: Array[String] = []

var _types: Array[TerrainType] = [] # índice 0 = sin terreno
var _by_id: Dictionary = {} # id -> índice


func _init() -> void:
	var none := TerrainType.new()
	none.id = NONE_ID
	none.display_name = "Sin terreno"
	none.walkable = false
	none.buildable = true
	none.color = Color(0.0, 0.0, 0.0, 0.0)
	_types.append(none)
	_by_id[NONE_ID] = 0


## Carga data/terrain_types.json y muestra los avisos en la consola.
static func load_default() -> TerrainCatalog:
	return load_file(DEFAULT_PATH)


## Con `report_warnings` los avisos también se escriben en la consola (push_warning).
static func load_file(path: String, report_warnings: bool = true) -> TerrainCatalog:
	var catalog: TerrainCatalog
	if not FileAccess.file_exists(path):
		catalog = TerrainCatalog.new()
		catalog.warnings.append("no existe el archivo de terrenos: %s" % path)
	else:
		catalog = parse(FileAccess.get_file_as_string(path))
	if report_warnings:
		for warning: String in catalog.warnings:
			push_warning("terrain_types: %s" % warning)
	return catalog


## Interpreta el texto de un JSON. No escribe nada en la consola (los avisos van en `warnings`).
static func parse(text: String) -> TerrainCatalog:
	var catalog := TerrainCatalog.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		catalog.warnings.append("JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return catalog
	var root: Variant = json.data
	if typeof(root) != TYPE_DICTIONARY or typeof((root as Dictionary).get("terrain_types")) != TYPE_ARRAY:
		catalog.warnings.append("se esperaba un objeto con la lista \"terrain_types\"")
		return catalog

	var entries: Array = (root as Dictionary)["terrain_types"]
	for i in range(entries.size()):
		if typeof(entries[i]) != TYPE_DICTIONARY:
			catalog.warnings.append("entrada %d: no es un objeto" % i)
			continue
		var errors: Array[String] = []
		var type: TerrainType = TerrainType.from_dict(entries[i] as Dictionary, errors)
		if type == null:
			for error: String in errors:
				catalog.warnings.append("entrada %d descartada: %s" % [i, error])
		elif catalog._by_id.has(type.id):
			catalog.warnings.append("entrada %d descartada: el id '%s' está repetido o reservado" % [i, type.id])
		elif catalog._types.size() > MAX_TYPES:
			catalog.warnings.append("entrada %d descartada: hay demasiados terrenos (máximo %d)" % [i, MAX_TYPES])
		else:
			catalog._by_id[type.id] = catalog._types.size()
			catalog._types.append(type)
	return catalog


## Cuántos terrenos hay, contando "sin terreno".
func count() -> int:
	return _types.size()


## El terreno con ese índice, o el de "sin terreno" si el índice no existe.
func get_by_index(index: int) -> TerrainType:
	if index < 0 or index >= _types.size():
		return _types[0]
	return _types[index]


## El índice del terreno con ese id, o -1 si no existe.
func index_of(id: StringName) -> int:
	return int(_by_id.get(id, -1))


func has_type(id: StringName) -> bool:
	return _by_id.has(id)


## El terreno con ese id, o null si no existe.
func get_type(id: StringName) -> TerrainType:
	if not _by_id.has(id):
		return null
	return _types[_by_id[id]]


## Los terrenos del archivo, en su orden (sin el "sin terreno").
func get_types() -> Array[TerrainType]:
	return _types.slice(1)
