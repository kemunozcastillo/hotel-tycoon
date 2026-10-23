class_name TilesetFactory
extends RefCounted
## Genera por código el TileSet isométrico con arte provisional (sin assets externos).
##
## - Fuente GROUND: un rombo de 64x32 por tipo de suelo.
## - Fuente WALL: paneles altos sobre las aristas norte (eje X) y oeste (eje Y) de la celda.
##   La textura es alta y tiene el rombo de la celda en su centro (con relleno transparente
##   debajo), para que el tile quede alineado sin tocar `texture_origin`.

const GROUND_SOURCE_ID: int = 0
const WALL_SOURCE_ID: int = 1

## Coordenadas de atlas de cada tile.
const GROUND_BASIC_COORDS: Vector2i = Vector2i(0, 0)
const WALL_X_COORDS: Vector2i = Vector2i(0, 0)
const WALL_Y_COORDS: Vector2i = Vector2i(1, 0)
const WALL_XY_COORDS: Vector2i = Vector2i(2, 0)

const WALL_HEIGHT: int = 48
const WALL_TEXTURE_SIZE: Vector2i = Vector2i(64, 32 + 2 * WALL_HEIGHT)

const GROUND_FILL: Color = Color(0.78, 0.70, 0.56)
const GROUND_BORDER: Color = Color(0.52, 0.45, 0.35)
const WALL_FACE_X: Color = Color(0.88, 0.86, 0.82)
const WALL_FACE_Y: Color = Color(0.72, 0.70, 0.67)
const WALL_CAP: Color = Color(0.97, 0.96, 0.94)
const WALL_BASE: Color = Color(0.40, 0.37, 0.35)


static func build() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tile_set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	tile_set.tile_size = IsoProjection.TILE_SIZE
	tile_set.add_source(_build_ground_source(), GROUND_SOURCE_ID)
	tile_set.add_source(_build_wall_source(), WALL_SOURCE_ID)
	return tile_set


## Coordenadas de atlas del tile de pared para una celda según las aristas que posee.
static func wall_coords(has_x: bool, has_y: bool) -> Vector2i:
	if has_x and has_y:
		return WALL_XY_COORDS
	return WALL_X_COORDS if has_x else WALL_Y_COORDS


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
	# Tres tiles en fila: solo X, solo Y, ambos.
	var image: Image = Image.create_empty(size.x * 3, size.y, false, Image.FORMAT_RGBA8)
	_draw_wall_panel(image, 0, Edge.Axis.X)
	_draw_wall_panel(image, size.x, Edge.Axis.Y)
	_draw_wall_panel(image, size.x * 2, Edge.Axis.X)
	_draw_wall_panel(image, size.x * 2, Edge.Axis.Y)
	var source := _make_source(image, size)
	source.create_tile(WALL_X_COORDS)
	source.create_tile(WALL_Y_COORDS)
	source.create_tile(WALL_XY_COORDS)
	return source


static func _make_source(image: Image, region_size: Vector2i) -> TileSetAtlasSource:
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = region_size
	return source


## Dibuja un panel sobre la arista norte (X) u oeste (Y) del rombo situado en el centro del tile.
static func _draw_wall_panel(image: Image, offset_x: int, axis: Edge.Axis) -> void:
	var origin := Vector2(offset_x, 0)
	# Rombo de la celda centrado verticalmente en la textura: su vértice superior queda en
	# (32, mitad - 16).
	var top: Vector2 = origin + Vector2(32, WALL_TEXTURE_SIZE.y * 0.5 - 16.0)
	var end: Vector2 = top + (Vector2(32, 16) if axis == Edge.Axis.X else Vector2(-32, 16))
	var up := Vector2(0, -WALL_HEIGHT)
	var face: Color = WALL_FACE_X if axis == Edge.Axis.X else WALL_FACE_Y
	_fill_polygon(image, [top, end, end + up, top + up], face)
	# Borde superior claro y base oscura.
	var cap := Vector2(0, 3)
	_fill_polygon(image, [top + up, end + up, end + up + cap, top + up + cap], WALL_CAP)
	var base := Vector2(0, -2)
	_fill_polygon(image, [top, end, end + base, top + base], WALL_BASE)


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
