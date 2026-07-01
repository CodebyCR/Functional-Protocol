// MARK: - @FunctionalProtocol Macro Declaration
//
// Attach this macro to a protocol with exactly one method requirement.
// It generates:
//   1. A generic bridge struct `<ProtocolName>Functor` (peer) that wraps a closure
//   2. A `static func closure(...)` factory method on the protocol (extension)
//
// Usage:
//   @FunctionalProtocol
//   protocol Transformer {
//       associatedtype Input
//       associatedtype Output
//       func transform(_ input: Input) -> Output
//   }
//
//   // Then call:
//   processData(use: .closure { $0.uppercased() })

@attached(peer, names: suffixed(Functor))
@attached(extension, names: named(closure))
public macro FunctionalProtocol() = #externalMacro(
    module: "FunctionalProtocolMacros",
    type: "FunctionalProtocolMacro"
)
