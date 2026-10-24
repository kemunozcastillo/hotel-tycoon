class_name TilesetFactory
extends RefCounted
## Genera por código el TileSet isométrico con arte provisional (sin assets externos).
##
## - Fuente GROUND: un rombo de 64x32 por tipo de suelo.
## - Fuente WALL: paneles sobre las aristas norte (eje X) y oeste (eje Y) de la celda. Cada
##   arista puede estar en 7 estados visuales: nada, o pared / puerta en cada una de las tres
##   alturas (WallStyle.Height). Una celda posee dos aristas, así que hay un tile por combinación
##   (7 x 7 = 49; la de "nada y nada" no se dibuja: quedan 48). La textura es alta y tiene el
##   rombo de la celda en su centro (con relleno transparente debajo), para que el tile quede
##   alineado sin tocar `texture_origin`.
##
## Los paneles son paralelogramos con lados verticales, así que se dibujan rellenando columnas
## de píxeles (fill_rect), no probando cada píxel contra un polígono: con 48 tiles lo segundo
## tardaría del orden de un segundo al arrancar.

const GROUND_SOURCE_ID: int = 0
const WALL_SOURCE_ID: int = 1
const TERRAIN_SOURCE_ID: int = 2

const GROUND_BASIC_COORDS: Vector2i = Vector2i(0, 0)

## Altura completa de una pared (la que usan los fantasmas de construcción y las etiquetas).
const WALL_HEIGHT: int = WallStyle.FULL_PIXELS
## Desplazamiento del punto de ordenación por Y de los tiles de pared (hacia el punto medio de
## sus aristas, que está 8 px por encima del centro de la celda).
const WALL_Y_SORT_ORIGIN: int = -8
const WALL_TEXTURE_SIZE: Vector2i = Vector2i(64, 32 + 2 * WALL_HEIGHT)
# Puerta: el hueco ocupa de DOOR_START a DOOR_END del largo de la arista y DOOR_HEIGHT de alto.
const DOOR_START: float = 0.22
const DOOR_END: float = 0.78
const DOOR_HEIGHT: int = 36
const DOOR_FRAME_THICKNESS: float = 0.05
# Grosor de la franja oscura de la base y de la franja clara de arriba, en píxeles.
const BASE_STRIP: int = 2
const CAP_STRIP: int = 3

const GROUND_FILL: Color = Color(0.78, 0.70, 0.56)
const GROUND_BORDER: Color = Color(0.52, 0.45, 0.35)
const WALL_FACE_X: Color = Color(0.88, 0.86, 0.82)
const WALL_FACE_Y: Color = Color(0.72, 0.70, 0.67)
const WALL_CAP: Color = Color(0.97, 0.96, 0.94)
const WALL_BASE: Color = Color(0.40, 0.37, 0.35)
const DOOR_FRAME: Color = Color(0.45, 0.30, 0.18)

## Estados visuales de una arista: 0 = nada; 1..3 = pared FULL/LOW/FLAT; 4..6 = puerta FULL/LOW/FLAT.
const EDGE_STATE_COUNT: int = 7
const HEIGHT_COUNT: int = 3


## Con un catálogo de terrenos, añade además una fuente con un rombo por terreno (los tiles del
## exterior); sin catálogo no hay fuente de terreno.
static func build(terrain: TerrainCatalog = null) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = IsoProjection.TILE_SIZE
	tile_set.add_source(_build_ground_source(), GROUND_SOURCE_ID)
	tile_set.add_source(_build_wall_source(), WALL_SOURCE_ID)
	if terrain != null and terrain.count() > 1:
		tile_set.add_source(_build_terrain_source(terrain), TERRAIN_SOURCE_ID)
	return tile_set


## Coordenadas de atlas del tile de un terreno (su índice del catálogo menos 1: el 0 es "sin
## terreno" y no se dibuja). (-1, -1) si no hay nada que dibujar.
static func terrain_coords(index: int) -> Vector2i:
	if index <= 0:
		return Vector2i(-1, -1)
	return Vector2i(index - 1, 0)


## Estado visual de una arista según lo que hay sobre ella y la altura con que se dibuja.
static func edge_state(type: CellTypes.EdgeType, height: WallStyle.Height) -> int:
	match type:
		CellTypes.EdgeType.WALL:
			return 1 + height
		CellTypes.EdgeType.DOOR:
			return 1 + HEIGHT_COUNT + height
		_:
			return 0


## Coordenadas de atlas del tile de una celda según sus dos aristas: la norte (X) y la oeste (Y),
## cada una con su tipo y su altura. Devuelve (-1, -1) si no hay nada que dibujar.
static func wall_coords(type_x: CellTypes.EdgeType, height_x: WallStyle.Height,
		type_y: CellTypes.EdgeType, height_y: WallStyle.Height) -> Vector2i:
	var index: int = edge_state(type_x, height_x) * EDGE_STATE_COUNT + edge_state(type_y, height_y)
	if index == 0:
		return Vector2i(-1, -1)
	return Vector2i(index, 0)


