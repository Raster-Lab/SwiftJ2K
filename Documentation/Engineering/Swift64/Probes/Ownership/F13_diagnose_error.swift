
@available(*, deprecated, message: "probe only")
func oldFunction() { }
@diagnose(DeprecatedDeclaration, as: error, reason: "Test local elevation")
func caller() { oldFunction() }
