class_name AgentInfoPanel
extends PanelContainer
## Panel con el estado del agente seleccionado. Solo lee el AgentRegistry; no captura el ratón.

const PANEL_WIDTH: float = 300.0
const MARGIN: float = 8.0

var _registry: AgentRegistry
var _label: Label
var _agent_id: int = 0


func setup(registry: AgentRegistry) -> void:
	_registry = registry
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Anclado abajo a la derecha; al crecer el contenido el panel sube.
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = -PANEL_WIDTH - MARGIN
	offset_right = -MARGIN
	offset_top = -MARGIN
	offset_bottom = -MARGIN
	grow_vertical = Control.GROW_DIRECTION_BEGIN

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Con ajuste de línea el texto largo no se sale de la pantalla.
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	add_child(_label)
	registry.agent_state_changed.connect(_on_agent_changed)
	visible = false


## Muestra el agente indicado por id (0 oculta el panel).
func show_agent(agent_id: int) -> void:
	_agent_id = agent_id
	_refresh()


func get_plain_text() -> String:
	return _label.text


## Texto del estado de un agente.
static func describe(agent: Agent) -> String:
	var text: String = "Agente %d\n" % agent.id
	match agent.state:
		Agent.State.WALKING:
			text += "Camina hacia (%d, %d)" % [agent.destination.x, agent.destination.y]
		Agent.State.BLOCKED:
			text += "Bloqueado: no hay camino a (%d, %d)" % [agent.destination.x, agent.destination.y]
		_:
			text += "Quieto"
	text += "\nClic der.: enviarlo a una celda   Supr: eliminarlo"
	return text


func _on_agent_changed(agent: Agent) -> void:
	if agent.id == _agent_id:
		_refresh()


func _refresh() -> void:
	var agent: Agent = _registry.get_agent(_agent_id)
	if agent == null:
		visible = false
		return
	_label.text = describe(agent)
	visible = true
