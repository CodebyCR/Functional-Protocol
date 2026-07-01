# System Prompt for Implementing the `@FunctionalProtocol` Macro

## Context & Objective
Swift lacks a native way to instantiate protocols with a single method (Single Abstract Method / SAM interfaces) directly via a closure (lambda syntax), as is possible in Java with `@FunctionalInterface`.

The goal is to create a Swift 6 compiler macro named `@FunctionalProtocol`. This macro should be attached to a **Protocol**, analyze the central method, and automatically generate the infrastructure to instantiate the protocol ad-hoc via trailing closure syntax. Maximum compile-time performance (inlining, generic specialization) must be guaranteed.

---

## Specification of Behavior (Code Generation)

### 1. The Developer Interface (Input)
The developer only defines the protocol and declares the types via `associatedtype`:

```swift
@FunctionalProtocol
protocol Transformer {
    associatedtype Input
    associatedtype Output
    
    func transform(_ input: Input) -> Output
}
```

### 2. The Expected AST Transformation (Macro Output)
The macro must act as a combined `@attached(peer)` and `@attached(extension)` macro and inject the following code into the file:

#### A. The Generic Bridge Struct (Peer Macro)
A concretely realized, generic struct is generated that implements the protocol. The name is composed of `[ProtocolName]` + `Functor`.

```swift
@frozen
public struct TransformerFunctor<Input, Output>: Transformer {
    @usableFromInline
    internal let _closure: @escaping (Input) -> Output

    @inlinable
    public init(_ closure: @escaping (Input) -> Output) {
        self._closure = closure
    }

    @inlinable
    public func transform(_ input: Input) -> Output {
        return _closure(input)
    }

    // Allows calling the instance like a function
    @inlinable
    public func callAsFunction(_ input: Input) -> Output {
        return _closure(input)
    }
}
```

#### B. The Protocol Extension for Instantiation (Extension Macro)
To enable the elegant dot syntax when passing, a static factory method is added to the protocol:

```swift
extension Transformer {
    @inlinable
    public static func closure<I, O>(_ closure: @escaping (I) -> O) -> TransformerFunctor<I, O> where Self == TransformerFunctor<I, O> {
        return TransformerFunctor(closure)
    }
}
```

---

## Desired Call Syntax (Usage Example)

After code generation, the framework must be usable as follows:

```swift
// 1. Definition of an API that expects the protocol (Zero-Cost via 'some')
func processData(using transformer: some Transformer) {
    let result = transformer.transform("Swift 6")
    print(result)
}

// 2. Elegant lambda call via type inference
processData(using: .create { $0.uppercased() })
```

---

## Technical Requirements for the Macro Implementation (`SwiftSyntax`)

1. **AST Parsing:** The macro must parse the `ProtocolDeclSyntax`. It must validate that exactly **one** method is defined in the protocol. If more or no methods are present, the macro must throw a compile-time error via `Diagnostics`.
2. **Type Extraction:** The macro must read the names of the `associatedtype` declarations (or the argument and return types of the method) to correctly map the generics `<Input, Output>` for the `Any...` struct.
3. **Performance Attributes:** The generated methods *must* be annotated with `@inlinable`. The struct should be marked with `@frozen` to allow the compiler cross-module optimizations (specialization and full inlining of the closure).
4. **Swift 6 Concurrency (Future-Proofing):** The macro should optionally detect whether the protocol or the method is marked as `@Sendable` or `async`, and forward these attributes to the generated initializer and the `...Functor` struct.

---

### Work Instructions
Generate the complete Swift code for the macro definition (`Macro` protocol), the implementation of the AST transformation using `SwiftSyntax`, and the corresponding client test code.
