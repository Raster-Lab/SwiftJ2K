
struct Element: ~Copyable { var number: Int }
struct Wrapper: ~Copyable {
    var storage: Element
    var element: Element {
        borrow { storage }
        mutate { &storage }
    }
}
func run() {
    var wrapper = Wrapper(storage: Element(number: 3))
    wrapper.element.number += 1
    precondition(wrapper.element.number == 4)
    print("F05: value-type borrow/mutate passed")
}
run()
