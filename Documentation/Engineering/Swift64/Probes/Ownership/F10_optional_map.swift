
struct Element: ~Copyable { var number: Int }
func trial(_ optional: consuming Element?) -> Int? {
    optional.map { $0.number }
}
