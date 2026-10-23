class_name BuildOp
extends RefCounted
## Una operación de construcción sobre una celda (suelo) o una arista (pared o puerta): qué hay
## ahora, qué habrá y qué piezas implica. BuildCommands planifica listas de operaciones y de la
## misma lista saca el presupuesto y la ejecución, así que lo que se ve en la vista previa es lo
## que luego se cobra.

var level: int = 0
## true si cambia el suelo de `cell`; false si cambia la pared o puerta de `edge`.
var is_floor: bool = true
var cell: Vector2i = Vector2i.ZERO
var edge: Edge = null
var new_floor: CellTypes.FloorType = CellTypes.FloorType.NONE
var new_edge: CellTypes.EdgeType = CellTypes.EdgeType.NONE

## La pieza que se retira (BuildItem.Kind, o -1 si no había) y en qué estado está.
var freed_kind: int = -1
var freed_condition: BuildItem.Condition = BuildItem.Condition.USED
## La pieza que hace falta colocar (BuildItem.Kind, o -1 si solo se retira algo).
var needed_kind: int = -1
