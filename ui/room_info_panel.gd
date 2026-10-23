class_name RoomInfoPanel
extends PanelContainer
## Panel con el tipo, el tamaño y los requisitos de la habitación bajo el cursor y, si es un
## dormitorio, quién lo ocupa. Solo lee el RoomRegistry y la ocupación; no captura el ratón para
## no estorbar a la construcción.

const PANEL_WIDTH: float = 330.0
const MARGIN: float = 8.0

var _registry: RoomRegistry
var _occupancy: RoomOccupancy
var _label: RichTextLabel
var _shown_room: Room = null


func setup(registry: RoomRegistry, occupancy: RoomOccupancy) -> void:
	_registry = registry
	_occupancy = occupancy
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anclado abajo a la izquierda; al crecer el contenido el panel sube.
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = MARGIN
	offset_top = -MARGIN
	offset_bottom = -MARGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	custom_minimum_size = Vector2(PANEL_WIDTH, 0)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
	visible = false
	occupancy.occupancy_changed.connect(_on_occupancy_changed)


## Muestra la información de una habitación (null oculta el panel).
func show_room(room: Room) -> void:
	_shown_room = room
	if room == null:
		visible = false
		return
	var type: RoomType = _registry.get_type_of(room)
	var status: RoomStatus = _registry.get_status(room)
	var text: String = RoomTexts.panel_bbcode(room, type, status)
	if room.type_id == GuestRegistry.BEDROOM_TYPE:
		text += "\n" + RoomTexts.occupancy_line(_occupancy.occupant_of(room.id))
	_label.text = text
	visible = true


## Texto actual sin formato (para comprobaciones).
func get_plain_text() -> String:
	return _label.get_parsed_text()


func _on_occupancy_changed() -> void:
	if _shown_room != null:
		show_room(_shown_room)