static func _build_ground_source() -> TileSetAtlasSource:
	var size: Vector2i = IsoProjection.TILE_SIZE
	var image: Image = Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(size) * 0.5
	for y in range(size.y):
		for x in range(size.x):
			# Distancia "de rombo": 1.0 justo en el borde del rombo.
			var d: float = absf(x + 0.5 - half.x) / half.x + absf(y + 0.5 - half.y) / half.y
			if d <= 1.0:
				image.set_pixel(x, y, GROUND_BORDER if d > 0.92 else GROUND_FILL)
	var source := _make_source(image, size)
	source.create_tile(GROUND_BASIC_COORDS)
	return source


## Un rombo por terreno del catálogo, en fila. El arte es provisional: el color del terreno con un
## borde algo más oscuro y un detalle suave (matas en el césped, juntas en la acera).
static func _build_terrain_source(terrain: TerrainCatalog) -> TileSetAtlasSource:
	var size: Vector2i = IsoProjection.TILE_SIZE
	var types: Array[TerrainType] = terrain.get_types()
	var image: Image = Image.create_empty(size.x * types.size(), size.y, false, Image.FORMAT_RGBA8)
	var half := Vector2(size) * 0.5
	for i in range(types.size()):
		var color: Color = types[i].color
		var border: Color = color.darkened(0.14)
		for y in range(size.y):
			for x in range(size.x):
				var d: float = absf(x + 0.5 - half.x) / half.x + absf(y + 0.5 - half.y) / half.y
				if d > 1.0:
					continue
				var pixel: Color = border if d > 0.94 else color
				if d <= 0.94 and d > 0.12:
					pixel = _terrain_detail(types[i].id, pixel, x, y)
				image.set_pixel(i * size.x + x, y, pixel)
	var source: TileSetAtlasSource = _make_source(image, size)
	for i in range(types.size()):
		source.create_tile(Vector2i(i, 0))
	return source


## Un pequeño detalle de textura según el terreno, para que no sea un color plano.
static func _terrain_detail(id: StringName, color: Color, x: int, y: int) -> Color:
	var hash_value: int = (x * 73856093) ^ (y * 19349663)
	match id:
		&"grass":
			# Matas sueltas, algo más oscuras o más claras.
			var bucket: int = absi(hash_value) % 23
			if bucket == 0:
				return color.darkened(0.12)
			if bucket == 1:
				return color.lightened(0.10)
		&"sidewalk":
			# Juntas de las losas, paralelas a los ejes de la cuadrícula.
			var u: float = (x + 0.5) / 32.0 + (y + 0.5) / 16.0
			var v: float = (x + 0.5) / 32.0 - (y + 0.5) / 16.0
			if fposmod(u * 2.0, 1.0) < 0.07 or fposmod(v * 2.0, 1.0) < 0.07:
				return color.darkened(0.10)
		&"street":
			if absi(hash_value) % 17 == 0:
				return color.lightened(0.06)
	return color


static func _build_wall_source() -> TileSetAtlasSource:
	var size: Vector2i = WALL_TEXTURE_SIZE
	var combos: int = EDGE_STATE_COUNT * EDGE_STATE_COUNT
	var image: Image = Image.create_empty(size.x * combos, size.y, false, Image.FORMAT_RGBA8)
	for state_x in range(EDGE_STATE_COUNT):
		for state_y in range(EDGE_STATE_COUNT):
			var index: int = state_x * EDGE_STATE_COUNT + state_y
			if index == 0:
				continue
			_draw_edge_panel(image, index * size.x, Edge.Axis.X, state_x)
			_draw_edge_panel(image, index * size.x, Edge.Axis.Y, state_y)
	var source: TileSetAtlasSource = _make_source(image, size)
	for index in range(1, combos):
		var coords := Vector2i(index, 0)
		source.create_tile(coords)
		# Las aristas norte y oeste de una celda están 8 px por encima de su centro: ordenar
		# las paredes por ese punto las coloca bien frente a los agentes (cuyo punto es el de
		# sus pies) tanto si están dentro de la celda como al otro lado de la pared.
		source.get_tile_data(coords, 0).y_sort_origin = WALL_Y_SORT_ORIGIN
	return source


