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
## El terreno de una celda cambió.
signal terrain_changed(cell: Vector2i, level: int)

var size: Vector2i
## Los terrenos exteriores que existen (calle, acera, césped...). Una celda sin terreno se comporta
## como antes de haber exterior: solo se puede pisar si tiene suelo construido.
var terrain: TerrainCatalog

## Contador que sube con cada cambio del mapa (suelo, paredes, puertas o niveles). Permite a
## quien guarda un resultado derivado (como una ruta) saber si sigue siendo válido.
var revision: int = 0

var _levels: Dictionary = {} # int -> LevelLayer


## El nivel 0 siempre existe.
func _init(p_size: Vector2i, p_terrain: TerrainCatalog = null) -> void:
	size = p_size
	terrain = p_terrain if p_terrain != null else TerrainCatalog.new()
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


## Índice (TerrainCatalog) del terreno de la celda; 0 = sin terreno.
func get_terrain_index(cell: Vector2i, level: int) -> int:
	if not has_level(level):
		return 0
	return _layer(level).get_terrain(cell)


## El tipo de terreno de la celda ("sin terreno" si no hay).
func get_terrain_type(cell: Vector2i, level: int) -> TerrainType:
	return terrain.get_by_index(get_terrain_index(cell, level))


## Devuelve true si el terreno cambió (y entonces emite terrain_changed).
func set_terrain_index(cell: Vector2i, level: int, index: int) -> bool:
	if not has_level(level) or index >= terrain.count():
		return false
	if not _layer(level).set_terrain(cell, index):
		return false
	revision += 1
	terrain_changed.emit(cell, level)
	return true


## Única función que decide si una celda se puede pisar: tiene suelo construido o su terreno es
## caminable. Pathfinder, agentes y paseo preguntan solo aquí.
func is_walkable(cell: Vector2i, level: int) -> bool:
	if not has_level(level) or not in_bounds(cell):
		return false
	return get_floor_type(cell, level) != CellTypes.FloorType.NONE or get_terrain_type(cell, level).walkable


## Coste de pisar la celda, como multiplicador de la distancia (1.0 = normal; siempre >= 1.0). Con
## suelo construido es 1.0; si no, el del terreno (la calle cuesta más que la acera).
func get_walk_cost(cell: Vector2i, level: int) -> float:
	if get_floor_type(cell, level) != CellTypes.FloorType.NONE:
		return 1.0
	return maxf(get_terrain_type(cell, level).cost, 1.0)


## true si se puede construir suelo (y paredes) en la celda: está en el mapa y su terreno lo permite.
func is_buildable_cell(cell: Vector2i, level: int) -> bool:
	return has_level(level) and in_bounds(cell) and get_terrain_type(cell, level).buildable


## true si se puede construir en la arista: basta con que una de las dos celdas que separa se pueda
## construir (así una puerta puede dar de un edificio sobre césped a la acera, que no se construye).
func is_buildable_edge(edge: Edge, level: int) -> bool:
	if not is_edge_valid(edge, level):
		return false
	var other: Vector2i = edge.cell + (Vector2i(0, -1) if edge.axis == Edge.Axis.X else Vector2i(-1, 0))
	return is_buildable_cell(edge.cell, level) or is_buildable_cell(other, level)


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
	# La paleta explica los índices de terreno guardados: así el archivo sigue valiendo si cambia el
	# orden de data/terrain_types.json.
	var palette: Array = [str(TerrainCatalog.NONE_ID)]
	for type: TerrainType in terrain.get_types():
		palette.append(str(type.id))
	return {"size": SaveReader.vec2i_data(size), "revision": revision, "levels": levels, "terrain_palette": palette}


## Rellena el mapa (que debe tener el mismo tamaño) con lo guardado. No emite señales de celdas o
## aristas: se usa sobre un estado recién creado, antes de que nadie lo mire. La revisión se
## restaura también, porque las rutas guardadas de los agentes se refieren a ella. Con
## `has_terrain` false (partidas de la versión 1) el mapa queda sin terreno. Un terreno que ya no
## existe en el catálogo se queda sin terreno, con un aviso.
func restore(data: Dictionary, reader: SaveReader, has_terrain: bool = true) -> void:
	var saved_size: Vector2i = reader.read_vec2i(data, "size", "mapa")
	if saved_size != size:
		reader.fail("mapa: el tamaño guardado %s no coincide con %s" % [str(saved_size), str(size)])
		return
	var saved_revision: int = reader.read_int(data, "revision", "mapa", 0)
	var levels: Dictionary = reader.read_dict(data, "levels", "mapa")
	if levels.is_empty():
		reader.fail("mapa: no hay ningún nivel")
		return
	var remap := PackedByteArray()
	if has_terrain:
		remap = _read_terrain_remap(data, reader)
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
		_layer(level).restore(layer_data, reader, "mapa.levels[%d]" % level, remap)
	revision = saved_revision


## Para cada índice de la paleta guardada, el índice del mismo terreno en el catálogo actual.
func _read_terrain_remap(data: Dictionary, reader: SaveReader) -> PackedByteArray:
	var remap := PackedByteArray()
	var palette: Array = reader.read_array(data, "terrain_palette", "mapa")
	if palette.is_empty() or palette.size() > TerrainCatalog.MAX_TYPES + 1:
		reader.fail("mapa: la paleta de terrenos debe tener entre 1 y %d ids" % (TerrainCatalog.MAX_TYPES + 1))
		return remap
	for i in range(palette.size()):
		if typeof(palette[i]) != TYPE_STRING:
			reader.fail("mapa.terrain_palette[%d] debe ser texto" % i)
			remap.append(0)
			continue
		var id := StringName(palette[i] as String)
		var index: int = terrain.index_of(id)
		if index < 0:
			reader.warn("el terreno '%s' ya no existe: esas celdas quedan sin terreno" % str(id))
			index = 0
		remap.append(index)
	return remap
