extends TestCase
## Pruebas de los textos del dinero: importes, presupuestos y el informe de finanzas.


func _state(start: int = 1000) -> GameState:
	var rules := EconomyRules.new()
	rules.start_money = start
	return GameState.new(Vector2i(12, 10), null, rules)


# --- Importes ----------------------------------------------------------------------------------

func test_format_groups_thousands_with_dots() -> void:
	assert_eq(MoneyTexts.format(0), "0 €")
	assert_eq(MoneyTexts.format(7), "7 €")
	assert_eq(MoneyTexts.format(999), "999 €")
	assert_eq(MoneyTexts.format(1000), "1.000 €")
	assert_eq(MoneyTexts.format(1234567), "1.234.567 €")
	assert_eq(MoneyTexts.format(100000), "100.000 €")


func test_format_and_signed_with_negative_amounts() -> void:
	assert_eq(MoneyTexts.format(-85), "-85 €")
	assert_eq(MoneyTexts.format(-12345), "-12.345 €")
	assert_eq(MoneyTexts.signed(40), "+40 €")
	assert_eq(MoneyTexts.signed(-20), "-20 €")
	assert_eq(MoneyTexts.signed(0), "0 €")
	assert_eq(MoneyTexts.signed(2500), "+2.500 €")


func test_every_category_has_a_distinct_label() -> void:
	var labels: Dictionary = {}
	for category in range(Ledger.CATEGORY_COUNT):
		labels[MoneyTexts.category_label(category as Ledger.Category)] = true
	assert_eq(labels.size(), Ledger.CATEGORY_COUNT)
	assert_eq(MoneyTexts.category_label(Ledger.Category.UPKEEP), "Mantenimiento")


func test_clock_text() -> void:
	assert_eq(MoneyTexts.clock_text(8.0 * 60.0), "Día 1 08:00")
	assert_eq(MoneyTexts.clock_text(1440.0 + 14.0 * 60.0 + 5.9), "Día 2 14:05")


# --- Presupuestos ------------------------------------------------------------------------------

func test_quote_text_for_a_purchase() -> void:
	var state := _state()
	var quote: BuildQuote = state.build.quote(state.build.plan_build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0))
	assert_eq(MoneyTexts.quote_text(quote), "-104 €")


func test_quote_text_mentions_pieces_taken_from_the_inventory() -> void:
	var state := _state()
	state.inventory.add(BuildItem.Kind.FLOOR, BuildItem.Condition.NEW, 4)
	var quote: BuildQuote = state.build.quote(state.build.plan_fill_rect_floor(Rect2i(Vector2i(2, 2), Vector2i(3, 2)), 0))
	assert_eq(MoneyTexts.quote_text(quote), "-20 € · 4 del inventario")


func test_quote_text_for_selling_and_storing() -> void:
	var state := _state()
	var rect := Rect2i(Vector2i(2, 2), Vector2i(2, 1))
	state.build.fill_rect_floor(rect, 0)
	var selling: BuildQuote = state.build.quote(state.build.plan_clear_rect_floor(rect, 0))
	assert_eq(MoneyTexts.quote_text(selling), "+20 €")
	state.inventory.removal_mode = Inventory.RemovalMode.STORE
	var storing: BuildQuote = state.build.quote(state.build.plan_clear_rect_floor(rect, 0))
	assert_eq(MoneyTexts.quote_text(storing), "2 al inventario")


func test_quote_text_warns_when_there_is_no_money() -> void:
	var state := _state(50)
	var quote: BuildQuote = state.build.quote(state.build.plan_fill_rect_floor(Rect2i(Vector2i(1, 1), Vector2i(3, 3)), 0))
	assert_false(quote.affordable)
	assert_eq(MoneyTexts.quote_text(quote), "-90 € · ¡sin fondos! hacen falta 90 €")


func test_quote_text_is_empty_when_nothing_changes_or_everything_is_free() -> void:
	var state := _state()
	assert_eq(MoneyTexts.quote_text(state.build.quote([] as Array[BuildOp])), "")
	var free_state := GameState.new(Vector2i(12, 10))
	var free_quote: BuildQuote = free_state.build.quote(free_state.build.plan_fill_rect_floor(Rect2i(Vector2i(1, 1), Vector2i(2, 2)), 0))
	assert_eq(MoneyTexts.quote_text(free_quote), "", "con reglas sin costes no hay nada que mostrar")


func test_insufficient_text() -> void:
	assert_eq(MoneyTexts.insufficient_text(480, 350), "Dinero insuficiente: hacen falta 480 € y hay 350 €")


# --- Informe ---------------------------------------------------------------------------------------

func test_day_lines_list_only_categories_with_movements() -> void:
	var state := _state()
	var day: int = state.clock.get_day()
	assert_true(MoneyTexts.day_lines(state.ledger, day).contains("Sin movimientos"))
	state.build.place_floor(Vector2i(1, 1), 0)
	var lines: String = MoneyTexts.day_lines(state.ledger, day)
	assert_true(lines.contains("Construcción") and lines.contains("-10 €"))
	assert_false(lines.contains("Mantenimiento"))
	assert_false(lines.contains("Sin movimientos"))


func test_finance_report_has_balance_today_days_and_recent_movements() -> void:
	var state := _state()
	state.build.build_room(Rect2i(Vector2i(2, 2), Vector2i(2, 2)), 0)
	state.clock.total_minutes += 1440.0
	state.ledger.record(Ledger.Category.STAY_DEPOSIT, 20, "Anticipo del huésped 1")
	var text: String = MoneyTexts.finance_report(state.ledger, state.clock.get_day(), state.clock.total_minutes)
	assert_true(text.contains("Saldo"))
	assert_true(text.contains("916 €"), "1000 - 104 + 20")
	assert_true(text.contains("Hoy"))
	assert_true(text.contains("Anticipos de estancias"))
	assert_true(text.contains("Últimos días"))
	assert_true(text.contains("Día 1:") and text.contains("Día 2:"), "los dos días con su resumen")
	assert_true(text.contains("Movimientos recientes"))
	assert_true(text.contains("Anticipo del huésped 1"))
	assert_true(text.contains("Construcción: 4 suelos"), "también los movimientos anteriores")


func test_finance_report_without_movements() -> void:
	var state := _state()
	var text: String = MoneyTexts.finance_report(state.ledger, state.clock.get_day(), state.clock.total_minutes)
	assert_true(text.contains("1.000 €"))
	assert_true(text.contains("Ninguno"))
	assert_true(text.contains("Sin movimientos"))


func test_finance_report_only_lists_the_last_days() -> void:
	var state := _state()
	state.clock.total_minutes += 20.0 * 1440.0
	var text: String = MoneyTexts.finance_report(state.ledger, state.clock.get_day(), state.clock.total_minutes)
	assert_false(text.contains("Día 1:"), "el día 1 queda fuera de los últimos siete")
	assert_true(text.contains("Día %d:" % state.clock.get_day()))
	assert_eq(text.count("  Día "), MoneyTexts.REPORT_DAYS)
