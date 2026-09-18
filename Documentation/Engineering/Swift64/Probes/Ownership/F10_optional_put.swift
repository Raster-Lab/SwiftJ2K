
struct Element: ~Copyable { var number: Int }
func trial(_ optional: inout Element?) {
    var reference = optional.put(Element(number: 3))
    reference.value.number += 1
}
