class_name EconomyRules
extends RefCounted
## Las reglas de dinero del juego, cargadas de data/economy.json: dinero inicial, precio de cada
## pieza, lo que devuelve venderla (nueva o usada), cuánto dura el margen de "nueva" y qué parte
## de una estancia se cobra al empezar. Un campo mal formado se ignora con un aviso en `warnings`
## y se queda su valor por defecto; nunca impide arrancar.
##
## `EconomyRules.without_costs()` hace que todo cueste 0 y no haya dinero inicial: es lo que usa
## GameState por defecto, para que los tests puedan construir sin límite.
##
## Nota para la exportación: los .json no son recursos de Godot, así que hay que incluir
## `data/*.json` en el filtro de exportación del preset.

const DEFAULT_PATH: String = "res://data/economy.json"

var start_money: int = 2000
var floor_price: int = 10
var wall_price: int = 8
var door_price: int = 25
## Fracción del precio que devuelve vender una pieza nueva y una usada.
var sell_rate_new: float = 1.0
var sell_rate_used: float = 0.85
## Minutos de juego que una pieza recién colocada sigue contando como nueva.
var new_window_minutes: float = 60.0
## Fracción del precio de una estancia que se cobra al hacer el check-in.
var deposit_rate: float = 0.5
## Si es false, los huéspedes no pagan y las habitaciones no cuestan mantenimiento (lo usan las
## reglas sin costes). Construir ya cuesta lo que digan los precios.
var charges_enabled: bool = true
## Si es true, el inventario solo guarda lo que cabe en los almacenes operativos (sin almacén no
## se guarda nada). Si es false, el inventario no tiene límite (lo usan los tests de otras fases;
## el juego lo activa en data/economy.json).
var limited_storage: bool = false

## Problemas encontrados al cargar (vacío si todo estaba bien).
var warnings: Array[String] = []


## Reglas sin costes: nada cuesta dinero ni se parte con él.
static func without_costs() -> EconomyRules:
	var rules := EconomyRules.new()
	rules.start_money = 0
	rules.floor_price = 0
	rules.wall_price = 0
	rules.door_price = 0
	rules.charges_enabled = false
	return rules


## Carga data/economy.json y muestra los avisos en la consola.
static func load_default() -> EconomyRules:
	return load_file(DEFAULT_PATH)


## Con `report_warnings` los avisos también se escriben en la consola (push_warning).
static func load_file(path: String, report_warnings: bool = true) -> EconomyRules:
	var rules: EconomyRules
	if not FileAccess.file_exists(path):
		rules = EconomyRules.new()
		rules.warnings.append("no existe el archivo de economía: %s (se usan los valores por defecto)" % path)
	else:
		rules = parse(FileAccess.get_file_as_string(path))
	if report_warnings:
		for warning: String in rules.warnings:
			push_warning("economy: %s" % warning)
	return rules


## Interpreta el texto de un JSON. No escribe nada en la consola (los avisos van en `warnings`).
static func parse(text: String) -> EconomyRules:
	var rules := EconomyRules.new()
	var json := JSON.new()
	if json.parse(text) != OK:
		rules.warnings.append("JSON inválido (línea %d): %s" % [json.get_error_line(), json.get_error_message()])
		return rules
	if typeof(json.data) != TYPE_DICTIONARY:
		rules.warnings.append("se esperaba un objeto con los campos de la economía")
		return rules
	var data: Dictionary = json.data

	rules.start_money = rules._read_int(data, "start_money", rules.start_money)
	var prices: Variant = data.get("build_prices", {})
	if typeof(prices) != TYPE_DICTIONARY:
		rules.warnings.append("'build_prices' debe ser un objeto con floor, wall y door")
	else:
		rules.floor_price = rules._read_int(prices as Dictionary, "floor", rules.floor_price, "build_prices.")
		rules.wall_price = rules._read_int(prices as Dictionary, "wall", rules.wall_price, "build_prices.")
		rules.door_price = rules._read_int(prices as Dictionary, "door", rules.door_price, "build_prices.")
	rules.sell_rate_new = rules._read_rate(data, "sell_rate_new", rules.sell_rate_new)
	rules.sell_rate_used = rules._read_rate(data, "sell_rate_used", rules.sell_rate_used)
	rules.deposit_rate = rules._read_rate(data, "deposit_rate", rules.deposit_rate)
	rules.new_window_minutes = rules._read_minutes(data, "new_window_minutes", rules.new_window_minutes)
	if data.has("limited_storage"):
		if typeof(data["limited_storage"]) == TYPE_BOOL:
			rules.limited_storage = data["limited_storage"] as bool
		else:
			rules.warnings.append("'limited_storage' debe ser true o false (se usa %s)" % rules.limited_storage)
	if rules.sell_rate_used > rules.sell_rate_new:
		rules.warnings.append("'sell_rate_used' (%s) no puede superar 'sell_rate_new' (%s): se iguala" % [rules.sell_rate_used, rules.sell_rate_new])
		rules.sell_rate_used = rules.sell_rate_new
	return rules


## Precio de una pieza nueva.
func price_of(kind: BuildItem.Kind) -> int:
	match kind:
		BuildItem.Kind.WALL:
			return wall_price
		BuildItem.Kind.DOOR:
			return door_price
		_:
			return floor_price


## Lo que se obtiene al vender una pieza en ese estado (redondeado al entero más cercano). Nunca
## supera el precio, así que comprar y vender no puede dar beneficio.
func sale_value(kind: BuildItem.Kind, condition: BuildItem.Condition) -> int:
	var rate: float = sell_rate_new if condition == BuildItem.Condition.NEW else sell_rate_used
	return roundi(float(price_of(kind)) * rate)


## Parte de una estancia que se cobra al hacer el check-in (redondeada hacia abajo; el resto se
## cobra al final).
func deposit_of(stay_price: int) -> int:
	return floori(float(stay_price) * deposit_rate)


# --- Lectura de campos -------------------------------------------------------------------------

func _read_int(data: Dictionary, key: String, current: int, prefix: String = "") -> int:
	if not data.has(key):
		return current
	var raw: Variant = data[key]
	var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
	if not is_number or float(raw) != floorf(float(raw)) or int(raw) < 0:
		warnings.append("'%s%s' debe ser un entero >= 0 (se usa %d)" % [prefix, key, current])
		return current
	return int(raw)


func _read_rate(data: Dictionary, key: String, current: float) -> float:
	if not data.has(key):
		return current
	var raw: Variant = data[key]
	var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
	if not is_number or float(raw) < 0.0 or float(raw) > 1.0:
		warnings.append("'%s' debe ser un número entre 0 y 1 (se usa %s)" % [key, current])
		return current
	return float(raw)


func _read_minutes(data: Dictionary, key: String, current: float) -> float:
	if not data.has(key):
		return current
	var raw: Variant = data[key]
	var is_number: bool = typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT
	if not is_number or float(raw) < 0.0:
		warnings.append("'%s' debe ser un número >= 0 (se usa %s)" % [key, current])
		return current
	return float(raw)
