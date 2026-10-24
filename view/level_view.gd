class_name LevelView
extends Node2D
## Representación visual de un nivel de GridMap2D. Solo lee el mapa y reacciona a sus
## señales; nunca modifica la simulación.
##
## Capas (de atrás hacia delante): terreno exterior, rejilla, suelo y un contenedor ordenado por Y
## con las paredes y las entidades (agentes). Las paredes comparten una sola capa con ordenación por
## Y, y las entidades se ordenan con ellas, para que lo que está delante tape a lo que está detrás.
##
## Las paredes se dibujan con la altura que indica el modo de visualización (WallViewMode): en el
## modo corte, las que tapan el interior bajan. Al cambiar de modo se redibujan todas; al cambiar
## el suelo de una celda solo las dos cuyas paredes dependen de ella.

## Cambió el modo de visualización de las paredes.
signal wall_mode_changed(mode: WallViewMode.Mode)

var _wall_mode: WallViewMode.Mode = WallViewMode.default_mode()
var _grid: GridMap2D
var _level: int = 0
var _terrain: TileMapLayer
var _lines: GridLines
var _ground: TileMapLayer
var _entities: Node2D
var _walls: TileMapLayer


func setup(grid: GridMap2D, level: int) -> void:
	_grid = grid
	_level = level
	var tile_set: TileSet = TilesetFactory.build(grid.terrain)

	_terrain = TileMapLayer.new()
	_terrain.tile_set = tile_set
	add_child(_terrain)

	_lines = GridLines.new()
	add_child(_lines)
	_lines.setup(grid.size)

	_ground = TileMapLayer.new()
	_ground.tile_set = tile_set
	add_child(_ground)

	_entities = Node2D.new()
	_entities.y_sort_enabled = true
	add_child(_entities)

	_walls = TileMapLayer.new()
	_walls.tile_set = tile_set
	_walls.y_sort_enabled = true
	_entities.add_child(_walls)

	grid.cell_changed.connect(_on_cell_changed)
	grid.edge_changed.connect(_on_edge_changed)
	grid.terrain_changed.connect(_on_terrain_changed)
	_redraw_all()


func get_wall_mode() -> WallViewMode.Mode:
	return _wall_mode


## Cambia el modo de visualización de las paredes y las redibuja.
func set_wall_mode(mode: WallViewMode.Mode) -> void:
	if mode == _wall_mode:
		return
	_wall_mode = mode
	for y in range(_grid.size.y + 1):
		for x in range(_grid.size.x + 1):
			_update_walls(Vector2i(x, y))
	wall_mode_changed.emit(mode)


## Coordenadas de atlas del tile de pared de una celda ((-1, -1) si no hay ninguno). Es lo que se
## está mostrando de verdad; sirve para comprobar la vista.
func get_wall_coords(cell: Vector2i) -> Vector2i:
	return _walls.get_cell_atlas_coords(cell)


## Añade un nodo que se dibuja sobre el suelo pero por debajo de las paredes.
func add_ground_overlay(node: Node2D) -> void:
	add_child(node)
	move_child(node, _entities.get_index())


## Nodo donde van las entidades (agentes): se ordenan por la Y de su posición junto con las
## paredes. Su posición debe ser el punto de los pies sobre el suelo.
func get_entities_root() -> Node2D:
	return _entities


func _redraw_all() -> void:
	_terrain.clear()
	_ground.clear()
	_walls.clear()
	# Las aristas del borde sur/este viven en celdas con x == ancho o y == alto.
	for y in range(_grid.size.y + 1):
		for x in range(_grid.size.x + 1):
			var cell := Vector2i(x, y)
			_update_terrain(cell)
			_update_ground(cell)
			_update_walls(cell)


func _update_terrain(cell: Vector2i) -> void:
	var coords: Vector2i = TilesetFactory.terrain_coords(_grid.get_terrain_index(cell, _level))
	if coords.x < 0 or not _grid.in_bounds(cell):
		_terrain.erase_cell(cell)
	else:
		_terrain.set_cell(cell, TilesetFactory.TERRAIN_SOURCE_ID, coords)


## Coordenadas de atlas del tile de terreno de una celda ((-1, -1) si no hay ninguno).
func get_terrain_coords(cell: Vector2i) -> Vector2i:
	return _terrain.get_cell_atlas_coords(cell)


func _update_ground(cell: Vector2i) -> void:
	if _grid.get_floor_type(cell, _level) == CellTypes.FloorType.NONE:
		_ground.erase_cell(cell)
	else:
		_ground.set_cell(cell, TilesetFactory.GROUND_SOURCE_ID, TilesetFactory.GROUND_BASIC_COORDS)


## Una celda dibuja las paredes y puertas que posee: su arista norte (X) y su arista oeste (Y),
## cada una con la altura que le toca en el modo actual.
func _update_walls(cell: Vector2i) -> void:
	var edge_x := Edge.new(cell, Edge.Axis.X)
	var edge_y := Edge.new(cell, Edge.Axis.Y)
	var type_x: CellTypes.EdgeType = _grid.get_edge_type(edge_x, _level)
	var type_y: CellTypes.EdgeType = _grid.get_edge_type(edge_y, _level)
	var coords: Vector2i = TilesetFactory.wall_coords(
			type_x, _height_of(edge_x, type_x), type_y, _height_of(edge_y, type_y))
	if coords.x < 0:
		_walls.erase_cell(cell)
		return
	_walls.set_cell(cell, TilesetFactory.WALL_SOURCE_ID, coords)


## Altura de una arista; si no hay nada sobre ella no importa (se usa la completa).
func _height_of(edge: Edge, type: CellTypes.EdgeType) -> WallStyle.Height:
	if type == CellTypes.EdgeType.NONE:
		return WallStyle.Height.FULL
	return WallVisibility.height_for(_grid, _level, edge, _wall_mode)


func _on_cell_changed(cell: Vector2i, level: int) -> void:
	if level != _level:
		return
	_update_ground(cell)
	# En el modo corte, el suelo de una celda decide la altura de las paredes que tiene delante.
	if _wall_mode == WallViewMode.Mode.CUTAWAY:
		for wall_cell: Vector2i in WallVisibility.dependent_wall_cells(cell):
			_update_walls(wall_cell)


func _on_terrain_changed(cell: Vector2i, level: int) -> void:
	if level == _level:
		_update_terrain(cell)


func _on_edge_changed(edge: Edge, level: int) -> void:
	if level == _level:
		_update_walls(edge.cell)
