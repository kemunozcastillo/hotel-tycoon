class_name SaveReader
extends RefCounted
## Lee con comprobaciones los datos de una partida guardada. Cada lectura que falla (falta el campo,
## tiene otro tipo, se sale de rango) anota un error con su ubicación y devuelve un valor neutro,
## así que restaurar nunca se rompe con un archivo corrupto: al final se mira `errors` y, si hay
## alguno, se descarta la partida entera. Los `warnings` son problemas recuperables (por ejemplo,
## un tipo de habitación que ya no existe).
##
## También trae las funciones para escribir (Vector2i, generadores de azar), para que todo el
## formato esté en un solo sitio.

## Mantiene el informe corto si el archivo está muy roto.
const MAX_MESSAGES: int = 12
## Cota "grande" para enteros normales (muy por debajo del límite de 64 bits).
const BIG: int = 1 << 53

var errors: Array[String] = []
var warnings: Array[String] = []


func fail(message: String) -> void:
	if errors.size() < MAX_MESSAGES:
		errors.append(message)


func warn(message: String) -> void:
	if warnings.size() < MAX_MESSAGES:
		warnings.append(message)


func is_ok() -> bool:
	return errors.is_empty()


# --- Escritura -----------------------------------------------------------------------------------

## Un decimal sin pérdida: sus 8 bytes en hexadecimal. El lector de JSON de Godot no devuelve
## siempre el mismo decimal que se escribió (falla en la última cifra en un 2% de los casos), y la
## partida cargada tiene que ser idéntica a la original.
static func float_data(value: float) -> String:
	return PackedFloat64Array([value]).to_byte_array().hex_encode()


static func vec2i_data(value: Vector2i) -> Array:
	return [value.x, value.y]


static func vec2i_list_data(values: Array[Vector2i]) -> Array:
	var result: Array = []
	for value: Vector2i in values:
		result.append(vec2i_data(value))
	return result


## Semilla y estado de un generador (para que, al cargar, siga la misma secuencia). Son enteros de
## 64 bits y JSON los leería como decimales perdiendo cifras, así que se guardan como texto.
static func rng_data(rng: RandomNumberGenerator) -> Dictionary:
	return {"seed": str(rng.seed), "state": str(rng.state)}


# --- Lectura de campos ------------------------------------------------------------------------------

func read_int(data: Dictionary, key: String, where: String, minimum: int = -BIG, maximum: int = BIG) -> int:
	if not data.has(key):
		fail("%s: falta '%s'" % [where, key])
		return clampi(0, minimum, maximum)
	return as_int(data[key], "%s.%s" % [where, key], minimum, maximum)


func read_float(data: Dictionary, key: String, where: String, minimum: float = -1.0e15, maximum: float = 1.0e15) -> float:
	if not data.has(key):
		fail("%s: falta '%s'" % [where, key])
		return clampf(0.0, minimum, maximum)
	return as_float(data[key], "%s.%s" % [where, key], minimum, maximum)


func read_bool(data: Dictionary, key: String, where: String) -> bool:
	if not data.has(key) or typeof(data[key]) != TYPE_BOOL:
		fail("%s: '%s' debe ser true o false" % [where, key])
		return false
	return data[key] as bool


func read_string(data: Dictionary, key: String, where: String) -> String:
	if not data.has(key) or typeof(data[key]) != TYPE_STRING:
		fail("%s: '%s' debe ser texto" % [where, key])
		return ""
	return data[key] as String


func read_dict(data: Dictionary, key: String, where: String) -> Dictionary:
	if not data.has(key) or typeof(data[key]) != TYPE_DICTIONARY:
		fail("%s: '%s' debe ser un objeto" % [where, key])
		return {}
	return data[key] as Dictionary


func read_array(data: Dictionary, key: String, where: String) -> Array:
	if not data.has(key) or typeof(data[key]) != TYPE_ARRAY:
		fail("%s: '%s' debe ser una lista" % [where, key])
		return []
	return data[key] as Array


func read_vec2i(data: Dictionary, key: String, where: String) -> Vector2i:
	if not data.has(key):
		fail("%s: falta '%s'" % [where, key])
		return Vector2i.ZERO
	return as_vec2i(data[key], "%s.%s" % [where, key])


## Un enum guardado como número: debe estar entre 0 y `count - 1`.
func read_enum(data: Dictionary, key: String, where: String, count: int) -> int:
	return read_int(data, key, where, 0, count - 1)


## Restaura un generador de azar guardado con `rng_data`.
func read_rng(data: Dictionary, key: String, where: String, rng: RandomNumberGenerator) -> void:
	var raw: Dictionary = read_dict(data, key, where)
	if raw.is_empty():
		return
	var seed_text: Variant = raw.get("seed")
	var state_text: Variant = raw.get("state")
	if typeof(seed_text) != TYPE_STRING or not (seed_text as String).is_valid_int() \
			or typeof(state_text) != TYPE_STRING or not (state_text as String).is_valid_int():
		fail("%s.%s: 'seed' y 'state' deben ser enteros escritos como texto" % [where, key])
		return
	rng.seed = (seed_text as String).to_int()
	rng.state = (state_text as String).to_int()


# --- Lectura de elementos de una lista --------------------------------------------------------------

func as_dict(raw: Variant, where: String) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		fail("%s debe ser un objeto" % where)
		return {}
	return raw as Dictionary


func as_int(raw: Variant, where: String, minimum: int = -BIG, maximum: int = BIG) -> int:
	var is_whole: bool = typeof(raw) == TYPE_INT or (typeof(raw) == TYPE_FLOAT and absf(raw as float) < float(BIG) and float(raw) == floorf(float(raw)))
	if not is_whole:
		fail("%s debe ser un entero" % where)
		return clampi(0, minimum, maximum)
	var value: int = int(raw)
	if value < minimum or value > maximum:
		fail("%s (%d) debe estar entre %d y %d" % [where, value, minimum, maximum])
		return clampi(value, minimum, maximum)
	return value


## Acepta un decimal escrito con `float_data` (16 cifras hexadecimales) o un número normal (por si
## alguien edita el archivo a mano).
func as_float(raw: Variant, where: String, minimum: float = -1.0e15, maximum: float = 1.0e15) -> float:
	var value: float = 0.0
	if typeof(raw) == TYPE_STRING and (raw as String).length() == 16 and (raw as String).is_valid_hex_number():
		var bytes: PackedByteArray = (raw as String).hex_decode()
		if bytes.size() != 8:
			fail("%s no es un decimal válido" % where)
			return clampf(0.0, minimum, maximum)
		value = bytes.decode_double(0)
	elif typeof(raw) == TYPE_INT or typeof(raw) == TYPE_FLOAT:
		value = float(raw)
	else:
		fail("%s debe ser un número" % where)
		return clampf(0.0, minimum, maximum)
	if is_nan(value) or value < minimum or value > maximum:
		fail("%s (%s) está fuera de rango" % [where, str(value)])
		return clampf(0.0 if is_nan(value) else value, minimum, maximum)
	return value


func as_vec2i(raw: Variant, where: String) -> Vector2i:
	if typeof(raw) != TYPE_ARRAY or (raw as Array).size() != 2:
		fail("%s debe ser una pareja [x, y]" % where)
		return Vector2i.ZERO
	var pair: Array = raw as Array
	return Vector2i(as_int(pair[0], where + "[0]"), as_int(pair[1], where + "[1]"))
