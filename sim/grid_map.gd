class_name GridMap2D
extends RefCounted
## Mapa de cuadrícula del edificio con soporte de varios niveles (pisos).
## Una celda es un Vector2i; el nivel es un int aparte (0 = planta baja,
## negativos = sótanos). Solo guarda y consulta datos; no conoce ninguna vista.

## El suelo de una celda cambió.
signal cell_changed(cell: Vector2i, level: int)
## Una pared (arista) cambió.
signal edge_changed(edge: Edge, level: int)
## Se creó un nivel nuevo.
signal level_added(level: int)

var size: Vector2i

## Contador que sube con cada cambio del mapa (suelo, paredes, puertas o niveles). Permite a
## quien guarda un resultado derivado (como una ruta) saber si sigue siendo válido.
var revision: int = 0

var _levels: Dictionary = {} # int -> LevelLayer


## El nivel 0 siempre existe.
func _init(p_size: Vector2i) -> void:
	size = p_size
	add_level(0)


## Crea un nivel vacío. Devuelve false si ya existía.
func add_level(level: int) -> bool:
	if _levels.has(level):
		return false
	_levels[level] = LevelLayer.new(size)
	revision += 1
	level_added.emit(level)
	return true


func has_level(level: int) -> bool:
	return _levels.has(level)


func get_levels() -> Array[int]:
	var result: Array[int] = []
	for level: int in _levels.keys():
		result.append(level)
	result.sort()
	return result


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


## Una arista es válida si cae dentro del perímetro del mapa (incluido su borde sur/este).
func is_edge_valid(edge: Edge, level: int) -> bool:
	return has_level(level) and _layer(level).in_bounds_edge(edge)


func get_floor_type(cell: Vector2i, level: int) -> CellTypes.FloorType:
	if not has_level(level):
		return CellTypes.FloorType.NONE
	return _layer(level).get_floor_type(cell)


## Devuelve true si el suelo cambió (y entonces emite cell_changed).
func set_floor_type(cell: Vector2i, level: int, type: CellTypes.FloorType) -> bool:
	if not has_level(level):
		return false
	if not _layer(level).set_floor_type(cell, type):
		return false
	revision += 1
	cell_changed.emit(cell, level)
	return true


func get_edge_type(edge: Edge, level: int) -> CellTypes.EdgeType:
	if not has_level(level):
		return CellTypes.EdgeType.NONE
	return _layer(level).get_edge_type(edge)


## Devuelve true si la arista cambió de tipo (y entonces emite edge_changed).
func set_edge_type(edge: Edge, level: int, type: CellTypes.EdgeType) -> bool:
	if not has_level(level):
		return false
	if not _layer(level).set_edge_type(edge, type):
		return false
	revision += 1
	edge_changed.emit(edge, level)
	return true


func has_wall(edge: Edge, level: int) -> bool:
	return get_edge_type(edge, level) == CellTypes.EdgeType.WALL


func has_door(edge: Edge, level: int) -> bool:
	return get_edge_type(edge, level) == CellTypes.EdgeType.DOOR


## Atajo: `on` pone una pared (sustituyendo una puerta si la hubiera); `off` solo quita una
## pared, nunca una puerta.
func set_wall(edge: Edge, level: int, on: bool) -> bool:
	if on:
		return set_edge_type(edge, level, CellTypes.EdgeType.WALL)
	if not has_wall(edge, level):
		return false
	return set_edge_type(edge, level, CellTypes.EdgeType.NONE)


## Única función que decide si una celda se puede pisar. Hoy: tiene suelo construido. Cuando
## exista un terreno predefinido (calle, acera, pasto) se ampliará aquí, sin tocar a quien
## pregunta (pathfinder, agentes).
func is_walkable(cell: Vector2i, level: int) -> bool:
	return has_level(level) and in_bounds(cell) and get_floor_type(cell, level) != CellTypes.FloorType.NONE


## Coste de pisar la celda, como multiplicador de la distancia (1.0 = normal; debe ser >= 1.0).
## Hoy siempre 1.0; el terreno futuro lo variará (preferir la acera al pasto, por ejemplo).
func get_walk_cost(_cell: Vector2i, _level: int) -> float:
	return 1.0


## true si no se puede pasar de `a` a `b`: solo lo bloquea una pared (las puertas se cruzan).
## Cualquier celda fuera del mapa, un nivel inexistente o un par de celdas no contiguas
## cuentan como bloqueados.
func is_blocked_between(a: Vector2i, b: Vector2i, level: int) -> bool:
	if not has_level(level) or not in_bounds(a) or not in_bounds(b):
		return true
	var edge: Edge = Edge.between(a, b)
	if edge == null:
		return true
	return has_wall(edge, level)


## true si entre `a` y `b` hay algo que separa habitaciones (pared o puerta). A diferencia de
## is_blocked_between, una celda vecina fuera del mapa NO cuenta como separada: solo la
## separa una pared o puerta en el borde. Las celdas no contiguas no están separadas.
func is_room_boundary(a: Vector2i, b: Vector2i, level: int) -> bool:
	if not has_level(level):
		return false
	var edge: Edge = Edge.between(a, b)
	if edge == null:
		return false
	return get_edge_type(edge, level) != CellTypes.EdgeType.NONE


func _layer(level: int) -> LevelLayer:
	return _levels[level] as LevelLayer


# --- Guardado -----------------------------------------------------------------------------------

func serialize() -> Dictionary:
	var levels: Dictionary = {}
	for level: int in get_levels():
		levels[str(level)] = _layer(level).serialize()
	return {"size": SaveReader.vec2i_data(size), "revision": revision, "levels": levels}


## Rellena el mapa (que debe tener el mismo tamaño) con lo guardado. No emite señales de celdas o
## aristas: se usa sobre un estado recién creado, antes de que nadie lo mire. La revisión se
## restaura también, porque las rutas guardadas de los agentes se refieren a ella.
func restore(data: Dictionary, reader: SaveReader) -> void:
	var saved_size: Vector2i = reader.read_vec2i(data, "size", "mapa")
	if saved_size != size:
		reader.fail("mapa: el tamaño guardado %s no coincide con %s" % [str(saved_size), str(size)])
		return
	var saved_revision: int = reader.read_int(data, "revision", "mapa", 0)
	var levels: Dictionary = reader.read_dict(data, "levels", "mapa")
	if levels.is_empty():
		reader.fail("mapa: no hay ningún nivel")
		return
	for key: Variant in levels.keys():
		if typeof(key) != TYPE_STRING or not (key as String).is_valid_int():
			reader.fail("mapa: nivel inválido '%s'" % str(key))
			continue
		var level: int = (key as String).to_int()
		if absi(level) > 64:
			reader.fail("mapa: nivel fuera de rango (%d)" % level)
			continue
		var layer_data: Dictionary = reader.as_dict(levels[key], "mapa.levels[%d]" % level)
		if layer_data.is_empty():
			continue
		add_level(level)
		_layer(level).restore(layer_data, reader, "mapa.levels[%d]" % level)
	revision = saved_revision
