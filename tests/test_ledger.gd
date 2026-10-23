extends TestCase
## Pruebas del libro de movimientos: saldo, totales por día y categoría, y señales.


func _ledger(start: int = 1000) -> Ledger:
	return Ledger.new(start, GameClock.new())


func test_record_changes_the_balance_and_ignores_zero() -> void:
	var ledger := _ledger(1000)
	ledger.record(Ledger.Category.BUILD, -150, "suelo")
	ledger.record(Ledger.Category.SALE, 40)
	ledger.record(Ledger.Category.SALE, 0)
	assert_eq(ledger.balance, 890)
	assert_eq(ledger.get_recent(10).size(), 2, "el movimiento de 0 no se anota")


func test_can_afford() -> void:
	var ledger := _ledger(100)
	assert_true(ledger.can_afford(100))
	assert_true(ledger.can_afford(0))
	assert_false(ledger.can_afford(101))
	ledger.record(Ledger.Category.UPKEEP, -150)
	assert_eq(ledger.balance, -50, "el mantenimiento sí puede dejar el saldo en negativo")
	assert_false(ledger.can_afford(1))
	assert_true(ledger.can_afford(-20), "un importe negativo (ingreso) siempre se puede")


func test_day_totals_by_category_income_expenses_and_net() -> void:
	var clock := GameClock.new()
	var ledger := Ledger.new(0, clock)
	ledger.record(Ledger.Category.BUILD, -100)
	ledger.record(Ledger.Category.BUILD, -30)
	ledger.record(Ledger.Category.STAY_DEPOSIT, 20)
	ledger.record(Ledger.Category.STAY_FINAL, 20)
	ledger.record(Ledger.Category.DEPOSIT_REFUND, -20)
	var day: int = clock.get_day()
	assert_eq(ledger.get_day_total(day, Ledger.Category.BUILD), -130)
	assert_eq(ledger.get_day_total(day, Ledger.Category.STAY_DEPOSIT), 20)
	assert_eq(ledger.get_day_total(day, Ledger.Category.UPKEEP), 0, "categoría sin movimientos")
	assert_eq(ledger.get_day_income(day), 40)
	assert_eq(ledger.get_day_expenses(day), 150)
	assert_eq(ledger.get_day_net(day), -110)
	assert_eq(ledger.balance, -110)


func test_movements_are_filed_under_the_day_of_the_clock() -> void:
	var clock := GameClock.new()
	var ledger := Ledger.new(500, clock)
	var first_day: int = clock.get_day()
	ledger.record(Ledger.Category.UPKEEP, -10)
	clock.total_minutes += 24.0 * 60.0
	ledger.record(Ledger.Category.UPKEEP, -25)
	clock.total_minutes += 3.0 * 24.0 * 60.0
	ledger.record(Ledger.Category.SALE, 8)
	assert_eq(ledger.get_days(), [first_day, first_day + 1, first_day + 4] as Array[int])
	assert_eq(ledger.get_day_total(first_day, Ledger.Category.UPKEEP), -10)
	assert_eq(ledger.get_day_total(first_day + 1, Ledger.Category.UPKEEP), -25)
	assert_eq(ledger.get_day_net(first_day + 4), 8)
	assert_eq(ledger.get_day_net(first_day + 2), 0, "un día sin movimientos")


func test_recent_transactions_are_newest_first_with_their_details() -> void:
	var ledger := _ledger()
	ledger.record(Ledger.Category.BUILD, -10, "uno")
	ledger.record(Ledger.Category.SALE, 5, "dos")
	ledger.record(Ledger.Category.UPKEEP, -3, "tres")
	var recent: Array[Dictionary] = ledger.get_recent(2)
	assert_eq(recent.size(), 2)
	assert_eq(recent[0]["note"], "tres")
	assert_eq(recent[1]["note"], "dos")
	assert_eq(recent[0]["category"], Ledger.Category.UPKEEP)
	assert_eq(recent[0]["amount"], -3)
	assert_eq(ledger.get_recent(50).size(), 3, "pedir más de los que hay devuelve todos")


func test_only_the_latest_transactions_are_kept_but_the_day_totals_are_complete() -> void:
	var clock := GameClock.new()
	var ledger := Ledger.new(0, clock)
	for i in range(Ledger.MAX_TRANSACTIONS + 50):
		ledger.record(Ledger.Category.SALE, 1)
	assert_eq(ledger.get_recent(10000).size(), Ledger.MAX_TRANSACTIONS)
	assert_eq(ledger.get_day_total(clock.get_day(), Ledger.Category.SALE), Ledger.MAX_TRANSACTIONS + 50)
	assert_eq(ledger.balance, Ledger.MAX_TRANSACTIONS + 50)


func test_signals() -> void:
	var ledger := _ledger(100)
	var balances: Array[int] = []
	var notes: Array[String] = []
	ledger.balance_changed.connect(func(balance: int) -> void: balances.append(balance))
	ledger.transaction_recorded.connect(func(transaction: Dictionary) -> void: notes.append(transaction["note"]))
	ledger.record(Ledger.Category.BUILD, -30, "a")
	ledger.record(Ledger.Category.SALE, 0, "ignorado")
	ledger.record(Ledger.Category.SALE, 10, "b")
	assert_eq(balances, [70, 80] as Array[int])
	assert_eq(notes, ["a", "b"] as Array[String])
