extends TestCase
## Pruebas de las reglas de economía (carga del JSON, precios y valores de venta).


func test_default_file_loads_cleanly_with_the_documented_values() -> void:
	var rules: EconomyRules = EconomyRules.load_default()
	assert_eq(rules.warnings, [] as Array[String], "sin avisos")
	assert_eq(rules.start_money, 2000)
	assert_eq(rules.price_of(BuildItem.Kind.FLOOR), 10)
	assert_eq(rules.price_of(BuildItem.Kind.WALL), 8)
	assert_eq(rules.price_of(BuildItem.Kind.DOOR), 25)
	assert_near(rules.sell_rate_new, 1.0)
	assert_near(rules.sell_rate_used, 0.85)
	assert_near(rules.new_window_minutes, 60.0)
	assert_near(rules.deposit_rate, 0.5)


func test_free_rules_cost_nothing() -> void:
	var rules: EconomyRules = EconomyRules.without_costs()
	assert_eq(rules.start_money, 0)
	for kind: int in [BuildItem.Kind.FLOOR, BuildItem.Kind.WALL, BuildItem.Kind.DOOR]:
		assert_eq(rules.price_of(kind as BuildItem.Kind), 0)
		assert_eq(rules.sale_value(kind as BuildItem.Kind, BuildItem.Condition.NEW), 0)


func test_sale_value_new_is_full_price_and_used_is_85_percent() -> void:
	var rules: EconomyRules = EconomyRules.load_default()
	assert_eq(rules.sale_value(BuildItem.Kind.DOOR, BuildItem.Condition.NEW), 25)
	assert_eq(rules.sale_value(BuildItem.Kind.DOOR, BuildItem.Condition.USED), 21, "25 * 0,85 = 21,25 -> 21")
	assert_eq(rules.sale_value(BuildItem.Kind.WALL, BuildItem.Condition.USED), 7, "8 * 0,85 = 6,8 -> 7")
	assert_eq(rules.sale_value(BuildItem.Kind.FLOOR, BuildItem.Condition.USED), 9, "10 * 0,85 = 8,5 -> 9")
	assert_eq(rules.sale_value(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW), 10)


func test_selling_never_pays_more_than_the_price() -> void:
	for price in range(0, 200):
		var rules := EconomyRules.new()
		rules.floor_price = price
		for condition: int in [BuildItem.Condition.NEW, BuildItem.Condition.USED]:
			assert_true(rules.sale_value(BuildItem.Kind.FLOOR, condition as BuildItem.Condition) <= price, "precio %d" % price)
		assert_true(rules.sale_value(BuildItem.Kind.FLOOR, BuildItem.Condition.USED) <= rules.sale_value(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW), "usada nunca vale más que nueva (precio %d)" % price)


func test_deposit_is_half_rounded_down_and_the_rest_is_the_balance() -> void:
	var rules: EconomyRules = EconomyRules.load_default()
	assert_eq(rules.deposit_of(40), 20)
	assert_eq(rules.deposit_of(41), 20, "importe impar: el anticipo redondea hacia abajo")
	assert_eq(rules.deposit_of(0), 0)
	assert_eq(41 - rules.deposit_of(41), 21, "y el resto se cobra al final")


func test_parse_overrides_only_valid_fields() -> void:
	var rules: EconomyRules = EconomyRules.parse('{"start_money": 500, "build_prices": {"wall": 3}, "deposit_rate": 0.25}')
	assert_eq(rules.warnings.size(), 0)
	assert_eq(rules.start_money, 500)
	assert_eq(rules.wall_price, 3)
	assert_eq(rules.floor_price, 10, "lo que no aparece se queda por defecto")
	assert_near(rules.deposit_rate, 0.25)


func test_invalid_fields_are_ignored_with_a_warning() -> void:
	for bad_json: String in [
		'{"start_money": -5}',
		'{"start_money": 12.5}',
		'{"start_money": "mucho"}',
		'{"build_prices": {"floor": -1}}',
		'{"build_prices": 3}',
		'{"sell_rate_new": 1.5}',
		'{"sell_rate_used": -0.1}',
		'{"deposit_rate": "mitad"}',
		'{"new_window_minutes": -10}',
	]:
		var rules: EconomyRules = EconomyRules.parse(bad_json)
		assert_true(rules.warnings.size() >= 1, "avisa de %s" % bad_json)
		assert_eq(rules.start_money, 2000 if not bad_json.contains("start_money") else 2000, "se queda el valor por defecto")
		assert_eq(rules.floor_price, 10)


func test_used_rate_cannot_exceed_new_rate() -> void:
	var rules: EconomyRules = EconomyRules.parse('{"sell_rate_new": 0.7, "sell_rate_used": 0.9}')
	assert_eq(rules.warnings.size(), 1)
	assert_near(rules.sell_rate_used, 0.7, "se iguala a la de nueva")


func test_broken_json_and_missing_file_fall_back_to_defaults() -> void:
	var broken: EconomyRules = EconomyRules.parse("{ esto no es json")
	assert_eq(broken.warnings.size(), 1)
	assert_eq(broken.start_money, 2000)
	assert_eq(EconomyRules.parse("[1, 2]").warnings.size(), 1)
	var missing: EconomyRules = EconomyRules.load_file("res://data/no_existe.json", false)
	assert_eq(missing.warnings.size(), 1)
	assert_eq(missing.floor_price, 10)


func test_build_item_helpers() -> void:
	assert_eq(BuildItem.kind_of_edge(CellTypes.EdgeType.WALL), BuildItem.Kind.WALL)
	assert_eq(BuildItem.kind_of_edge(CellTypes.EdgeType.DOOR), BuildItem.Kind.DOOR)
	assert_eq(BuildItem.kind_of_edge(CellTypes.EdgeType.NONE), -1)
	assert_eq(BuildItem.label(BuildItem.Kind.FLOOR), "Suelo")
	assert_eq(BuildItem.label_plural(BuildItem.Kind.DOOR), "Puertas")
