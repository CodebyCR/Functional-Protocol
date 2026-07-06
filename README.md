# `@FunctionalProtocol`

A Swift 6 compiler macro that derives a zero-cost closure wrapper for any Single Abstract Method (SAM) protocol — one annotation, no boilerplate, full optimizer visibility.

```swift
@FunctionalProtocol
public protocol Transformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

// That's all. Now use it:
processData(use: .transform { $0.uppercased() })
```

---

## Motivation

### The Conformance Tax

Swift protocols are the canonical abstraction tool, but every protocol that an API accepts forces callers to pay a *conformance tax*: they must declare a named type. For protocols with a single method, this named type often contains nothing but a forwarding call:

```swift
// The API
func processData<T: Transformer>(use t: T, input: T.Input) { ... }

// The tax — a full type for one line of logic
struct UppercaseTransformer: Transformer {
    func transform(_ input: String) -> String { input.uppercased() }
}
processData(use: UppercaseTransformer(), input: "swift")
```

Three alternatives exist, and all carry costs:

| Approach | Problem |
|---|---|
| Named conforming struct | Boilerplate, clutters the namespace |
| Hand-rolled `@frozen` wrapper | Correct, but you write the same ritual for every protocol |
| Existential (`any Transformer`) | Heap allocation, no generic specialization, dynamic dispatch |

### The Hand-Rolled Wrapper is Right — But Tedious

The correct solution looks like this:

```swift
@frozen
public struct TransformerWrapper<Input, Output>: Transformer {
    @usableFromInline internal let _transform: (Input) -> Output

    @inlinable
    public init(_ block: @escaping (Input) -> Output) {
        self._transform = block
    }

    @inlinable
    public func transform(_ input: Input) -> Output {
        _transform(input)
    }
}

extension Transformer {
    @inlinable
    public static func transform<I, O>(
        _ block: @escaping (I) -> O
    ) -> TransformerWrapper<I, O> where Self == TransformerWrapper<I, O> {
        TransformerWrapper(block)
    }
}
```

This is `@frozen` for ABI stability, `@inlinable` for cross-module optimization, and `@usableFromInline` on the stored property so inlined callers can reach it. The compiler can specialize and fully inline it. But you write this boilerplate for *every single protocol*.

---

## Proposed Solution

`@FunctionalProtocol` is an attached macro. You annotate the protocol, and the compiler generates the entire bridge at compile time. The output is syntactically identical to the hand-rolled wrapper — `@frozen`, `@inlinable`, `@usableFromInline` — you just never read or maintain it.

```swift
// Before
struct UppercaseTransformer: Transformer {
    func transform(_ input: String) -> String { input.uppercased() }
}
processData(use: UppercaseTransformer(), input: "swift")

// After
processData(use: .transform { $0.uppercased() }, input: "swift")
```

The generated code is identical in performance characteristics to what you would write by hand. The difference is you don't have to.

---

## Detailed Design

### Generation Template

For a `public` protocol:

```swift
@FunctionalProtocol
public protocol Transformer: Sendable {
    associatedtype Input
    associatedtype Output
    func transform(_ input: consuming Input) async throws -> Output
}
```

The macro expands to exactly:

```swift
// — Peer (generated alongside the protocol declaration) —

@frozen
public struct TransformerWrapper<Input, Output>: Transformer {

    @usableFromInline
    internal let _transform: @Sendable (consuming Input) async throws -> Output

    @inlinable
    public init(_ closure: @escaping @Sendable (consuming Input) async throws -> Output) {
        self._transform = closure
    }

    @inlinable
    public func transform(_ input: consuming Input) async throws -> Output {
        return try await _transform(input)
    }

    // Allows calling the instance directly like a closure
    @inlinable
    public func callAsFunction(_ input: consuming Input) async throws -> Output {
        return try await _transform(input)
    }
}

// — Extension (adds the static factory to the protocol) —

extension Transformer {
    @inlinable
    public static func transform<Input, Output>(
        _ block: @escaping @Sendable (consuming Input) async throws -> Output
    ) -> TransformerWrapper<Input, Output>
    where Self == TransformerWrapper<Input, Output> {
        return TransformerWrapper(block)
    }
}
```

### Rules

| Rule | Detail |
|---|---|
| Factory name | Mirrors the SAM identifier — `func transform(...)` → `.transform { ... }` |
| Access modifier | Inherited from the protocol — `public protocol` → `public struct` |
| `@frozen` on internal types | Requires `@usableFromInline` — added automatically |
| `@Sendable` closure | Added when protocol inherits `Sendable` |
| Effects (`async`, `throws`, typed throws) | Extracted from the AST and forwarded 1:1 |
| Ownership (`consuming`, `borrowing`) | Preserved as part of the parameter type |
| `callAsFunction` collision | Suppressed when the SAM is itself named `callAsFunction` |

---

## What Works

### Basic: two associated types

```swift
@FunctionalProtocol
public protocol Transformer {
    associatedtype Input
    associatedtype Output
    func transform(_ input: Input) -> Output
}

// ✅ Static factory — name mirrors the method
processData(use: .transform { $0.uppercased() })

// ✅ Direct struct initializer
let t = TransformerWrapper<String, Int> { $0.count }

// ✅ callAsFunction — call the instance like a closure
t("Hello")  // → 5
```

### Concrete types (no associated types)

```swift
@FunctionalProtocol
public protocol Logger {
    func log(_ message: String)
}

// ✅ No generics in the factory — type is fully resolved
let logger = LoggerWrapper { print($0) }
acceptLogger(.log { print($0) })
```

### Effects: `async throws`

