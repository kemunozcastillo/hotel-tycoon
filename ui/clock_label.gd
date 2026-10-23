class_name ClockLabel
extends Label
## Muestra el día, la hora y la velocidad del reloj. Solo lee GameClock.

const SPEED_TEXT: Dictionary = {
	GameClock.Speed.PAUSED: "Pausa",
	GameClock.Speed.X1: "x1",
	GameClock.Speed.X2: "x2",
	GameClock.Speed.X3: "x3",
}

var _clock: GameClock


func setup(clock: GameClock) -> void:
	_clock = clock
	horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _refresh() -> void:
	var new_text: String = "Día %d  %02d:%02d   [%s]" % [
		_clock.get_day(), _clock.get_hour(), _clock.get_minute(), SPEED_TEXT[_clock.speed]]
	if new_text != text:
		text = new_text
