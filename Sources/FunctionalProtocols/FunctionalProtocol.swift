// MARK: - @FunctionalProtocol Macro Declaration
//
// Attach this macro to a protocol with exactly one method requirement.
// It generates:
//   1. A generic bridge struct `Any<ProtocolName>` (peer) that wraps a closure
//   2. A `static func create(...)` factory method on the protocol (extension)
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
//   processData(using: .create { $0.uppercased() })

@attached(peer, names: prefixed(Any))
@attached(extension, names: named(create))
public macro FunctionalProtocol() = #externalMacro(
    module: "FunctionalProtocolMacros",
    type: "FunctionalProtocolMacro"
)
