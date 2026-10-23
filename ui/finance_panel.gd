class_name FinancePanel
extends PanelContainer
## Informe de finanzas (saldo, hoy, últimos días y movimientos recientes) en el centro de la
## pantalla. Se abre y se cierra con la tecla F o pulsando el saldo. No captura el ratón. Solo lee
## el Ledger.

const PANEL_WIDTH: float = 560.0
const REFRESH_SECONDS: float = 0.5

var _ledger: Ledger
var _clock: GameClock
var _label: RichTextLabel
var _since_refresh: float = 0.0


func setup(ledger: Ledger, clock: GameClock) -> void:
	_ledger = ledger
	_clock = clock
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	# Fondo casi opaco para que el texto se lea sobre el mapa.
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.07, 0.08, 0.10, 0.93)
	background.set_content_margin_all(14.0)
	background.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", background)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false
	ledger.balance_changed.connect(_on_balance_changed)


func is_open() -> bool:
	return visible


func set_open(open: bool) -> void:
	visible = open
	if open:
		_refresh()


func toggle() -> void:
	set_open(not visible)


## Texto actual sin formato (para comprobaciones).
func get_plain_text() -> String:
	return _label.get_parsed_text()


func _process(delta: float) -> void:
	if not visible:
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_refresh() # el día puede cambiar sin que haya ningún movimiento


func _on_balance_changed(_balance: int) -> void:
	if visible:
		_refresh()


func _refresh() -> void:
	_since_refresh = 0.0
	_label.text = MoneyTexts.finance_report(_ledger, _clock.get_day(), _clock.total_minutes)
