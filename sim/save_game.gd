class_name SaveGame
extends RefCounted
## Guardar y cargar la partida entera. El archivo es un JSON legible con una `version`; contiene
## todo el estado de la simulación (mapa, habitaciones, dinero, inventario, reloj, agentes,
## huéspedes y el estado de cada generador de azar, para que una partida cargada siga exactamente
## igual que la original). No contiene las reglas ni el catálogo de tipos (se leen de data/*.json)
## ni nada de la vista (cámara, herramienta, paneles).
##
## Cargar no modifica ningún estado: construye un `GameState` nuevo y lo devuelve; si el archivo
## está roto, devuelve los errores y no hay nada que sustituir.
##
## Para cambiar el formato: sube `VERSION` y añade en `migrate` el paso de la versión anterior.

const VERSION: int = 1
const GAME_ID: String = "hotel-tycoon"
const SAVE_DIR: String = "user://saves"
const MANUAL_SLOT: StringName = &"manual"
const AUTO_SLOT: StringName = &"auto"
## Lado máximo de mapa que se acepta al cargar (cota de cordura).
const MAX_MAP_SIDE: int = 256


## Resultado de cargar: o `state`, o los `errors`.
class LoadResult:
	var state: GameState = null
	var errors: Array[String] = []
	var warnings: Array[String] = []

	func is_ok() -> bool:
		return state != null


# --- Estado <-> diccionario --------------------------------------------------------------------------

static func serialize(state: GameState) -> Dictionary:
	return {
		"game": GAME_ID,
		"version": VERSION,
		"map_size": SaveReader.vec2i_data(state.grid.size),
		"clock": state.clock.serialize(),
		"grid": state.grid.serialize(),
		"rooms": state.rooms.serialize(),
		"pieces": state.pieces.serialize(),
		"ledger": state.ledger.serialize(),
		"inventory": state.inventory.serialize(),
		"entrances": state.entrances.serialize(),
		"agents": state.agents.serialize(),
		"guests": state.guests.serialize(),
		"spawner": state.spawner.serialize(),
		"wander": state.wander.serialize(),
		"economy": state.economy.serialize(),
	}


## El texto del archivo. Los decimales se escriben con toda su precisión.
static func to_text(data: Dictionary) -> String:
	return JSON.stringify(data, "\t", true, true)


## Interpreta el texto de un archivo. Devuelve un diccionario vacío y un error si no es JSON válido.
static func parse_text(text: String, errors: Array[String]) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("el archivo no es un JSON válido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return {}
	if typeof(json.data) != TYPE_DICTIONARY:
		errors.append("el archivo no contiene una partida")
		return {}
	return json.data as Dictionary


## Pasa los datos de una versión antigua a la actual. Hoy solo existe la versión 1.
static func migrate(data: Dictionary, _from_version: int) -> Dictionary:
	return data


## Construye un `GameState` nuevo con lo guardado. Usa las reglas y el catálogo indicados (por
## defecto, el de data/room_types.json). Si algo no cuadra devuelve los errores y ningún estado.
static func restore(data: Dictionary, rules: EconomyRules, catalog: RoomTypeCatalog = null) -> LoadResult:
	var result := LoadResult.new()
	var reader := SaveReader.new()

	if typeof(data.get("game")) != TYPE_STRING or data["game"] != GAME_ID:
		result.errors.append("no es una partida de Hotel Tycoon")
		return result
	var version: int = reader.read_int(data, "version", "partida", 1)
	if version > VERSION:
		result.errors.append("la partida es de una versión más nueva (%d) que este juego (%d)" % [version, VERSION])
		return result
	if version < VERSION:
		data = migrate(data, version)
	var map_size: Vector2i = reader.read_vec2i(data, "map_size", "partida")
	if map_size.x < 1 or map_size.y < 1 or map_size.x > MAX_MAP_SIDE or map_size.y > MAX_MAP_SIDE:
		reader.fail("partida: el tamaño del mapa %s no es válido" % str(map_size))
	if not reader.is_ok():
		return _fail(result, reader)

	var state := GameState.new(map_size, catalog, rules)
	state.clock.restore(reader.read_dict(data, "clock", "partida"), reader)
	state.grid.restore(reader.read_dict(data, "grid", "partida"), reader)
	if not reader.is_ok():
		return _fail(result, reader)
	state.rooms.restore(reader.read_dict(data, "rooms", "partida"), reader)
	state.pieces.restore(reader.read_dict(data, "pieces", "partida"), reader)
	state.ledger.restore(reader.read_dict(data, "ledger", "partida"), reader)
	state.inventory.restore(reader.read_dict(data, "inventory", "partida"), reader)
	state.entrances.restore(reader.read_dict(data, "entrances", "partida"), reader)
	state.agents.restore(reader.read_dict(data, "agents", "partida"), reader)
	state.guests.restore(reader.read_dict(data, "guests", "partida"), reader)
	state.spawner.restore(reader.read_dict(data, "spawner", "partida"), reader)
	state.wander.restore(reader.read_dict(data, "wander", "partida"), reader)
	state.economy.restore(reader.read_dict(data, "economy", "partida"), reader)
	if not reader.is_ok():
		return _fail(result, reader)
	state.storage.sync()
	result.state = state
	result.warnings = reader.warnings
	return result


static func _fail(result: LoadResult, reader: SaveReader) -> LoadResult:
	result.errors = reader.errors
	result.warnings = reader.warnings
	return result


# --- Archivos ----------------------------------------------------------------------------------------

static func slot_path(slot: StringName, directory: String = SAVE_DIR) -> String:
	return "%s/%s.json" % [directory, str(slot)]


static func has_slot(slot: StringName, directory: String = SAVE_DIR) -> bool:
	return FileAccess.file_exists(slot_path(slot, directory))


## Guarda la partida en una ranura. Devuelve "" si fue bien, o el motivo del fallo. Escribe primero
## un archivo temporal y lo renombra, así un fallo a medias no destruye la partida anterior.
static func save_slot(state: GameState, slot: StringName, directory: String = SAVE_DIR) -> String:
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "no se pudo crear la carpeta de partidas"
	var path: String = slot_path(slot, directory)
	var temp_path: String = path + ".tmp"
	var file: FileAccess = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return "no se pudo escribir el archivo (error %d)" % FileAccess.get_open_error()
	file.store_string(to_text(serialize(state)))
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(temp_path)
		return "falló la escritura del archivo (error %d)" % write_error
	if DirAccess.rename_absolute(temp_path, path) != OK:
		DirAccess.remove_absolute(temp_path)
		return "no se pudo reemplazar la partida anterior"
	return ""


## Carga una ranura. No cambia ningún estado: el resultado trae el `GameState` nuevo o los errores.
static func load_slot(slot: StringName, rules: EconomyRules, catalog: RoomTypeCatalog = null,
		directory: String = SAVE_DIR) -> LoadResult:
	var path: String = slot_path(slot, directory)
	if not FileAccess.file_exists(path):
		var missing := LoadResult.new()
		missing.errors.append("no hay ninguna partida guardada")
		return missing
	var result := LoadResult.new()
	var data: Dictionary = parse_text(FileAccess.get_file_as_string(path), result.errors)
	if not result.errors.is_empty():
		return result
	return restore(data, rules, catalog)