static func _make_source(image: Image, region_size: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = region_size
	return source


## Dibuja lo que hay sobre la arista norte (X) u oeste (Y) del rombo situado en el centro del
## tile, según su estado visual (ver edge_state).
static func _draw_edge_panel(image: Image, offset_x: int, axis: Edge.Axis, state: int) -> void:
	if state == 0:
		return
	var is_door: bool = state > HEIGHT_COUNT
	var height_px: int = WallStyle.pixels(((state - 1) % HEIGHT_COUNT) as WallStyle.Height)
	# Rombo de la celda centrado verticalmente en la textura: su vértice superior queda en
	# (32, mitad - 16). La arista va de ese vértice al derecho (eje X) o al izquierdo (eje Y).
	var top: Vector2 = Vector2(offset_x + 32, WALL_TEXTURE_SIZE.y * 0.5 - 16.0)
	var end: Vector2 = top + (Vector2(32, 16) if axis == Edge.Axis.X else Vector2(-32, 16))
	var face: Color = WALL_FACE_X if axis == Edge.Axis.X else WALL_FACE_Y
	if is_door:
		_draw_door(image, top, end, face, height_px)
	else:
		_fill_band(image, top, end, 0.0, 1.0, 0, height_px, face)
		_fill_band(image, top, end, 0.0, 1.0, maxi(height_px - CAP_STRIP, 0), height_px, WALL_CAP)
		_fill_band(image, top, end, 0.0, 1.0, 0, mini(BASE_STRIP, height_px), WALL_BASE)


## Pared con un hueco de puerta. Si la pared es más alta que la puerta (FULL) queda un dintel; si
## no (LOW, FLAT), solo dos jambas y el hueco entero. En FLAT el hueco lleva una franja de madera
## para que se vea dónde está la puerta.
static func _draw_door(image: Image, top: Vector2, end: Vector2, face: Color, height_px: int) -> void:
	var has_lintel: bool = DOOR_HEIGHT < height_px
	var door_top: int = mini(DOOR_HEIGHT, height_px)
	var cap_from: int = maxi(height_px - CAP_STRIP, 0)
	var base_to: int = mini(BASE_STRIP, height_px)

	# Jambas (a cada lado del hueco) y dintel (encima).
	_fill_band(image, top, end, 0.0, DOOR_START, 0, height_px, face)
	_fill_band(image, top, end, DOOR_END, 1.0, 0, height_px, face)
	if has_lintel:
		_fill_band(image, top, end, DOOR_START, DOOR_END, DOOR_HEIGHT, height_px, face)
		_fill_band(image, top, end, 0.0, 1.0, cap_from, height_px, WALL_CAP)
	else:
		_fill_band(image, top, end, 0.0, DOOR_START, cap_from, height_px, WALL_CAP)
		_fill_band(image, top, end, DOOR_END, 1.0, cap_from, height_px, WALL_CAP)
	_fill_band(image, top, end, 0.0, DOOR_START, 0, base_to, WALL_BASE)
	_fill_band(image, top, end, DOOR_END, 1.0, 0, base_to, WALL_BASE)

	# Marco de madera alrededor del hueco.
	_fill_band(image, top, end, DOOR_START, DOOR_START + DOOR_FRAME_THICKNESS, 0, door_top, DOOR_FRAME)
	_fill_band(image, top, end, DOOR_END - DOOR_FRAME_THICKNESS, DOOR_END, 0, door_top, DOOR_FRAME)
	if has_lintel:
		_fill_band(image, top, end, DOOR_START, DOOR_END, DOOR_HEIGHT - 4, DOOR_HEIGHT, DOOR_FRAME)
	if height_px == WallStyle.FLAT_PIXELS:
		_fill_band(image, top, end, DOOR_START, DOOR_END, 0, BASE_STRIP, DOOR_FRAME)


## Rellena una franja de la cara de una pared: desde la fracción `t0` hasta `t1` del largo de la
## arista (que va de `top` a `end`) y desde `from_px` hasta `to_px` píxeles sobre su base. Un
## píxel se pinta si su centro cae dentro de la franja. Se rellena por columnas.
static func _fill_band(image: Image, top: Vector2, end: Vector2, t0: float, t1: float,
		from_px: int, to_px: int, color: Color) -> void:
	if to_px <= from_px or t1 <= t0:
		return
	var slope: float = (end.y - top.y) / (end.x - top.x)
	var x_a: float = top.x + (end.x - top.x) * t0
	var x_b: float = top.x + (end.x - top.x) * t1
	var x_first: int = ceili(minf(x_a, x_b) - 0.5)
	var x_last: int = floori(maxf(x_a, x_b) - 0.5)
	for x in range(x_first, x_last + 1):
		var base_y: float = top.y + (x + 0.5 - top.x) * slope
		var y_first: int = ceili(base_y - to_px - 0.5)
		var y_last: int = floori(base_y - from_px - 0.5)
		if y_last >= y_first:
			image.fill_rect(Rect2i(x, y_first, 1, y_last - y_first + 1), color)