```swift
@FunctionalProtocol
public protocol Fetcher {
    associatedtype Resource
    func fetch(_ url: URL) async throws -> Resource
}

// ✅ Effects are forwarded to the closure signature
let f = FetcherWrapper<Data> { url in
    try await URLSession.shared.data(from: url).0
}
let data = try await f.fetch(someURL)
let data2 = try await f(someURL)          // callAsFunction also has async throws
```

### Typed throws (Swift 6)

```swift
@FunctionalProtocol
public protocol Validator {
    associatedtype Value
    func validate(_ value: Value) throws(ValidationError) -> Value
}

// ✅ Typed throws is preserved — no type erasure on the error
let v = ValidatorWrapper<Int> { n in
    guard n > 0 else { throw ValidationError.negative }
    return n
}
```

### Sendable concurrency

```swift
@FunctionalProtocol
public protocol Worker: Sendable {
    associatedtype Job
    func perform(_ job: Job) async -> Void
}

// ✅ Closure is @Sendable — safe to cross actor boundaries
let w = WorkerWrapper<String> { job in
    await Task.detached { print(job) }.value
}
```

### Ownership modifiers

```swift
@FunctionalProtocol
public protocol Sink {
    associatedtype Element
    func consume(_ element: consuming Element)
}

// ✅ consuming is preserved in both the closure type and the method signature
let sink = SinkWrapper<Data> { data in process(data) }
```

### Visibility inheritance

```swift
// ✅ public protocol → public struct (usable across modules)
@FunctionalProtocol
public protocol Serializer { ... }
// Generates: public struct SerializerWrapper ...

// ✅ package protocol → package struct
@FunctionalProtocol
package protocol InternalService { ... }
// Generates: package struct InternalServiceWrapper ...

// ✅ internal protocol → @usableFromInline struct (satisfies @frozen constraint)
@FunctionalProtocol
protocol Helper { ... }
// Generates: @frozen @usableFromInline struct HelperWrapper ...
```

### Protocol-level generics via `associatedtype`

```swift
// ✅ associatedtype is the correct way to parameterize the protocol
@FunctionalProtocol
public protocol Mapper {
    associatedtype Input
    associatedtype Output
    func map(_ input: Input) -> Output
}
```

### `callAsFunction` as the SAM name

```swift
// ✅ Collision protection: when the SAM is callAsFunction,
//    the synthesized wrapper is suppressed (no duplicate method error)
@FunctionalProtocol
public protocol Callable {
    func callAsFunction(_ value: Int) -> Int
}

let c = CallableWrapper { $0 * 2 }
c(21)  // → 42
```

### Default implementations in protocol extensions

```swift
// ✅ Methods in extensions don't count toward the SAM limit
@FunctionalProtocol
public protocol Predicate {
    associatedtype Element
    func evaluate(_ element: Element) -> Bool
}

extension Predicate {
    func negate(_ element: Element) -> Bool { !evaluate(element) }
}
// ↑ Fine — negate() is in an extension, not in the primary declaration
```

---

## What Doesn't Work

### Multiple methods in the primary declaration

```swift
@FunctionalProtocol
protocol TwoMethods {
    func encode() -> Data
    func decode(_ data: Data)   // ❌ error: '@FunctionalProtocol' requires exactly
}                               //           one method in the protocol, but found multiple.
```

### No methods

```swift
@FunctionalProtocol
protocol MarkerProtocol {
    associatedtype ID   // ❌ error: '@FunctionalProtocol' requires exactly
}                       //           one method in the protocol, but found none.
```

### Applied to a non-protocol type

```swift
@FunctionalProtocol
struct Wrapper { ... }  // ❌ error: '@FunctionalProtocol' can only be applied
                        //           to a protocol declaration.

@FunctionalProtocol
class Service { ... }   // ❌ same error
```

### Method-level generic parameters

Swift cannot store a generic closure as a property — `let f: <T>(T) -> T` is not valid Swift.
Use `associatedtype` at the protocol level instead.

```swift
@FunctionalProtocol
protocol Caster {
    func cast<T>(_ value: Any) -> T   // ❌ error: '@FunctionalProtocol' does not support
}                                     //           method-level generic parameters; use
                                      //           protocol-level 'associatedtype' instead.

// ✅ Correct version:
@FunctionalProtocol
protocol Caster {
    associatedtype T
    func cast(_ value: Any) -> T
}
```

### Existential / `any` usage (not a macro error — a Swift limitation)

```swift
// ❌ Protocols with associated types cannot be used as existentials directly.
//    This is a Swift language constraint, not specific to this macro.
var box: any Transformer = .transform { $0 }  // ❌ use 'some Transformer' or a concrete type

// ✅ Use 'some' (opaque return) or the concrete Wrapper type
func process(using t: some Transformer) { ... }
let t: TransformerWrapper<String, String> = .transform { $0.uppercased() }
```

---

## Comparison: Java `@FunctionalInterface` vs Swift `@FunctionalProtocol`

| | Java `@FunctionalInterface` | Swift `@FunctionalProtocol` |
|---|---|---|
| Validates single abstract method | Yes | Yes — compile-time diagnostic |
| Generates code | No | Yes — full `@frozen` bridge struct |
| Enables closure / lambda syntax | Via JVM language feature | Via generated static factory |
| Runtime cost | Object allocation + virtual dispatch | Zero — static dispatch, inlinable |
| Type erasure | Yes (object reference) | No — concrete generic struct |
| Cross-module optimization | No | Yes — `@frozen` + `@inlinable` |
| Effects forwarding | No | Yes — `async`, `throws`, typed throws |
| Sendable safety | No | Yes — `@Sendable` when protocol is `Sendable` |

---

## Requirements

- Swift 6.0+
- macOS 14+ / iOS 17+ / any platform with Swift macro support

---

## License

MIT
