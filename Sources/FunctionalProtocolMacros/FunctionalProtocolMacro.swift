import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  @FunctionalProtocol – SwiftSyntax Macro Implementation                    ║
// ║                                                                            ║
// ║  Attached to a protocol with exactly one method requirement, this macro    ║
// ║  generates:                                                                ║
// ║    • A @frozen bridge struct `Any<ProtocolName>` (PeerMacro)               ║
// ║    • A `static func create(...)` factory extension (ExtensionMacro)        ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

// MARK: - Extracted Protocol Metadata

/// All information extracted from the annotated protocol declaration
/// that is needed for code generation.
struct ProtocolInfo {
    let protocolName: String
    let structName: String        // "Any" + protocolName
    let associatedTypes: [String]
    let method: MethodInfo
    let isSendable: Bool
}

/// Information about the single required method.
struct MethodInfo {
    let name: String
    let parameters: [ParameterInfo]
    let returnType: String
    let hasExplicitReturn: Bool
    let isAsync: Bool
    let throwsClause: String?     // "throws" or "throws(SomeError)" or nil
}

/// Information about a single method parameter.
struct ParameterInfo {
    let firstName: String         // External label (or "_")
    let internalName: String      // Internal parameter name
    let type: String
}

// MARK: - Diagnostics

enum FunctionalProtocolDiagnostic: String, DiagnosticMessage {
    case notAProtocol
    case noMethods
    case tooManyMethods

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .notAProtocol:
            return "'@FunctionalProtocol' can only be applied to a protocol declaration."
        case .noMethods:
            return "'@FunctionalProtocol' requires exactly one method in the protocol, but found none."
        case .tooManyMethods:
            return "'@FunctionalProtocol' requires exactly one method in the protocol, but found multiple."
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "FunctionalProtocolMacro", id: rawValue)
    }
}

/// Sentinel error thrown after a diagnostic has already been emitted via `context.diagnose`.
private struct DiagnosticAlreadyReported: Error {}

// MARK: - Macro Type

public struct FunctionalProtocolMacro {}

// MARK: - PeerMacro (generates `@frozen struct Any<Protocol>`)

extension FunctionalProtocolMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let info = try extractProtocolInfo(from: declaration, attribute: node, in: context)
        return [generateBridgeStruct(from: info)]
    }
}

// MARK: - ExtensionMacro (generates `extension Protocol { static func create(...) }`)

extension FunctionalProtocolMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let info = try extractProtocolInfo(from: declaration, attribute: node, in: context)
        return [try generateExtension(from: info)]
    }
}

// MARK: - Protocol Parsing & Validation

extension FunctionalProtocolMacro {

    /// Parses a `ProtocolDeclSyntax` and extracts all metadata needed for code generation.
    /// Reports diagnostics and throws if the protocol is invalid.
    private static func extractProtocolInfo<D: SyntaxProtocol>(
        from declaration: D,
        attribute: AttributeSyntax,
        in context: some MacroExpansionContext
    ) throws -> ProtocolInfo {
        // ── 1. Must be a protocol ──────────────────────────────────────────
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(node: Syntax(attribute), message: FunctionalProtocolDiagnostic.notAProtocol)
            )
            throw DiagnosticAlreadyReported()
        }

        let protocolName = protocolDecl.name.trimmedDescription

        // ── 2. Collect associated types ────────────────────────────────────
        let associatedTypes = protocolDecl.memberBlock.members.compactMap { member -> String? in
            member.decl.as(AssociatedTypeDeclSyntax.self)?.name.trimmedDescription
        }

        // ── 3. Collect and validate methods ────────────────────────────────
        let methods = protocolDecl.memberBlock.members.compactMap { member -> FunctionDeclSyntax? in
            member.decl.as(FunctionDeclSyntax.self)
        }

        guard methods.count == 1 else {
            let diagnostic: FunctionalProtocolDiagnostic = methods.isEmpty ? .noMethods : .tooManyMethods
            context.diagnose(
                Diagnostic(node: Syntax(protocolDecl.memberBlock), message: diagnostic)
            )
            throw DiagnosticAlreadyReported()
        }

        let method = methods[0]

        // ── 4. Extract method details ──────────────────────────────────────
        let methodName = method.name.trimmedDescription

        let parameters: [ParameterInfo] = method.signature.parameterClause.parameters
            .enumerated()
            .map { index, param in
                let firstName = param.firstName.trimmedDescription
                let internalName: String
                if let secondName = param.secondName {
                    internalName = secondName.trimmedDescription
                } else if param.firstName.tokenKind == .wildcard {
                    // Unnamed parameter (e.g. `func foo(_: Int)`) – synthesize a name
                    internalName = "arg\(index)"
                } else {
                    internalName = firstName
                }
                return ParameterInfo(
                    firstName: firstName,
                    internalName: internalName,
                    type: param.type.trimmedDescription
                )
            }

        let returnType = method.signature.returnClause?.type.trimmedDescription ?? "Void"
        let hasExplicitReturn = method.signature.returnClause != nil

        let isAsync = method.signature.effectSpecifiers?.asyncSpecifier != nil

        let throwsClause: String?
        if let tc = method.signature.effectSpecifiers?.throwsClause {
            throwsClause = tc.trimmedDescription
        } else {
            throwsClause = nil
        }

        // ── 5. Check Sendable conformance ──────────────────────────────────
        let isSendable = protocolDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Sendable"
        } ?? false

        return ProtocolInfo(
            protocolName: protocolName,
            structName: "Any\(protocolName)",
            associatedTypes: associatedTypes,
            method: MethodInfo(
                name: methodName,
                parameters: parameters,
                returnType: returnType,
                hasExplicitReturn: hasExplicitReturn,
                isAsync: isAsync,
                throwsClause: throwsClause
            ),
            isSendable: isSendable
        )
    }
}

