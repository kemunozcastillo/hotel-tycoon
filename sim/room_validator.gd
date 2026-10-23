class_name RoomValidator
extends RefCounted
## Comprueba una habitación contra los requisitos de un tipo. Función pura.
##
## Solo se generan comprobaciones para los requisitos que el tipo define (un máximo de 0 o un
## lado mínimo de 0 significan "sin requisito"). Orden fijo: área mínima, área máxima, lado
## corto, puertas y suelo.


static func evaluate(room: Room, type: RoomType) -> RoomStatus:
	var status := RoomStatus.new()
	var area: int = room.get_area()

	status.checks.append(RoomCheck.new(RoomCheck.Kind.MIN_AREA, area >= type.min_area, area, type.min_area))
	if type.max_area > 0:
		status.checks.append(RoomCheck.new(RoomCheck.Kind.MAX_AREA, area <= type.max_area, area, type.max_area))
	if type.min_short_side > 0:
		var side: int = room.get_short_side()
		status.checks.append(RoomCheck.new(RoomCheck.Kind.MIN_SHORT_SIDE, side >= type.min_short_side, side, type.min_short_side))
	if type.min_doors > 0:
		var doors: int = room.doors.size()
		status.checks.append(RoomCheck.new(RoomCheck.Kind.MIN_DOORS, doors >= type.min_doors, doors, type.min_doors))
	if type.requires_complete_floor:
		status.checks.append(RoomCheck.new(RoomCheck.Kind.COMPLETE_FLOOR, room.missing_floor_cells == 0, room.missing_floor_cells, 0))
	return status
