
func run() {
    var number = 3
    do {
        var reference = MutableRef(&number)
        reference.value += 1
    }
    let reference = Ref(number)
    precondition(reference.value == 4)
    print("F07: scoped mutable and read references passed")
}
run()
