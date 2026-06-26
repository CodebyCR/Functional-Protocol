import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct FunctionalProtocolPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        FunctionalProtocolMacro.self,
    ]
}
