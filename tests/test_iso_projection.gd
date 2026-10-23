extends TestCase
## IsoProjection debe coincidir con el TileMapLayer real. Los nodos funcionan sin ventana.

const SAMPLE_CELLS: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(5, 3), Vector2i(3, 5),
	Vector2i(31, 31), Vector2i(-4, 7), Vector2i(12, -9), Vector2i(-6, -6),
]


func test_cell_to_world_matches_tilemaplayer() -> void:
	var layer: TileMapLayer = _make_layer()
	for cell: Vector2i in SAMPLE_CELLS:
		assert_eq(IsoProjection.cell_to_world(cell), layer.map_to_local(cell), "celda %s" % str(cell))
	layer.free()


func test_world_to_cell_matches_tilemaplayer() -> void:
	var layer: TileMapLayer = _make_layer()
	# Puntos dentro de cada rombo (centro y desplazamientos que no tocan el borde).
	var offsets: Array[Vector2] = [
		Vector2.ZERO, Vector2(10, 0), Vector2(-10, 0), Vector2(0, 6), Vector2(0, -6), Vector2(14, 4), Vector2(-14, -4),
	]
	for cell: Vector2i in SAMPLE_CELLS:
		var center: Vector2 = layer.map_to_local(cell)
		for offset: Vector2 in offsets:
			var point: Vector2 = center + offset
			assert_eq(IsoProjection.world_to_cell(point), layer.local_to_map(point), "celda %s + %s" % [str(cell), str(offset)])
			assert_eq(IsoProjection.world_to_cell(point), cell, "el punto cae en su propia celda")
	layer.free()


func test_grid_round_trip() -> void:
	for grid_pos: Vector2 in [Vector2(0, 0), Vector2(3.25, 7.75), Vector2(-2.5, 4.1), Vector2(10, -3)]:
		var back: Vector2 = IsoProjection.world_to_grid(IsoProjection.grid_to_world(grid_pos))
		assert_near(back.x, grid_pos.x, "x de %s" % str(grid_pos))
		assert_near(back.y, grid_pos.y, "y de %s" % str(grid_pos))


func test_cell_center_in_grid_space() -> void:
	for cell: Vector2i in SAMPLE_CELLS:
		var center_grid := Vector2(cell) + Vector2(0.5, 0.5)
		assert_eq(IsoProjection.grid_to_world(center_grid), IsoProjection.cell_to_world(cell))


func test_diamond_and_edge_endpoints() -> void:
	var cell := Vector2i(4, 2)
	var center: Vector2 = IsoProjection.cell_to_world(cell)
	var diamond: PackedVector2Array = IsoProjection.cell_diamond(cell)
	assert_eq(diamond[0], center + Vector2(0, -16), "vértice superior")
	assert_eq(diamond[1], center + Vector2(32, 0), "vértice derecho")
	assert_eq(diamond[2], center + Vector2(0, 16), "vértice inferior")
	assert_eq(diamond[3], center + Vector2(-32, 0), "vértice izquierdo")
	# La arista norte (X) es el borde superior-derecho; la oeste (Y), el superior-izquierdo.
	var north: PackedVector2Array = IsoProjection.edge_endpoints(Edge.from_side(cell, Edge.Side.NORTH))
	assert_eq(north[0], diamond[0])
	assert_eq(north[1], diamond[1])
	var west: PackedVector2Array = IsoProjection.edge_endpoints(Edge.from_side(cell, Edge.Side.WEST))
	assert_eq(west[0], diamond[0])
	assert_eq(west[1], diamond[3])


func test_tileset_has_expected_sources() -> void:
	var tile_set: TileSet = TilesetFactory.build()
	assert_eq(tile_set.tile_size, Vector2i(64, 32))
	assert_true(tile_set.has_source(TilesetFactory.GROUND_SOURCE_ID))
	assert_true(tile_set.has_source(TilesetFactory.WALL_SOURCE_ID))
	var walls: TileSetAtlasSource = tile_set.get_source(TilesetFactory.WALL_SOURCE_ID) as TileSetAtlasSource
	assert_eq(walls.get_tiles_count(), 8, "combinaciones de arista X/Y con algo que dibujar")


func _make_layer() -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.tile_set = TilesetFactory.build()
	return layer
