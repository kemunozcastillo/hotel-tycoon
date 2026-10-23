class_name MoneyButton
extends Button
## El saldo siempre a la vista, con lo que se lleva ganado o perdido hoy. Al pulsarlo se abre el
## panel de finanzas. En rojo si el saldo es negativo. Solo lee el Ledger.

var _ledger: Ledger
var _clock: GameClock


func setup(ledger: Ledger, clock: GameClock) -> void:
	_ledger = ledger
	_clock = clock
	flat = true
	focus_mode = Control.FOCUS_NONE # que la barra espaciadora siga siendo del reloj
	alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tooltip_text = "Finanzas (F)"
	_refresh()


func _process(_delta: float) -> void:
	_refresh() # también cambia al empezar un día, sin que haya movimientos


func _refresh() -> void:
	var net_today: int = _ledger.get_day_net(_clock.get_day())
	var new_text: String = "Dinero %s  ·  hoy %s  [F]" % [MoneyTexts.format(_ledger.balance), MoneyTexts.signed(net_today)]
	if new_text != text:
		text = new_text
	var color: Color = Color(1.0, 0.55, 0.5) if _ledger.balance < 0 else Color(1, 1, 1)
	add_theme_color_override("font_color", color)
	add_theme_color_override("font_hover_color", color.lightened(0.2))
	add_theme_color_override("font_pressed_color", color)
