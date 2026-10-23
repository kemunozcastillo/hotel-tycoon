class_name TilesetFactory
extends RefCounted
## Genera por código el TileSet isométrico con arte provisional (sin assets externos).
##
## - Fuente GROUND: un rombo de 64x32 por tipo de suelo.
## - Fuente WALL: paneles altos sobre las aristas norte (eje X) y oeste (eje Y) de la celda.
##   Una celda posee dos aristas y cada una puede ser nada, pared o puerta, así que hay un
##   tile por combinación (3 x 3 = 9; la combinación "nada y nada" no se dibuja). La textura
##   es alta y tiene el rombo de la celda en su centro (con relleno transparente debajo), para
##   que el tile quede alineado sin tocar `texture_origin`.

const GROUND_SOURCE_ID: int = 0
const WALL_SOURCE_ID: int = 1

const GROUND_BASIC_COORDS: Vector2i = Vector2i(0, 0)

const WALL_HEIGHT: int = 48
const WALL_TEXTURE_SIZE: Vector2i = Vector2i(64, 32 + 2 * WALL_HEIGHT)
# Puerta: el hueco ocupa de DOOR_START a DOOR_END del largo de la arista y DOOR_HEIGHT de alto.
const DOOR_START: float = 0.22
const DOOR_END: float = 0.78
const DOOR_HEIGHT: int = 36
const DOOR_FRAME_THICKNESS: float = 0.05

const GROUND_FILL: Color = Color(0.78, 0.70, 0.56)
const GROUND_BORDER: Color = Color(0.52, 0.45, 0.35)
const WALL_FACE_X: Color = Color(0.88, 0.86, 0.82)
const WALL_FACE_Y: Color = Color(0.72, 0.70, 0.67)
const WALL_CAP: Color = Color(0.97, 0.96, 0.94)
const WALL_BASE: Color = Color(0.40, 0.37, 0.35)
const DOOR_FRAME: Color = Color(0.45, 0.30, 0.18)

# Número de tipos de arista (NONE, WALL, DOOR) usado para indexar las combinaciones.
const EDGE_TYPE_COUNT: int = 3


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = IsoProjection.TILE_SIZE
	tile_set.add_source(_build_ground_source(), GROUND_SOURCE_ID)
	tile_set.add_source(_build_wall_source(), WALL_SOURCE_ID)
	return tile_set


## Coordenadas de atlas del tile de una celda según el tipo de su arista norte (X) y oeste (Y).
## Devuelve (-1, -1) si no hay nada que dibujar.
static func wall_coords(type_x: CellTypes.EdgeType, type_y: CellTypes.EdgeType) -> Vector2i:
	var index: int = type_x * EDGE_TYPE_COUNT + type_y
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


static func _build_wall_source() -> TileSetAtlasSource:
	var size: Vector2i = WALL_TEXTURE_SIZE
	var combos: int = EDGE_TYPE_COUNT * EDGE_TYPE_COUNT
	var image: Image = Image.create_empty(size.x * combos, size.y, false, Image.FORMAT_RGBA8)
	var source: TileSetAtlasSource = null
	for type_x in range(EDGE_TYPE_COUNT):
		for type_y in range(EDGE_TYPE_COUNT):
			var index: int = type_x * EDGE_TYPE_COUNT + type_y
			if index == 0:
				continue
			_draw_edge_panel(image, index * size.x, Edge.Axis.X, type_x as CellTypes.EdgeType)
			_draw_edge_panel(image, index * size.x, Edge.Axis.Y, type_y as CellTypes.EdgeType)
	source = _make_source(image, size)
	for index in range(1, combos):
		source.create_tile(Vector2i(index, 0))
	return source


static func _make_source(image: Image, region_size: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = region_size
	return source


## Dibuja lo que hay sobre la arista norte (X) u oeste (Y) del rombo situado en el centro del
## tile: una pared completa o una pared con hueco de puerta.
static func _draw_edge_panel(image: Image, offset_x: int, axis: Edge.Axis, type: CellTypes.EdgeType) -> void:
	if type == CellTypes.EdgeType.NONE:
		return
	var origin := Vector2(offset_x, 0)
	# Rombo de la celda centrado verticalmente en la textura: su vértice superior queda en
	# (32, mitad - 16).
	var top: Vector2 = origin + Vector2(32, WALL_TEXTURE_SIZE.y * 0.5 - 16.0)
	var end: Vector2 = top + (Vector2(32, 16) if axis == Edge.Axis.X else Vector2(-32, 16))
	var up := Vector2(0, -WALL_HEIGHT)
	var face: Color = WALL_FACE_X if axis == Edge.Axis.X else WALL_FACE_Y
	var cap := Vector2(0, 3)
	var base := Vector2(0, -2)

	if type == CellTypes.EdgeType.WALL:
		_fill_polygon(image, [top, end, end + up, top + up], face)
		_fill_polygon(image, [top, end, end + base, top + base], WALL_BASE)
	else:
		_draw_door_panel(image, top, end, face)
	# Borde superior claro, en ambos casos.
	_fill_polygon(image, [top + up, end + up, end + up + cap, top + up + cap], WALL_CAP)


## Pared con un hueco: dos jambas laterales y un dintel, con el marco en madera.
static func _draw_door_panel(image: Image, top: Vector2, end: Vector2, face: Color) -> void:
	var up := Vector2(0, -WALL_HEIGHT)
	var door_up := Vector2(0, -DOOR_HEIGHT)
	var base := Vector2(0, -2)
	var along: Vector2 = end - top
	var left: Vector2 = top + along * DOOR_START
	var right: Vector2 = top + along * DOOR_END
	var thick: Vector2 = along * DOOR_FRAME_THICKNESS

	# Jambas (a cada lado del hueco) y dintel (encima).
	_fill_polygon(image, [top, left, left + up, top + up], face)
	_fill_polygon(image, [right, end, end + up, right + up], face)
	_fill_polygon(image, [left + door_up, right + door_up, right + up, left + up], face)
	_fill_polygon(image, [top, left, left + base, top + base], WALL_BASE)
	_fill_polygon(image, [right, end, end + base, right + base], WALL_BASE)
	# Marco de madera alrededor del hueco.
	_fill_polygon(image, [left, left + thick, left + thick + door_up, left + door_up], DOOR_FRAME)
	_fill_polygon(image, [right - thick, right, right + door_up, right - thick + door_up], DOOR_FRAME)
	_fill_polygon(image, [left + door_up, right + door_up, right + door_up + Vector2(0, 4), left + door_up + Vector2(0, 4)], DOOR_FRAME)


## Rellena un polígono convexo comprobando el centro de cada píxel.
static func _fill_polygon(image: Image, points: Array[Vector2], color: Color) -> void:
	var polygon := PackedVector2Array(points)
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point: Vector2 in points:
		bounds = bounds.expand(point)
	var x_min: int = maxi(floori(bounds.position.x), 0)
	var y_min: int = maxi(floori(bounds.position.y), 0)
	var x_max: int = mini(ceili(bounds.end.x), image.get_width())
	var y_max: int = mini(ceili(bounds.end.y), image.get_height())
	for y in range(y_min, y_max):
		for x in range(x_min, x_max):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), polygon):
				image.set_pixel(x, y, color)
