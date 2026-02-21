import Foundation

protocol ContextProvider {
    func capture() async -> ScreenContext
}

struct LocalContextProvider: ContextProvider {
    private let assembler = ContextAssembler()

    func capture() async -> ScreenContext {
        assembler.assemble()
    }
}
