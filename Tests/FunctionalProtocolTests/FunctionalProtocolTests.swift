import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations are loaded from the FunctionalProtocolMacros module.
#if canImport(FunctionalProtocolMacros)
import FunctionalProtocolMacros

let testMacros: [String: Macro.Type] = [
    "FunctionalProtocol": FunctionalProtocolMacro.self,
]
#endif

final class FunctionalProtocolTests: XCTestCase {

    // MARK: - Happy Path: Basic Transformer (2 associated types)

    func testBasicTransformerExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Transformer {
                associatedtype Input
                associatedtype Output

                func transform(_ input: Input) -> Output
            }
            """,
            expandedSource: """
            protocol Transformer {
                associatedtype Input
                associatedtype Output

                func transform(_ input: Input) -> Output
            }

            @frozen
            @usableFromInline
            struct TransformerWrapper<Input, Output>: Transformer {
                @usableFromInline
                internal let _transform: (Input) -> Output

                @inlinable
                init(_ closure: @escaping (Input) -> Output) {
                    self._transform = closure
                }

                @inlinable
                func transform(_ input: Input) -> Output {
                    return _transform(input)
                }

                @inlinable
                func callAsFunction(_ input: Input) -> Output {
                    return _transform(input)
                }
            }

            extension Transformer {
                @inlinable
                static func transform<Input, Output>(_ block: @escaping (Input) -> Output) -> TransformerWrapper<Input, Output> where Self == TransformerWrapper<Input, Output> {
                    return TransformerWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: Predicate (1 associated type, concrete return)

    func testPredicateExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Predicate {
                associatedtype Element

                func evaluate(_ element: Element) -> Bool
            }
            """,
            expandedSource: """
            protocol Predicate {
                associatedtype Element

                func evaluate(_ element: Element) -> Bool
            }

            @frozen
            @usableFromInline
            struct PredicateWrapper<Element>: Predicate {
                @usableFromInline
                internal let _evaluate: (Element) -> Bool

                @inlinable
                init(_ closure: @escaping (Element) -> Bool) {
                    self._evaluate = closure
                }

                @inlinable
                func evaluate(_ element: Element) -> Bool {
                    return _evaluate(element)
                }

                @inlinable
                func callAsFunction(_ element: Element) -> Bool {
                    return _evaluate(element)
                }
            }

            extension Predicate {
                @inlinable
                static func evaluate<Element>(_ block: @escaping (Element) -> Bool) -> PredicateWrapper<Element> where Self == PredicateWrapper<Element> {
                    return PredicateWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: No Associated Types (concrete types only)

    func testConcreteTypesExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Logger {
                func log(_ message: String)
            }
            """,
            expandedSource: """
            protocol Logger {
                func log(_ message: String)
            }

            @frozen
            @usableFromInline
            struct LoggerWrapper: Logger {
                @usableFromInline
                internal let _log: (String) -> Void

                @inlinable
                init(_ closure: @escaping (String) -> Void) {
                    self._log = closure
                }

                @inlinable
                func log(_ message: String) {
                    return _log(message)
                }

                @inlinable
                func callAsFunction(_ message: String) {
                    return _log(message)
                }
            }

            extension Logger {
                @inlinable
                static func log(_ block: @escaping (String) -> Void) -> LoggerWrapper where Self == LoggerWrapper {
                    return LoggerWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: Throwing Method

    func testThrowingMethodExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Parser {
                associatedtype Input
                associatedtype Output

                func parse(_ input: Input) throws -> Output
            }
            """,
            expandedSource: """
            protocol Parser {
                associatedtype Input
                associatedtype Output

                func parse(_ input: Input) throws -> Output
            }

            @frozen
            @usableFromInline
            struct ParserWrapper<Input, Output>: Parser {
                @usableFromInline
                internal let _parse: (Input) throws -> Output

                @inlinable
                init(_ closure: @escaping (Input) throws -> Output) {
                    self._parse = closure
                }

                @inlinable
                func parse(_ input: Input) throws -> Output {
                    return try _parse(input)
                }

                @inlinable
                func callAsFunction(_ input: Input) throws -> Output {
                    return try _parse(input)
                }
            }

            extension Parser {
                @inlinable
                static func parse<Input, Output>(_ block: @escaping (Input) throws -> Output) -> ParserWrapper<Input, Output> where Self == ParserWrapper<Input, Output> {
                    return ParserWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: Async Throwing Method

    func testAsyncThrowingMethodExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol AsyncFetcher {
                associatedtype Input
                associatedtype Output

                func fetch(_ input: Input) async throws -> Output
            }
            """,
            expandedSource: """
            protocol AsyncFetcher {
                associatedtype Input
                associatedtype Output

                func fetch(_ input: Input) async throws -> Output
            }

            @frozen
            @usableFromInline
            struct AsyncFetcherWrapper<Input, Output>: AsyncFetcher {
                @usableFromInline
                internal let _fetch: (Input) async throws -> Output

                @inlinable
                init(_ closure: @escaping (Input) async throws -> Output) {
                    self._fetch = closure
                }

                @inlinable
                func fetch(_ input: Input) async throws -> Output {
                    return try await _fetch(input)
                }

                @inlinable
                func callAsFunction(_ input: Input) async throws -> Output {
                    return try await _fetch(input)
                }
            }

            extension AsyncFetcher {
                @inlinable
                static func fetch<Input, Output>(_ block: @escaping (Input) async throws -> Output) -> AsyncFetcherWrapper<Input, Output> where Self == AsyncFetcherWrapper<Input, Output> {
                    return AsyncFetcherWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: Sendable Protocol

    func testSendableProtocolExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol SendableTransformer: Sendable {
                associatedtype Input
                associatedtype Output

                func transform(_ input: Input) -> Output
            }
            """,
            expandedSource: """
            protocol SendableTransformer: Sendable {
                associatedtype Input
                associatedtype Output

                func transform(_ input: Input) -> Output
            }

            @frozen
            @usableFromInline
            struct SendableTransformerWrapper<Input, Output>: SendableTransformer {
                @usableFromInline
                internal let _transform: @Sendable (Input) -> Output

                @inlinable
                init(_ closure: @escaping @Sendable (Input) -> Output) {
                    self._transform = closure
                }

                @inlinable
                func transform(_ input: Input) -> Output {
                    return _transform(input)
                }

                @inlinable
                func callAsFunction(_ input: Input) -> Output {
                    return _transform(input)
                }
            }

            extension SendableTransformer {
                @inlinable
                static func transform<Input, Output>(_ block: @escaping @Sendable (Input) -> Output) -> SendableTransformerWrapper<Input, Output> where Self == SendableTransformerWrapper<Input, Output> {
                    return SendableTransformerWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: Consuming Parameter

    func testConsumingParameterExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Consumer {
                associatedtype Element
                func consume(_ element: consuming Element)
            }
            """,
            expandedSource: """
            protocol Consumer {
                associatedtype Element
                func consume(_ element: consuming Element)
            }

            @frozen
            @usableFromInline
            struct ConsumerWrapper<Element>: Consumer {
                @usableFromInline
                internal let _consume: (consuming Element) -> Void

                @inlinable
                init(_ closure: @escaping (consuming Element) -> Void) {
                    self._consume = closure
                }

                @inlinable
                func consume(_ element: consuming Element) {
                    return _consume(element)
                }

                @inlinable
                func callAsFunction(_ element: consuming Element) {
                    return _consume(element)
                }
            }

            extension Consumer {
                @inlinable
                static func consume<Element>(_ block: @escaping (consuming Element) -> Void) -> ConsumerWrapper<Element> where Self == ConsumerWrapper<Element> {
                    return ConsumerWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Happy Path: callAsFunction Collision Protection

    func testCallAsFunctionCollisionProtection() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol Callable {
                func callAsFunction(_ value: Int) -> Int
            }
            """,
            expandedSource: """
            protocol Callable {
                func callAsFunction(_ value: Int) -> Int
            }

            @frozen
            @usableFromInline
            struct CallableWrapper: Callable {
                @usableFromInline
                internal let _callAsFunction: (Int) -> Int

                @inlinable
                init(_ closure: @escaping (Int) -> Int) {
                    self._callAsFunction = closure
                }

                @inlinable
                func callAsFunction(_ value: Int) -> Int {
                    return _callAsFunction(value)
                }
            }

            extension Callable {
                @inlinable
                static func callAsFunction(_ block: @escaping (Int) -> Int) -> CallableWrapper where Self == CallableWrapper {
                    return CallableWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error: Applied to a Struct (not a protocol)

    func testDiagnosticNotAProtocol() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            struct NotAProtocol {
                func doSomething() {}
            }
            """,
            expandedSource: """
            struct NotAProtocol {
                func doSomething() {}
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@FunctionalProtocol' can only be applied to a protocol declaration.",
                    line: 1,
                    column: 1
                ),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error: No Methods

    func testDiagnosticNoMethods() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol EmptyProtocol {
                associatedtype Element
            }
            """,
            expandedSource: """
            protocol EmptyProtocol {
                associatedtype Element
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@FunctionalProtocol' requires exactly one method in the protocol, but found none.",
                    line: 2,
                    column: 24
                ),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error: Too Many Methods

    func testDiagnosticTooManyMethods() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol TooManyMethods {
                func first()
                func second()
            }
            """,
            expandedSource: """
            protocol TooManyMethods {
                func first()
                func second()
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@FunctionalProtocol' requires exactly one method in the protocol, but found multiple.",
                    line: 2,
                    column: 25
                ),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Access Modifiers: fileprivate

    func testFileprivateProtocolExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            fileprivate protocol Validator {
                func validate(_ s: String) -> Bool
            }
            """,
            expandedSource: """
            fileprivate protocol Validator {
                func validate(_ s: String) -> Bool
            }

            fileprivate struct ValidatorWrapper: Validator {
                let _validate: (String) -> Bool

                fileprivate init(_ closure: @escaping (String) -> Bool) {
                    self._validate = closure
                }

                fileprivate func validate(_ s: String) -> Bool {
                    return _validate(s)
                }

                fileprivate func callAsFunction(_ s: String) -> Bool {
                    return _validate(s)
                }
            }

            extension Validator {
                fileprivate static func validate(_ block: @escaping (String) -> Bool) -> ValidatorWrapper where Self == ValidatorWrapper {
                    return ValidatorWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Access Modifiers: private

    func testPrivateProtocolExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            private protocol Reducer {
                func reduce(_ value: Int) -> Int
            }
            """,
            expandedSource: """
            private protocol Reducer {
                func reduce(_ value: Int) -> Int
            }

            private struct ReducerWrapper: Reducer {
                let _reduce: (Int) -> Int

                private init(_ closure: @escaping (Int) -> Int) {
                    self._reduce = closure
                }

                private func reduce(_ value: Int) -> Int {
                    return _reduce(value)
                }

                private func callAsFunction(_ value: Int) -> Int {
                    return _reduce(value)
                }
            }

            extension Reducer {
                private static func reduce(_ block: @escaping (Int) -> Int) -> ReducerWrapper where Self == ReducerWrapper {
                    return ReducerWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Sendable: Swift.Sendable (fully qualified)

    func testSwiftSendableProtocolExpansion() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol QueueTask: Swift.Sendable {
                func execute()
            }
            """,
            expandedSource: """
            protocol QueueTask: Swift.Sendable {
                func execute()
            }

            @frozen
            @usableFromInline
            struct QueueTaskWrapper: QueueTask {
                @usableFromInline
                internal let _execute: @Sendable () -> Void

                @inlinable
                init(_ closure: @escaping @Sendable () -> Void) {
                    self._execute = closure
                }

                @inlinable
                func execute() {
                    return _execute()
                }

                @inlinable
                func callAsFunction() {
                    return _execute()
                }
            }

            extension QueueTask {
                @inlinable
                static func execute(_ block: @escaping @Sendable () -> Void) -> QueueTaskWrapper where Self == QueueTaskWrapper {
                    return QueueTaskWrapper(block)
                }
            }
            """,
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    // MARK: - Error: Method-Level Generic Parameters

    func testDiagnosticGenericMethod() throws {
        #if canImport(FunctionalProtocolMacros)
        assertMacroExpansion(
            """
            @FunctionalProtocol
            protocol GenericMethod {
                func transform<T>(_ value: T) -> T
            }
            """,
            expandedSource: """
            protocol GenericMethod {
                func transform<T>(_ value: T) -> T
            }
            """,
            diagnostics: [
                DiagnosticSpec(
                    message: "'@FunctionalProtocol' does not support method-level generic parameters; use protocol-level 'associatedtype' instead.",
                    line: 3,
                    column: 5
                ),
            ],
            macros: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
