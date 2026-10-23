class_name NoticeLabel
extends Label
## Aviso breve en la parte de arriba (por ejemplo "Dinero insuficiente"): aparece, se mantiene unos
## segundos y se desvanece. Un aviso nuevo sustituye al anterior. Usa tiempo real, no el del juego,
## para que también se vea con el juego en pausa.

const DEFAULT_SECONDS: float = 3.0
const FADE_SECONDS: float = 0.6
const TOP_OFFSET: float = 96.0

var _remaining: float = 0.0
var _seconds: float = DEFAULT_SECONDS


func setup() -> void:
	# Centrado arriba; al crecer el texto se reparte a ambos lados.
	anchor_left = 0.5
	anchor_right = 0.5
	offset_top = TOP_OFFSET
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_color_override("font_color", Color(1.0, 0.7, 0.55))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	add_theme_constant_override("outline_size", 5)
	visible = false


## Muestra un aviso durante unos segundos.
func show_notice(message: String, seconds: float = DEFAULT_SECONDS) -> void:
	text = message
	_seconds = seconds
	_remaining = seconds
	modulate.a = 1.0
	visible = true


func _process(delta: float) -> void:
	if not visible:
		return
	_remaining -= delta
	if _remaining <= 0.0:
		visible = false
		return
	modulate.a = clampf(_remaining / minf(FADE_SECONDS, _seconds), 0.0, 1.0)
