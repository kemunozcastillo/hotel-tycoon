class_name IsoCamera
extends Camera2D
## Cámara 2D con desplazamiento (WASD / flechas / arrastre con el botón central) y zoom
## con la rueda, que mantiene fijo el punto del mundo bajo el cursor.

const MOVE_SPEED: float = 800.0 # píxeles de pantalla por segundo
const ZOOM_MIN: float = 0.25
const ZOOM_MAX: float = 4.0
const ZOOM_STEP: float = 1.15

## Zona del mundo por la que se permite moverse (el centro de la cámara se limita a ella).
var bounds: Rect2 = Rect2()
var _has_bounds: bool = false
var _dragging: bool = false


## Limita el movimiento al rectángulo dado (coordenadas del mundo).
func set_bounds(world_rect: Rect2) -> void:
	bounds = world_rect
	_has_bounds = true
	position = _clamped(position)


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if direction != Vector2.ZERO:
		pan_screen(direction.normalized() * MOVE_SPEED * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_MIDDLE:
				_dragging = button.pressed
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed:
					zoom_at(ZOOM_STEP, button.position, get_viewport_rect().size)
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed:
					zoom_at(1.0 / ZOOM_STEP, button.position, get_viewport_rect().size)
	elif event is InputEventMouseMotion and _dragging:
		pan_screen(-(event as InputEventMouseMotion).relative)


## Mueve la cámara un desplazamiento expresado en píxeles de pantalla.
func pan_screen(screen_delta: Vector2) -> void:
	position = _clamped(position + screen_delta / zoom.x)


## Multiplica el zoom por `factor` manteniendo fijo el punto del mundo bajo `screen_pos`.
func zoom_at(factor: float, screen_pos: Vector2, viewport_size: Vector2) -> void:
	var new_zoom: float = clampf(zoom.x * factor, ZOOM_MIN, ZOOM_MAX)
	if is_equal_approx(new_zoom, zoom.x):
		return
	var from_center: Vector2 = screen_pos - viewport_size * 0.5
	var new_position: Vector2 = position + from_center / zoom.x - from_center / new_zoom
	zoom = Vector2(new_zoom, new_zoom)
	position = _clamped(new_position)


## Punto del mundo que hay bajo una posición de pantalla.
func screen_to_world(screen_pos: Vector2, viewport_size: Vector2) -> Vector2:
	return position + (screen_pos - viewport_size * 0.5) / zoom.x


func _clamped(world_pos: Vector2) -> Vector2:
	if not _has_bounds:
		return world_pos
	return Vector2(
		clampf(world_pos.x, bounds.position.x, bounds.end.x),
		clampf(world_pos.y, bounds.position.y, bounds.end.y))
