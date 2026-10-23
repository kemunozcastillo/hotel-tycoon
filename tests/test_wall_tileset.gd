extends TestCase
## Pruebas del TileSet de paredes: estados de arista, combinaciones y dibujo comprobado por píxeles.

const TILE_W: int = 64

var _tile_set: TileSet = TilesetFactory.build()


func _walls_source() -> TileSetAtlasSource:
	return _tile_set.get_source(TilesetFactory.WALL_SOURCE_ID) as TileSetAtlasSource


## Fila del píxel opaco más alto y más bajo de una columna del atlas ((-1, -1) si no hay ninguno).
func _extent(image: Image, x: int) -> Vector2i:
	var top: int = -1
	var bottom: int = -1
	for y in range(image.get_height()):
		if image.get_pixel(x, y).a > 0.5:
			if top < 0:
				top = y
			bottom = y
	return Vector2i(top, bottom)


func _index(state_x: int, state_y: int) -> int:
	return state_x * TilesetFactory.EDGE_STATE_COUNT + state_y


func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) < 0.08


# --- Estados y coordenadas ------------------------------------------------------------------

func test_wall_style_pixel_heights() -> void:
	assert_eq(WallStyle.pixels(WallStyle.Height.FULL), 48)
	assert_eq(WallStyle.pixels(WallStyle.Height.LOW), 14)
	assert_eq(WallStyle.pixels(WallStyle.Height.FLAT), 3)
	assert_eq(TilesetFactory.WALL_HEIGHT, 48, "la altura completa sigue siendo la de siempre")


func test_edge_states() -> void:
	for height: int in [WallStyle.Height.FULL, WallStyle.Height.LOW, WallStyle.Height.FLAT]:
		assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.NONE, height as WallStyle.Height), 0, "sin nada la altura no importa")
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.FULL), 1)
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.LOW), 2)
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.FLAT), 3)
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.FULL), 4)
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.LOW), 5)
	assert_eq(TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.FLAT), 6)


func test_wall_coords_are_unique_for_every_visible_combination() -> void:
	var seen: Dictionary = {}
	var types: Array[CellTypes.EdgeType] = [CellTypes.EdgeType.NONE, CellTypes.EdgeType.WALL, CellTypes.EdgeType.DOOR]
	var heights: Array[WallStyle.Height] = [WallStyle.Height.FULL, WallStyle.Height.LOW, WallStyle.Height.FLAT]
	var visible_pairs: Dictionary = {}
	for type_x: CellTypes.EdgeType in types:
		for height_x: WallStyle.Height in heights:
			for type_y: CellTypes.EdgeType in types:
				for height_y: WallStyle.Height in heights:
					var coords: Vector2i = TilesetFactory.wall_coords(type_x, height_x, type_y, height_y)
					var state_x: int = TilesetFactory.edge_state(type_x, height_x)
					var state_y: int = TilesetFactory.edge_state(type_y, height_y)
					if state_x == 0 and state_y == 0:
						assert_eq(coords, Vector2i(-1, -1), "nada y nada no se dibuja")
						continue
					visible_pairs[Vector2i(state_x, state_y)] = coords
					seen[coords] = true
	assert_eq(visible_pairs.size(), 48, "48 combinaciones distintas con algo que dibujar")
	assert_eq(seen.size(), 48, "cada una con sus propias coordenadas")
	for coords: Vector2i in seen.keys():
		assert_true(coords.x >= 1 and coords.x <= 48 and coords.y == 0, "dentro del atlas: %s" % str(coords))


func test_tileset_has_all_wall_tiles_with_the_sort_origin() -> void:
	var source: TileSetAtlasSource = _walls_source()
	assert_eq(source.get_tiles_count(), 48)
	assert_eq(source.texture_region_size, TilesetFactory.WALL_TEXTURE_SIZE)
	for index in range(1, 49):
		var data: TileData = source.get_tile_data(Vector2i(index, 0), 0)
		assert_true(data != null, "existe el tile %d" % index)
		if data != null:
			assert_eq(data.y_sort_origin, TilesetFactory.WALL_Y_SORT_ORIGIN, "orden por Y del tile %d" % index)
	assert_eq(source.texture.get_width(), TILE_W * 49)


