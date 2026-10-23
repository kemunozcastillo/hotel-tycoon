class_name LevelView
extends Node2D
## Representación visual de un nivel de GridMap2D. Solo lee el mapa y reacciona a sus
## señales; nunca modifica la simulación.
##
## Capas (de atrás hacia delante): rejilla, suelo y paredes. Las paredes comparten una sola
## capa con ordenación por Y para que las de delante tapen a las de detrás.

var _grid: GridMap2D
var _level: int = 0
var _lines: GridLines
var _ground: TileMapLayer
var _walls: TileMapLayer


func setup(grid: GridMap2D, level: int) -> void:
	_grid = grid
	_level = level
	var tile_set: TileSet = TilesetFactory.build()

	_lines = GridLines.new()
	add_child(_lines)
	_lines.setup(grid.size)

	_ground = TileMapLayer.new()
	_ground.tile_set = tile_set
	add_child(_ground)

	_walls = TileMapLayer.new()
	_walls.tile_set = tile_set
	_walls.y_sort_enabled = true
	add_child(_walls)

	grid.cell_changed.connect(_on_cell_changed)
	grid.edge_changed.connect(_on_edge_changed)
	_redraw_all()


func _redraw_all() -> void:
	_ground.clear()
	_walls.clear()
	# Las aristas del borde sur/este viven en celdas con x == ancho o y == alto.
	for y in range(_grid.size.y + 1):
		for x in range(_grid.size.x + 1):
			var cell := Vector2i(x, y)
			_update_ground(cell)
			_update_walls(cell)


func _update_ground(cell: Vector2i) -> void:
	if _grid.get_floor_type(cell, _level) == CellTypes.FloorType.NONE:
		_ground.erase_cell(cell)
	else:
		_ground.set_cell(cell, TilesetFactory.GROUND_SOURCE_ID, TilesetFactory.GROUND_BASIC_COORDS)


## Una celda dibuja las paredes que posee: su arista norte (X) y su arista oeste (Y).
func _update_walls(cell: Vector2i) -> void:
	var has_x: bool = _grid.has_wall(Edge.new(cell, Edge.Axis.X), _level)
	var has_y: bool = _grid.has_wall(Edge.new(cell, Edge.Axis.Y), _level)
	if not has_x and not has_y:
		_walls.erase_cell(cell)
		return
	_walls.set_cell(cell, TilesetFactory.WALL_SOURCE_ID, TilesetFactory.wall_coords(has_x, has_y))


func _on_cell_changed(cell: Vector2i, level: int) -> void:
	if level == _level:
		_update_ground(cell)


func _on_edge_changed(edge: Edge, level: int) -> void:
	if level == _level:
		_update_walls(edge.cell)
