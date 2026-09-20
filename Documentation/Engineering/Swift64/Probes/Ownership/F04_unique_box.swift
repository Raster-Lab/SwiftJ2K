
struct Element: ~Copyable { var number: Int }
func run() {
    var box = UniqueBox(Element(number: 3))
    box.value.number += 1
    let value = box.consume()
    precondition(value.number == 4)
    print("F04: unique box mutation and consume passed")
}
run()
