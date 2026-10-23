extends TestCase
## Pruebas del catálogo de tipos de habitación y de su validación al cargar.


func _entry(extra: String = "") -> String:
	return '{"id": "x", "name": "Equis", "color": "#112233", "min_area": 4' + extra + '}'


func _wrap(entries: Array[String]) -> String:
	return '{"room_types": [' + ", ".join(entries) + ']}'


func test_default_file_loads_cleanly() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.load_default()
	assert_eq(catalog.warnings, [] as Array[String], "sin avisos")
	assert_eq(catalog.get_types().size(), 2)
	assert_true(catalog.has_type(&"bedroom"))
	assert_true(catalog.has_type(&"bathroom"))


func test_default_bathroom_and_bedroom_values() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.load_default()
	var bathroom: RoomType = catalog.get_type(&"bathroom")
	assert_eq(bathroom.display_name, "Baño")
	assert_eq(bathroom.min_area, 4)
	assert_eq(bathroom.max_area, 9)
	assert_eq(bathroom.min_short_side, 2)
	assert_eq(bathroom.min_doors, 1)
	assert_true(bathroom.requires_complete_floor)
	var bedroom: RoomType = catalog.get_type(&"bedroom")
	assert_eq(bedroom.display_name, "Dormitorio")
	assert_eq(bedroom.min_area, 6)
	assert_eq(bedroom.max_area, 20)


func test_types_keep_file_order_and_lookup_unknown_is_null() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.load_default()
	var ids: Array[StringName] = []
	for type: RoomType in catalog.get_types():
		ids.append(type.id)
	assert_eq(ids, [&"bedroom", &"bathroom"] as Array[StringName])
	assert_eq(catalog.get_type(&"spa"), null)
	assert_false(catalog.has_type(&"spa"))


func test_get_types_returns_a_copy() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.load_default()
	catalog.get_types().clear()
	assert_eq(catalog.get_types().size(), 2)


func test_defaults_for_optional_fields() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap(['{"id": "a", "name": "A"}']))
	assert_eq(catalog.warnings.size(), 0)
	var type: RoomType = catalog.get_type(&"a")
	assert_eq(type.min_area, 1)
	assert_eq(type.max_area, 0, "0 = sin límite")
	assert_eq(type.min_short_side, 0)
	assert_eq(type.min_doors, 0)
	assert_true(type.requires_complete_floor)
	assert_eq(type.color, Color.WHITE)


func test_color_is_parsed() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap([_entry()]))
	assert_eq(catalog.get_type(&"x").color, Color.html("#112233"))


func test_invalid_json_gives_empty_catalog_with_warning() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse("{ esto no es json")
	assert_eq(catalog.get_types().size(), 0)
	assert_eq(catalog.warnings.size(), 1)
	assert_true(catalog.warnings[0].contains("JSON inválido"))


func test_wrong_structure_gives_warning() -> void:
	assert_eq(RoomTypeCatalog.parse("[]").warnings.size(), 1)
	assert_eq(RoomTypeCatalog.parse('{"otra_cosa": 1}').warnings.size(), 1)
	assert_eq(RoomTypeCatalog.parse('{"room_types": 5}').warnings.size(), 1)


func test_invalid_entries_are_skipped_but_valid_ones_survive() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap([
		'{"name": "Sin id"}',
		'{"id": "ok", "name": "Bien"}',
		'{"id": "sinnombre"}',
		'"no soy un objeto"',
	]))
	assert_eq(catalog.get_types().size(), 1)
	assert_true(catalog.has_type(&"ok"))
	assert_eq(catalog.warnings.size(), 3, "una advertencia por cada entrada descartada")


func test_bad_numbers_and_colors_are_rejected() -> void:
	for extra: String in [
		', "min_area": 0',
		', "min_area": -3',
		', "min_area": 2.5',
		', "min_area": "cuatro"',
		', "max_area": -1',
		', "min_doors": 1.1',
		', "color": "rojo-casi"',
		', "requires_complete_floor": "si"',
	]:
		var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap(['{"id": "x", "name": "X"' + extra + '}']))
		assert_eq(catalog.get_types().size(), 0, "se rechaza %s" % extra)
		assert_true(catalog.warnings.size() >= 1, "con aviso para %s" % extra)


func test_max_area_must_not_be_below_min_area() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap(['{"id": "x", "name": "X", "min_area": 8, "max_area": 5}']))
	assert_eq(catalog.get_types().size(), 0)
	assert_true(catalog.warnings[0].contains("max_area"))


func test_duplicate_ids_keep_the_first() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap([
		'{"id": "d", "name": "Primero", "min_area": 2}',
		'{"id": "d", "name": "Segundo", "min_area": 9}',
	]))
	assert_eq(catalog.get_types().size(), 1)
	assert_eq(catalog.get_type(&"d").display_name, "Primero")
	assert_eq(catalog.warnings.size(), 1)


func test_unknown_fields_are_ignored() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.parse(_wrap([_entry(', "campo_futuro": [1, 2, 3]')]))
	assert_eq(catalog.get_types().size(), 1)
	assert_eq(catalog.warnings.size(), 0)


func test_missing_file_gives_empty_catalog_with_warning() -> void:
	var catalog: RoomTypeCatalog = RoomTypeCatalog.load_file("res://data/no_existe.json", false)
	assert_eq(catalog.get_types().size(), 0)
	assert_eq(catalog.warnings.size(), 1)
