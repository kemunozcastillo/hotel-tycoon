extends TestCase
## Lógica de la cámara (zoom hacia el cursor, desplazamiento, límites) sin árbol de escena.

const VIEWPORT := Vector2(1280, 720)


func test_zoom_keeps_world_point_under_cursor() -> void:
	var camera := IsoCamera.new()
	camera.position = Vector2(500, 300)
	for cursor: Vector2 in [Vector2(640, 360), Vector2(100, 50), Vector2(1200, 700), Vector2(900, 200)]:
		var before: Vector2 = camera.screen_to_world(cursor, VIEWPORT)
		camera.zoom_at(1.15, cursor, VIEWPORT)
		camera.zoom_at(1.15, cursor, VIEWPORT)
		var after: Vector2 = camera.screen_to_world(cursor, VIEWPORT)
		assert_near(after.x, before.x, "x bajo el cursor %s" % str(cursor), 0.01)
		assert_near(after.y, before.y, "y bajo el cursor %s" % str(cursor), 0.01)
	camera.free()


func test_zoom_is_clamped() -> void:
	var camera := IsoCamera.new()
	for i in range(50):
		camera.zoom_at(1.5, VIEWPORT * 0.5, VIEWPORT)
	assert_near(camera.zoom.x, IsoCamera.ZOOM_MAX)
	for i in range(100):
		camera.zoom_at(1.0 / 1.5, VIEWPORT * 0.5, VIEWPORT)
	assert_near(camera.zoom.x, IsoCamera.ZOOM_MIN)
	camera.free()


func test_pan_scales_with_zoom() -> void:
	var camera := IsoCamera.new()
	camera.pan_screen(Vector2(100, 0))
	assert_near(camera.position.x, 100.0)
	camera.zoom = Vector2(2, 2)
	camera.pan_screen(Vector2(100, 0))
	assert_near(camera.position.x, 150.0, "con zoom 2 el mismo gesto mueve la mitad")
	camera.free()


func test_bounds_limit_position() -> void:
	var camera := IsoCamera.new()
	camera.set_bounds(Rect2(0, 0, 1000, 500))
	camera.pan_screen(Vector2(5000, 5000))
	assert_eq(camera.position, Vector2(1000, 500))
	camera.pan_screen(Vector2(-9000, -9000))
	assert_eq(camera.position, Vector2(0, 0))
	camera.free()


func test_map_world_bounds_contains_all_corners() -> void:
	var size := Vector2i(10, 6)
	var rect: Rect2 = IsoProjection.map_world_bounds(size)
	for corner: Vector2 in [Vector2(0, 0), Vector2(10, 0), Vector2(0, 6), Vector2(10, 6)]:
		var world: Vector2 = IsoProjection.grid_to_world(corner)
		assert_true(rect.grow(0.01).has_point(world), "esquina %s dentro de los límites" % str(corner))
