extends TestCase
## Pruebas de la cola de prioridad.


func test_pops_in_priority_order() -> void:
	var heap := MinHeap.new()
	for priority: float in [5.0, 1.0, 4.0, 2.0, 3.0]:
		heap.push("p%d" % int(priority), priority)
	assert_eq(heap.size(), 5)
	var order: Array[String] = []
	while not heap.is_empty():
		order.append(heap.pop())
	assert_eq(order, ["p1", "p2", "p3", "p4", "p5"] as Array[String])


func test_ties_come_out_in_insertion_order() -> void:
	var heap := MinHeap.new()
	for name: String in ["a", "b", "c", "d"]:
		heap.push(name, 1.0)
	heap.push("primero", 0.5)
	var order: Array[String] = []
	while not heap.is_empty():
		order.append(heap.pop())
	assert_eq(order, ["primero", "a", "b", "c", "d"] as Array[String])


func test_peek_and_clear() -> void:
	var heap := MinHeap.new()
	heap.push(Vector2i(1, 2), 3.5)
	heap.push(Vector2i(3, 4), 2.5)
	assert_near(heap.peek_priority(), 2.5)
	assert_eq(heap.pop(), Vector2i(3, 4))
	heap.clear()
	assert_true(heap.is_empty())
	assert_eq(heap.size(), 0)


func test_matches_a_sort_on_random_data() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var heap := MinHeap.new()
	var expected: Array[float] = []
	for i in range(300):
		var priority: float = float(rng.randi_range(0, 50))
		heap.push(i, priority)
		expected.append(priority)
	expected.sort()
	var actual: Array[float] = []
	while not heap.is_empty():
		actual.append(heap.peek_priority())
		heap.pop()
	assert_eq(actual, expected)


func test_interleaved_push_and_pop() -> void:
	var heap := MinHeap.new()
	heap.push("b", 2.0)
	heap.push("a", 1.0)
	assert_eq(heap.pop(), "a")
	heap.push("c", 0.5)
	assert_eq(heap.pop(), "c")
	assert_eq(heap.pop(), "b")
	assert_true(heap.is_empty())
