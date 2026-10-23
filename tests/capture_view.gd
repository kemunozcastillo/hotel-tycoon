extends SceneTree
## Herramienta de verificación visual (NO es un test automático; necesita ventana y GPU):
##   godot --path . --script res://tests/capture_view.gd -- <ruta_salida.png>
## Carga la escena principal, construye un baño de 2x2 y una sala con puerta, y guarda una captura.

const OUTPUT_DEFAULT: String = "user://capture.png"


func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var output: String = args[0] if args.size() > 0 else OUTPUT_DEFAULT

	var main: Node = load("res://view/main.tscn").instantiate()
	root.add_child(main)
	await process_frame # _ready de la escena corre antes de este punto
	_build_demo(main.state as GameState)

	# Esperar unos fotogramas para que se dibuje todo.
	for i in range(8):
		await process_frame
	var image: Image = root.get_texture().get_image()
	var error: Error = image.save_png(output)
	print("captura guardada en %s (%dx%d) error=%d" % [output, image.get_width(), image.get_height(), error])
	quit()


func _build_demo(state: GameState) -> void:
	# Baño de 2x2 en (12,12): 8 aristas, con puerta en la arista norte derecha.
	_room(state, Vector2i(12, 12), Vector2i(2, 2))
	state.build.remove_wall(Edge.from_side(Vector2i(13, 12), Edge.Side.NORTH), 0)
	# Sala de 5x3 al lado, con puerta en el oeste.
	_room(state, Vector2i(16, 12), Vector2i(5, 3))
	state.build.remove_wall(Edge.from_side(Vector2i(16, 13), Edge.Side.WEST), 0)
	# Un pasillo de suelo suelto y un tramo de pared sin suelo.
	for x in range(12, 21):
		state.build.place_floor(Vector2i(x, 16), 0)
	for x in range(8, 11):
		state.build.place_wall(Edge.from_side(Vector2i(x, 14), Edge.Side.NORTH), 0)


func _room(state: GameState, origin: Vector2i, size: Vector2i) -> void:
	for y in range(size.y):
		for x in range(size.x):
			state.build.place_floor(origin + Vector2i(x, y), 0)
	for x in range(size.x):
		state.build.place_wall(Edge.from_side(origin + Vector2i(x, 0), Edge.Side.NORTH), 0)
		state.build.place_wall(Edge.from_side(origin + Vector2i(x, size.y - 1), Edge.Side.SOUTH), 0)
	for y in range(size.y):
		state.build.place_wall(Edge.from_side(origin + Vector2i(0, y), Edge.Side.WEST), 0)
		state.build.place_wall(Edge.from_side(origin + Vector2i(size.x - 1, y), Edge.Side.EAST), 0)