// MARK: - Code Generation

extension FunctionalProtocolMacro {

    // ── String Building Helpers ────────────────────────────────────────────

    /// Generic parameter clause: `<Input, Output>` or empty string.
    private static func genericClause(for associatedTypes: [String]) -> String {
        associatedTypes.isEmpty ? "" : "<\(associatedTypes.joined(separator: ", "))>"
    }

    /// Effect specifiers for function signatures and closure types: ` async throws` etc.
    private static func effectsString(for method: MethodInfo) -> String {
        var parts: [String] = []
        if method.isAsync { parts.append("async") }
        if let tc = method.throwsClause { parts.append(tc) }
        return parts.isEmpty ? "" : " " + parts.joined(separator: " ")
    }

    /// Call-site prefix: `try await `, `try `, `await `, or empty.
    private static func callPrefix(for method: MethodInfo) -> String {
        var prefix = ""
        if method.throwsClause != nil { prefix += "try " }
        if method.isAsync { prefix += "await " }
        return prefix
    }

    /// Closure type string, e.g. `@Sendable (Input) async throws -> Output`.
    private static func closureTypeString(for info: ProtocolInfo) -> String {
        let paramTypes = info.method.parameters.map(\.type).joined(separator: ", ")
        let effects = effectsString(for: info.method)
        let base = "(\(paramTypes))\(effects) -> \(info.method.returnType)"
        return info.isSendable ? "@Sendable \(base)" : base
    }

    /// Function parameter clause: `(_ input: Input, _ other: String)`.
    private static func parameterClause(for parameters: [ParameterInfo]) -> String {
        let parts = parameters.map { param in
            if param.firstName == param.internalName {
                return "\(param.firstName): \(param.type)"
            } else {
                return "\(param.firstName) \(param.internalName): \(param.type)"
            }
        }
        return "(\(parts.joined(separator: ", ")))"
    }

    /// Argument list for calling the closure: `input, other`.
    private static func callArguments(for parameters: [ParameterInfo]) -> String {
        parameters.map(\.internalName).joined(separator: ", ")
    }

    /// Return clause: ` -> Output` or empty for Void.
    private static func returnClause(for method: MethodInfo) -> String {
        method.hasExplicitReturn ? " -> \(method.returnType)" : ""
    }

    // ── Peer: @frozen struct Any<Protocol> ─────────────────────────────────

    private static func generateBridgeStruct(from info: ProtocolInfo) -> DeclSyntax {
        let generics    = genericClause(for: info.associatedTypes)
        let closureT    = closureTypeString(for: info)
        let params      = parameterClause(for: info.method.parameters)
        let effects     = effectsString(for: info.method)
        let retClause   = returnClause(for: info.method)
        let callPfx     = callPrefix(for: info.method)
        let args        = callArguments(for: info.method.parameters)

        return """
        @frozen
        public struct \(raw: info.structName)\(raw: generics): \(raw: info.protocolName) {
            @usableFromInline
            internal let _closure: \(raw: closureT)

            @inlinable
            public init(_ closure: @escaping \(raw: closureT)) {
                self._closure = closure
            }

            @inlinable
            public func \(raw: info.method.name)\(raw: params)\(raw: effects)\(raw: retClause) {
                return \(raw: callPfx)_closure(\(raw: args))
            }

            @inlinable
            public func callAsFunction\(raw: params)\(raw: effects)\(raw: retClause) {
                return \(raw: callPfx)_closure(\(raw: args))
            }
        }
        """
    }

    // ── Extension: static func create(...) ─────────────────────────────────

    private static func generateExtension(from info: ProtocolInfo) throws -> ExtensionDeclSyntax {
        let generics  = genericClause(for: info.associatedTypes)
        let closureT  = closureTypeString(for: info)
        let structT   = "\(info.structName)\(generics)"
        let whereClause = "where Self == \(structT)"

        let extensionSource: DeclSyntax = """
        extension \(raw: info.protocolName) {
            @inlinable
            public static func create\(raw: generics)(_ closure: @escaping \(raw: closureT)) -> \(raw: structT) \(raw: whereClause) {
                return \(raw: info.structName)(closure)
            }
        }
        """

        guard let extensionDecl = extensionSource.as(ExtensionDeclSyntax.self) else {
            throw DiagnosticAlreadyReported()
        }

        return extensionDecl
    }
}
