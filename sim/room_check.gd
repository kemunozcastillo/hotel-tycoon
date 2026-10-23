class_name RoomCheck
extends RefCounted
## Resultado de comprobar UN requisito de un tipo de habitación contra una habitación concreta.

enum Kind { MIN_AREA, MAX_AREA, MIN_SHORT_SIDE, MIN_DOORS, COMPLETE_FLOOR }

var kind: Kind
var passed: bool
## Valor que tiene la habitación (celdas, lado, puertas, o celdas sin suelo).
var actual: int
## Valor exigido: el mínimo, el máximo, o 0 celdas sin suelo.
var required: int


func _init(p_kind: Kind, p_passed: bool, p_actual: int, p_required: int) -> void:
	kind = p_kind
	passed = p_passed
	actual = p_actual
	required = p_required
