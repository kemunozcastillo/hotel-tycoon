class_name RoomStatus
extends RefCounted
## Estado de una habitación frente a los requisitos de su tipo: una comprobación por requisito.

var checks: Array[RoomCheck] = []


## true si cumple todos los requisitos.
func is_operational() -> bool:
	for check: RoomCheck in checks:
		if not check.passed:
			return false
	return true


func get_failed() -> Array[RoomCheck]:
	var failed: Array[RoomCheck] = []
	for check: RoomCheck in checks:
		if not check.passed:
			failed.append(check)
	return failed


## El primer requisito incumplido (en el orden de los requisitos), o null si cumple todos.
func get_first_failed() -> RoomCheck:
	for check: RoomCheck in checks:
		if not check.passed:
			return check
	return null
