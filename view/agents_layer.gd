class_name AgentsLayer
extends Node2D
## Mantiene un AgentView por cada agente (los crea y quita según las señales del registro), marca
## el agente seleccionado y dibuja su ruta. Los AgentView viven en `entities_root` para
## ordenarse por Y con las paredes; el trazo de la ruta lo dibuja esta capa, por encima del suelo.

const PATH_COLOR: Color = Color(1.0, 0.92, 0.4, 0.8)
const DESTINATION_COLOR: Color = Color(1.0, 0.92, 0.4, 0.3)

var _registry: AgentRegistry
var _guests: GuestRegistry
var _entities_root: Node2D
var _views: Dictionary = {} # id -> AgentView
var _selected_id: int = 0


func setup(registry: AgentRegistry, guests: GuestRegistry, entities_root: Node2D) -> void:
	_registry = registry
	_guests = guests
	_entities_root = entities_root
	z_index = 8
	registry.agent_added.connect(_on_agent_added)
	registry.agent_removed.connect(_on_agent_removed)
	registry.agent_state_changed.connect(_on_agent_state_changed)
	for agent: Agent in registry.get_agents():
		_add_view(agent)


func get_view_count() -> int:
	return _views.size()


func get_view(id: int) -> AgentView:
	return _views.get(id) as AgentView


## Marca un agente como seleccionado (0 = ninguno).
func set_selected(id: int) -> void:
	if _selected_id == id:
		return
	var previous: AgentView = _views.get(_selected_id) as AgentView
	if previous != null:
		previous.selected = false
	_selected_id = id
	var current: AgentView = _views.get(id) as AgentView
	if current != null:
		current.selected = true
	queue_redraw()


func _process(_delta: float) -> void:
	# El trazo parte de la posición del agente, que cambia cada fotograma.
	if _selected_id != 0:
		queue_redraw()


func _draw() -> void:
	var agent: Agent = _registry.get_agent(_selected_id)
	if agent == null or agent.path.is_empty():
		return
	var points := PackedVector2Array([IsoProjection.grid_to_world(agent.position)])
	for cell: Vector2i in agent.path:
		points.append(IsoProjection.grid_to_world(Vector2(cell) + Vector2(0.5, 0.5)))
	draw_polyline(points, PATH_COLOR, 2.0)
	draw_colored_polygon(IsoProjection.cell_diamond(agent.destination), DESTINATION_COLOR)


func _on_agent_added(agent: Agent) -> void:
	_add_view(agent)


func _add_view(agent: Agent) -> void:
	var view := AgentView.new()
	_entities_root.add_child(view)
	view.setup(agent, _guests)
	view.selected = agent.id == _selected_id
	_views[agent.id] = view


func _on_agent_removed(agent: Agent) -> void:
	var view: AgentView = _views.get(agent.id) as AgentView
	if view != null:
		view.queue_free()
		_views.erase(agent.id)
	if agent.id == _selected_id:
		_selected_id = 0
	queue_redraw()


func _on_agent_state_changed(_agent: Agent) -> void:
	queue_redraw()
