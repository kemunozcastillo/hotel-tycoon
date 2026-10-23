class_name RoomTexts
extends RefCounted
## Textos en español de las habitaciones, sus requisitos y sus problemas. Funciones puras,
## compartidas por el panel de información y las etiquetas del mapa.

const OK_COLOR: String = "#7bd88f"
const FAIL_COLOR: String = "#ff8a6b"


## Tamaño legible: "ancho×alto" si es rectangular, si no, el número de celdas.
static func size_text(room: Room) -> String:
	if room.is_rectangular():
		var size: Vector2i = room.get_bounds().size
		return "%d×%d" % [size.x, size.y]
	return "%d celdas" % room.get_area()


## Motivo corto por el que un requisito no se cumple (para la etiqueta del mapa).
static func problem_text(check: RoomCheck) -> String:
	match check.kind:
		RoomCheck.Kind.MIN_AREA:
			return "Muy pequeña (%d de %d celdas)" % [check.actual, check.required]
		RoomCheck.Kind.MAX_AREA:
			return "Demasiado grande (%d de %d celdas)" % [check.actual, check.required]
		RoomCheck.Kind.MIN_SHORT_SIDE:
			return "Demasiado estrecha (lado %d, mín. %d)" % [check.actual, check.required]
		RoomCheck.Kind.MIN_DOORS:
			if check.required == 1:
				return "Falta puerta"
			return "Faltan puertas (%d de %d)" % [check.actual, check.required]
		RoomCheck.Kind.COMPLETE_FLOOR:
			if check.actual == 1:
				return "Falta suelo (1 celda)"
			return "Falta suelo (%d celdas)" % check.actual
	return ""


## Descripción del requisito con lo que tiene la habitación (para el panel).
static func requirement_text(check: RoomCheck) -> String:
	match check.kind:
		RoomCheck.Kind.MIN_AREA:
			return "Área mínima: %d celdas (tiene %d)" % [check.required, check.actual]
		RoomCheck.Kind.MAX_AREA:
			return "Área máxima: %d celdas (tiene %d)" % [check.required, check.actual]
		RoomCheck.Kind.MIN_SHORT_SIDE:
			return "Lado corto mínimo: %d (tiene %d)" % [check.required, check.actual]
		RoomCheck.Kind.MIN_DOORS:
			return "Puertas: mínimo %d (tiene %d)" % [check.required, check.actual]
		RoomCheck.Kind.COMPLETE_FLOOR:
			if check.passed:
				return "Suelo completo"
			if check.actual == 1:
				return "Suelo completo (falta 1 celda)"
			return "Suelo completo (faltan %d celdas)" % check.actual
	return ""


## Líneas de la etiqueta flotante de una habitación. Sin tipo: solo el tamaño (y el aviso de
## suelo). Con tipo: el nombre y el tamaño, y el primer problema si no cumple los requisitos.
static func label_lines(room: Room, type: RoomType, status: RoomStatus) -> Array[String]:
	var lines: Array[String] = []
	if type == null:
		var text: String = size_text(room)
		if not room.has_complete_floor:
			text += " · falta suelo"
		lines.append(text)
		return lines
	lines.append("%s %s" % [type.display_name, size_text(room)])
	var failed: RoomCheck = status.get_first_failed() if status != null else null
	if failed != null:
		lines.append(problem_text(failed))
	return lines


## Contenido del panel de información en BBCode.
static func panel_bbcode(room: Room, type: RoomType, status: RoomStatus) -> String:
	var title: String = "Sin tipo" if type == null else type.display_name
	var text: String = "[b]%s[/b]  %s (%d celdas)" % [title, size_text(room), room.get_area()]
	if type == null:
		return text + "\n[i]Elige un tipo en la barra y haz clic en la habitación.[/i]"
	for check: RoomCheck in status.checks:
		var mark: String = "[color=%s]OK[/color]" % OK_COLOR if check.passed else "[color=%s]NO[/color]" % FAIL_COLOR
		text += "\n%s  %s" % [mark, requirement_text(check)]
	if status.is_operational():
		text += "\n[color=%s]Operativa[/color]" % OK_COLOR
	else:
		text += "\n[color=%s]No operativa[/color]" % FAIL_COLOR
	return text
