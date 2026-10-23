class_name AgentView
extends Node2D
## Dibujo de un agente: sombra, cuerpo y cabeza con formas simples (arte provisional). Su
## posición es el punto de los pies, que es lo que usa la ordenación por Y con las paredes.
## Solo lee el Agent; no lo modifica.

const SHADOW_COLOR: Color = Color(0, 0, 0, 0.35)
const OUTLINE_COLOR: Color = Color(0.1, 0.1, 0.12, 0.9)
const SKIN_COLOR: Color = Color(0.96, 0.8, 0.66)
const SELECTION_COLOR: Color = Color(1.0, 0.92, 0.4, 0.95)
const BLOCKED_COLOR: Color = Color(1.0, 0.35, 0.3)
const HAT_COLOR: Color = Color(0.32, 0.22, 0.16)
const BAG_COLOR: Color = Color(0.62, 0.4, 0.2)
const BODY_SIZE: Vector2 = Vector2(10, 15)
const HEAD_RADIUS: float = 4.5

var agent: Agent
var selected: bool = false:
	set(value):
		if selected != value:
			selected = value
			queue_redraw()

## Para saber si el agente es un huésped (lleva sombrero y, al llegar o irse, una maleta).
var _guests: GuestRegistry
var _last_state: Agent.State = Agent.State.IDLE
var _last_look: int = 0


func setup(p_agent: Agent, guests: GuestRegistry) -> void:
	agent = p_agent
	_guests = guests
	_last_state = agent.state
	_last_look = _look()
	_follow_agent()


func _process(_delta: float) -> void:
	_follow_agent()
	var look: int = _look()
	if agent.state != _last_state or look != _last_look:
		_last_state = agent.state
		_last_look = look
		queue_redraw()


## 0 = agente normal, 1 = huésped, 2 = huésped de viaje (llegando o yéndose, con maleta).
func _look() -> int:
	var guest: Guest = _guests.get_guest_by_agent(agent.id)
	if guest == null:
		return 0
	return 2 if guest.state == Guest.State.ARRIVING or guest.state == Guest.State.LEAVING else 1


func _follow_agent() -> void:
	position = IsoProjection.grid_to_world(agent.position)


func _draw() -> void:
	draw_colored_polygon(_ellipse(Vector2.ZERO, Vector2(9, 4.5)), SHADOW_COLOR)
	if selected:
		var ring: PackedVector2Array = _ellipse(Vector2.ZERO, Vector2(13, 6.5))
		ring.append(ring[0])
		draw_polyline(ring, SELECTION_COLOR, 2.0)

	var body_rect := Rect2(Vector2(-BODY_SIZE.x * 0.5, -BODY_SIZE.y - 2.0), BODY_SIZE)
	draw_rect(body_rect, _body_color())
	draw_rect(body_rect, OUTLINE_COLOR, false, 1.0)
	var head_center := Vector2(0, body_rect.position.y - HEAD_RADIUS + 1.0)
	draw_circle(head_center, HEAD_RADIUS, SKIN_COLOR)
	draw_arc(head_center, HEAD_RADIUS, 0.0, TAU, 16, OUTLINE_COLOR, 1.0)

	if _last_look >= 1:
		# Sombrero de huésped.
		draw_rect(Rect2(head_center + Vector2(-HEAD_RADIUS - 1.5, -HEAD_RADIUS - 0.5), Vector2(HEAD_RADIUS * 2.0 + 3.0, 2.5)), HAT_COLOR)
		draw_rect(Rect2(head_center + Vector2(-HEAD_RADIUS + 1.0, -HEAD_RADIUS - 3.0), Vector2(HEAD_RADIUS * 2.0 - 2.0, 3.0)), HAT_COLOR)
	if _last_look == 2:
		# Maleta junto a la mano.
		var bag := Rect2(Vector2(BODY_SIZE.x * 0.5 + 0.5, body_rect.position.y + BODY_SIZE.y - 6.0), Vector2(7, 6))
		draw_rect(bag, BAG_COLOR)
		draw_rect(bag, OUTLINE_COLOR, false, 1.0)

	if agent.state == Agent.State.BLOCKED:
		var font: Font = ThemeDB.fallback_font
		draw_string_outline(font, head_center + Vector2(-3, -9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, OUTLINE_COLOR)
		draw_string(font, head_center + Vector2(-3, -9), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, BLOCKED_COLOR)


## Un color de ropa estable por agente (derivado de su id) para distinguirlos.
func _body_color() -> Color:
	return body_color_of(agent)


static func body_color_of(of_agent: Agent) -> Color:
	return Color.from_hsv(fmod(of_agent.id * 0.21, 1.0), 0.55, 0.9)


static func _ellipse(center: Vector2, radius: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in range(16):
		var angle: float = TAU * float(i) / 16.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	return points
