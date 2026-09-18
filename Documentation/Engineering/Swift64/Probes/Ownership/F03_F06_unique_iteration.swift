
struct Element: ~Copyable { var number: Int }
func run() {
    var array = UniqueArray<Element>(capacity: 3)
    array.append(Element(number: 1))
    array.append(Element(number: 2))
    var total = 0
    for element in array { total += element.number }
    precondition(total == 3 && array.count == 2)
    print("F03/F06: noncopyable element iteration passed")
}
run()
