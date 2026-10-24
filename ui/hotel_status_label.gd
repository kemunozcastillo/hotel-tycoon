class_name HotelStatusLabel
extends Label
## Resumen del hotel (huéspedes, espera y dormitorios libres) o, si falta la recepción o no se
## llega a ella desde la calle, un aviso de qué construir. Solo lee GameState.

var _state: GameState
var _level: int = 0


func setup(state: GameState, level: int) -> void:
	_state = state
	_level = level
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var bedrooms: Vector2i = _state.guests.count_bedrooms(_level)
	var new_text: String = GuestTexts.hotel_summary(
			_state.guests.get_guest_count(),
			_state.guests.get_waiting_count(_level),
			bedrooms.x, bedrooms.y,
			not _state.entrances.get_valid(_level).is_empty(),
			_state.guests.has_operational_reception(_level),
			_state.guests.is_reception_reachable(_level))
	if new_text != text:
		text = new_text
