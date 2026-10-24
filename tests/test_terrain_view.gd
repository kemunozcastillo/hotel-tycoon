extends TestCase
## Pruebas de la vista del terreno: el tile de cada celda, la actualización al cambiar el terreno y
## el arte provisional de los tiles.


func _state_with_layout() -> GameState:
	var state := GameState.new_hotel_game()
	return state


func _view_for(state: GameState) -> LevelView:
	var view := LevelView.new()
	view.setup(state.grid, 0)
	return view


func test_each_terrain_has_its_own_tile_and_none_has_no_tile() -> void:
	var state := _state_with_layout()
	var view := _view_for(state)
	var row: int = TerrainGenerator.sidewalk_row_of(state.grid.size)
	var grass: Vector2i = view.get_terrain_coords(Vector2i(4, 2))
	var sidewalk: Vector2i = view.get_terrain_coords(Vector2i(4, row))
	var street: Vector2i = view.get_terrain_coords(Vector2i(4, row + 1))
	assert_eq(grass, TilesetFactory.terrain_coords(state.grid.terrain.index_of(TerrainGenerator.GRASS)))
	assert_eq(sidewalk, TilesetFactory.terrain_coords(state.grid.terrain.index_of(TerrainGenerator.SIDEWALK)))
	assert_eq(street, TilesetFactory.terrain_coords(state.grid.terrain.index_of(TerrainGenerator.STREET)))
	assert_eq(_distinct([grass, sidewalk, street]), 3, "tres tiles distintos")
	var plain := GameState.new(Vector2i(8, 8))
	var plain_view := _view_for(plain)
	assert_eq(plain_view.get_terrain_coords(Vector2i(2, 2)), Vector2i(-1, -1), "sin terreno no se dibuja nada")
	plain_view.free()
	view.free()


func _distinct(values: Array[Vector2i]) -> int:
	var seen: Dictionary = {}
	for value: Vector2i in values:
		seen[value] = true
	return seen.size()


func test_changing_the_terrain_updates_the_tile() -> void:
	var state := GameState.new(Vector2i(8, 8))
	var view := _view_for(state)
	assert_eq(view.get_terrain_coords(Vector2i(3, 3)), Vector2i(-1, -1))
	var index: int = state.grid.terrain.index_of(TerrainGenerator.GRASS)
	state.grid.set_terrain_index(Vector2i(3, 3), 0, index)
	assert_eq(view.get_terrain_coords(Vector2i(3, 3)), TilesetFactory.terrain_coords(index))
	state.grid.set_terrain_index(Vector2i(3, 3), 0, 0)
	assert_eq(view.get_terrain_coords(Vector2i(3, 3)), Vector2i(-1, -1), "volver a 'sin terreno' lo borra")
	view.free()


func test_the_tileset_has_a_terrain_source_only_with_a_catalog() -> void:
	assert_false(TilesetFactory.build().has_source(TilesetFactory.TERRAIN_SOURCE_ID))
	var catalog: TerrainCatalog = TerrainCatalog.load_default()
	var tile_set: TileSet = TilesetFactory.build(catalog)
	assert_true(tile_set.has_source(TilesetFactory.TERRAIN_SOURCE_ID))
	var source := tile_set.get_source(TilesetFactory.TERRAIN_SOURCE_ID) as TileSetAtlasSource
	assert_eq(source.get_tiles_count(), 3, "un tile por terreno del archivo")
	assert_eq(TilesetFactory.terrain_coords(0), Vector2i(-1, -1))
	assert_eq(TilesetFactory.terrain_coords(1), Vector2i(0, 0))


func test_the_tile_art_is_a_diamond_in_the_terrain_color() -> void:
	var catalog: TerrainCatalog = TerrainCatalog.load_default()
	var tile_set: TileSet = TilesetFactory.build(catalog)
	var source := tile_set.get_source(TilesetFactory.TERRAIN_SOURCE_ID) as TileSetAtlasSource
	var image: Image = source.texture.get_image()
	var types: Array[TerrainType] = catalog.get_types()
	for i in range(types.size()):
		var center: Color = image.get_pixel(i * 64 + 32, 16)
		var wanted: Color = types[i].color
		assert_true(absf(center.r - wanted.r) + absf(center.g - wanted.g) + absf(center.b - wanted.b) < 0.2,
				"el centro de %s tiene su color (%s)" % [types[i].id, str(center)])
		assert_eq(image.get_pixel(i * 64 + 1, 1).a, 0.0, "las esquinas del rombo son transparentes")
		assert_eq(image.get_pixel(i * 64 + 32, 16).a, 1.0)
