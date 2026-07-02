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
            struct TransformerFunctor<Input, Output>: Transformer {
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
                static func transform<Input, Output>(_ block: @escaping (Input) -> Output) -> TransformerFunctor<Input, Output> where Self == TransformerFunctor<Input, Output> {
                    return TransformerFunctor(block)
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
            struct PredicateFunctor<Element>: Predicate {
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
                static func evaluate<Element>(_ block: @escaping (Element) -> Bool) -> PredicateFunctor<Element> where Self == PredicateFunctor<Element> {
                    return PredicateFunctor(block)
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
            struct LoggerFunctor: Logger {
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
                static func log(_ block: @escaping (String) -> Void) -> LoggerFunctor where Self == LoggerFunctor {
                    return LoggerFunctor(block)
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
            struct ParserFunctor<Input, Output>: Parser {
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
                static func parse<Input, Output>(_ block: @escaping (Input) throws -> Output) -> ParserFunctor<Input, Output> where Self == ParserFunctor<Input, Output> {
                    return ParserFunctor(block)
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
            struct AsyncFetcherFunctor<Input, Output>: AsyncFetcher {
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
                static func fetch<Input, Output>(_ block: @escaping (Input) async throws -> Output) -> AsyncFetcherFunctor<Input, Output> where Self == AsyncFetcherFunctor<Input, Output> {
                    return AsyncFetcherFunctor(block)
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
            struct SendableTransformerFunctor<Input, Output>: SendableTransformer {
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
                static func transform<Input, Output>(_ block: @escaping @Sendable (Input) -> Output) -> SendableTransformerFunctor<Input, Output> where Self == SendableTransformerFunctor<Input, Output> {
                    return SendableTransformerFunctor(block)
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
            struct ConsumerFunctor<Element>: Consumer {
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
                static func consume<Element>(_ block: @escaping (consuming Element) -> Void) -> ConsumerFunctor<Element> where Self == ConsumerFunctor<Element> {
                    return ConsumerFunctor(block)
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
            struct CallableFunctor: Callable {
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
                static func callAsFunction(_ block: @escaping (Int) -> Int) -> CallableFunctor where Self == CallableFunctor {
                    return CallableFunctor(block)
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
