
struct Element: ~Copyable { var number: Int }
func trial(_ optional: borrowing Element?) -> Int? {
    optional.ref.map { $0.value.number }
}