func test_building_the_tileset_is_fast() -> void:
	var start: int = Time.get_ticks_msec()
	TilesetFactory.build()
	var elapsed: int = Time.get_ticks_msec() - start
	assert_true(elapsed < 2000, "generar el TileSet tarda %d ms (el dibujo por columnas debería ser rápido)" % elapsed)


# --- Dibujo de las paredes ----------------------------------------------------------------------

func test_wall_heights_are_drawn_at_the_expected_rows() -> void:
	var image: Image = _walls_source().texture.get_image()
	# Arista X sola, a media arista (el punto medio de la base queda en la fila ~56).
	var expected_top: Dictionary = {WallStyle.Height.FULL: 8, WallStyle.Height.LOW: 42, WallStyle.Height.FLAT: 53}
	for height: int in expected_top.keys():
		var state: int = TilesetFactory.edge_state(CellTypes.EdgeType.WALL, height as WallStyle.Height)
		var extent: Vector2i = _extent(image, _index(state, 0) * TILE_W + 48)
		assert_true(absi(extent.x - int(expected_top[height])) <= 1, "cima de la altura %d en la fila %d (esperada ~%d)" % [height, extent.x, expected_top[height]])
		assert_true(extent.y >= 54 and extent.y <= 56, "base de la altura %d en la fila %d" % [height, extent.y])
		# Arista Y sola, a media arista.
		var y_extent: Vector2i = _extent(image, _index(0, state) * TILE_W + 16)
		assert_true(absi(y_extent.x - int(expected_top[height])) <= 1, "arista Y: cima de la altura %d en la fila %d" % [height, y_extent.x])


func test_wall_faces_use_the_axis_colors() -> void:
	var image: Image = _walls_source().texture.get_image()
	var full: int = TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.FULL)
	assert_true(_close(image.get_pixel(_index(full, 0) * TILE_W + 48, 30), TilesetFactory.WALL_FACE_X), "cara de la arista X")
	assert_true(_close(image.get_pixel(_index(0, full) * TILE_W + 16, 30), TilesetFactory.WALL_FACE_Y), "cara de la arista Y")


func test_a_tile_draws_both_of_its_edges_with_their_own_heights() -> void:
	var image: Image = _walls_source().texture.get_image()
	var full: int = TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.FULL)
	var low: int = TilesetFactory.edge_state(CellTypes.EdgeType.WALL, WallStyle.Height.LOW)
	var offset: int = _index(full, low) * TILE_W
	var x_side: Vector2i = _extent(image, offset + 48)
	var y_side: Vector2i = _extent(image, offset + 16)
	assert_true(absi(x_side.x - 8) <= 1, "la arista X, completa (%d)" % x_side.x)
	assert_true(absi(y_side.x - 42) <= 1, "la arista Y, baja (%d)" % y_side.x)


func test_doors_leave_a_gap_at_every_height() -> void:
	var image: Image = _walls_source().texture.get_image()
	var full_door: int = TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.FULL)
	var offset: int = _index(full_door, 0) * TILE_W
	assert_true(image.get_pixel(offset + 48, 40).a < 0.1, "hueco de la puerta completa")
	assert_true(image.get_pixel(offset + 48, 10).a > 0.5, "con dintel encima")
	assert_true(image.get_pixel(offset + 35, 40).a > 0.5, "y jamba a un lado")

	var low_door: int = TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.LOW)
	offset = _index(low_door, 0) * TILE_W
	assert_true(image.get_pixel(offset + 48, 50).a < 0.1, "hueco de la puerta baja, sin dintel")
	assert_true(_extent(image, offset + 48).x < 0, "la columna central de la puerta baja está vacía")
	assert_true(image.get_pixel(offset + 35, 44).a > 0.5, "con jamba baja a un lado")

	var flat_door: int = TilesetFactory.edge_state(CellTypes.EdgeType.DOOR, WallStyle.Height.FLAT)
	offset = _index(flat_door, 0) * TILE_W
	assert_true(_close(image.get_pixel(offset + 48, 55), TilesetFactory.DOOR_FRAME), "la puerta plana marca el hueco en madera")
	assert_true(image.get_pixel(offset + 48, 50).a < 0.1, "y no tiene nada más")
