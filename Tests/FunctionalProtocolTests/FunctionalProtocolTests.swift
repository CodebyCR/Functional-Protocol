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
            public struct TransformerFunctor<Input, Output>: Transformer {
                @usableFromInline
                internal let _closure: (Input) -> Output

                @inlinable
                public init(_ closure: @escaping (Input) -> Output) {
                    self._closure = closure
                }

                @inlinable
                public func transform(_ input: Input) -> Output {
                    return _closure(input)
                }

                @inlinable
                public func callAsFunction(_ input: Input) -> Output {
                    return _closure(input)
                }
            }

            extension Transformer {
                @inlinable
                public static func closure<Input, Output>(_ closure: @escaping (Input) -> Output) -> TransformerFunctor<Input, Output> where Self == TransformerFunctor<Input, Output> {
                    return TransformerFunctor(closure)
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
            public struct PredicateFunctor<Element>: Predicate {
                @usableFromInline
                internal let _closure: (Element) -> Bool

                @inlinable
                public init(_ closure: @escaping (Element) -> Bool) {
                    self._closure = closure
                }

                @inlinable
                public func evaluate(_ element: Element) -> Bool {
                    return _closure(element)
                }

                @inlinable
                public func callAsFunction(_ element: Element) -> Bool {
                    return _closure(element)
                }
            }

            extension Predicate {
                @inlinable
                public static func closure<Element>(_ closure: @escaping (Element) -> Bool) -> PredicateFunctor<Element> where Self == PredicateFunctor<Element> {
                    return PredicateFunctor(closure)
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
            public struct LoggerFunctor: Logger {
                @usableFromInline
                internal let _closure: (String) -> Void

                @inlinable
                public init(_ closure: @escaping (String) -> Void) {
                    self._closure = closure
                }

                @inlinable
                public func log(_ message: String) {
                    return _closure(message)
                }

                @inlinable
                public func callAsFunction(_ message: String) {
                    return _closure(message)
                }
            }

            extension Logger {
                @inlinable
                public static func closure(_ closure: @escaping (String) -> Void) -> LoggerFunctor where Self == LoggerFunctor {
                    return LoggerFunctor(closure)
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
            public struct ParserFunctor<Input, Output>: Parser {
                @usableFromInline
                internal let _closure: (Input) throws -> Output

                @inlinable
                public init(_ closure: @escaping (Input) throws -> Output) {
                    self._closure = closure
                }

                @inlinable
                public func parse(_ input: Input) throws -> Output {
                    return try _closure(input)
                }

                @inlinable
                public func callAsFunction(_ input: Input) throws -> Output {
                    return try _closure(input)
                }
            }

            extension Parser {
                @inlinable
                public static func closure<Input, Output>(_ closure: @escaping (Input) throws -> Output) -> ParserFunctor<Input, Output> where Self == ParserFunctor<Input, Output> {
                    return ParserFunctor(closure)
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
            public struct AsyncFetcherFunctor<Input, Output>: AsyncFetcher {
                @usableFromInline
                internal let _closure: (Input) async throws -> Output

                @inlinable
                public init(_ closure: @escaping (Input) async throws -> Output) {
                    self._closure = closure
                }

                @inlinable
                public func fetch(_ input: Input) async throws -> Output {
                    return try await _closure(input)
                }

                @inlinable
                public func callAsFunction(_ input: Input) async throws -> Output {
                    return try await _closure(input)
                }
            }

            extension AsyncFetcher {
                @inlinable
                public static func closure<Input, Output>(_ closure: @escaping (Input) async throws -> Output) -> AsyncFetcherFunctor<Input, Output> where Self == AsyncFetcherFunctor<Input, Output> {
                    return AsyncFetcherFunctor(closure)
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
            public struct SendableTransformerFunctor<Input, Output>: SendableTransformer {
                @usableFromInline
                internal let _closure: @Sendable (Input) -> Output

                @inlinable
                public init(_ closure: @escaping @Sendable (Input) -> Output) {
                    self._closure = closure
                }

                @inlinable
                public func transform(_ input: Input) -> Output {
                    return _closure(input)
                }

                @inlinable
                public func callAsFunction(_ input: Input) -> Output {
                    return _closure(input)
                }
            }

            extension SendableTransformer {
                @inlinable
                public static func closure<Input, Output>(_ closure: @escaping @Sendable (Input) -> Output) -> SendableTransformerFunctor<Input, Output> where Self == SendableTransformerFunctor<Input, Output> {
                    return SendableTransformerFunctor(closure)
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
            public struct ConsumerFunctor<Element>: Consumer {
                @usableFromInline
                internal let _closure: (consuming Element) -> Void

                @inlinable
                public init(_ closure: @escaping (consuming Element) -> Void) {
                    self._closure = closure
                }

                @inlinable
                public func consume(_ element: consuming Element) {
                    return _closure(element)
                }

                @inlinable
                public func callAsFunction(_ element: consuming Element) {
                    return _closure(element)
                }
            }

            extension Consumer {
                @inlinable
                public static func closure<Element>(_ closure: @escaping (consuming Element) -> Void) -> ConsumerFunctor<Element> where Self == ConsumerFunctor<Element> {
                    return ConsumerFunctor(closure)
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
}
