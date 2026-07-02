import SwiftSyntax
import SwiftSyntaxMacros
import SwiftDiagnostics

// ╔══════════════════════════════════════════════════════════════════════════════╗
// ║  @FunctionalProtocol – SwiftSyntax Macro Implementation                    ║
// ║                                                                            ║
// ║  Attached to a protocol with exactly one method requirement, this macro    ║
// ║  generates:                                                                ║
// ║    • A @frozen bridge struct `<ProtocolName>Functor` (PeerMacro)           ║
// ║    • A static factory extension matching the method name (ExtensionMacro)  ║
// ╚══════════════════════════════════════════════════════════════════════════════╝

// MARK: - Extracted Protocol Metadata

/// All information extracted from the annotated protocol declaration
/// that is needed for code generation.
struct ProtocolInfo {
    let protocolName: String
    let structName: String        // protocolName + "Functor"
    let accessModifier: String    // "public", "package", "internal", or "" (default internal)
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
    case genericMethod

    var severity: DiagnosticSeverity { .error }

    var message: String {
        switch self {
        case .notAProtocol:
            return "'@FunctionalProtocol' can only be applied to a protocol declaration."
        case .noMethods:
            return "'@FunctionalProtocol' requires exactly one method in the protocol, but found none."
        case .tooManyMethods:
            return "'@FunctionalProtocol' requires exactly one method in the protocol, but found multiple."
        case .genericMethod:
            return "'@FunctionalProtocol' does not support method-level generic parameters; use protocol-level 'associatedtype' instead."
        }
    }

    var diagnosticID: MessageID {
        MessageID(domain: "FunctionalProtocolMacro", id: rawValue)
    }
}

// MARK: - Macro Type

public struct FunctionalProtocolMacro {}

// MARK: - PeerMacro (generates `@frozen struct <Protocol>Functor`)

extension FunctionalProtocolMacro: PeerMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingPeersOf declaration: some DeclSyntaxProtocol,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let info = extractProtocolInfo(from: declaration, attribute: node, in: context, emitDiagnostics: true) else {
            return []
        }
        return [generateBridgeStruct(from: info)]
    }
}

// MARK: - ExtensionMacro (generates `extension Protocol { static func <method>(...) }`)

extension FunctionalProtocolMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard let info = extractProtocolInfo(from: declaration, attribute: node, in: context, emitDiagnostics: false),
              let ext = generateExtension(from: info) else {
            return []
        }
        return [ext]
    }
}

// MARK: - Protocol Parsing & Validation

extension FunctionalProtocolMacro {

    /// Parses a `ProtocolDeclSyntax` and extracts all metadata needed for code generation.
    /// When `emitDiagnostics` is true (PeerMacro only), reports compiler errors for invalid protocols.
    private static func extractProtocolInfo<D: SyntaxProtocol>(
        from declaration: D,
        attribute: AttributeSyntax,
        in context: some MacroExpansionContext,
        emitDiagnostics: Bool
    ) -> ProtocolInfo? {
        // ── 1. Must be a protocol ──────────────────────────────────────────
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            if emitDiagnostics {
                context.diagnose(
                    Diagnostic(node: Syntax(attribute), message: FunctionalProtocolDiagnostic.notAProtocol)
                )
            }
            return nil
        }

        let protocolName = protocolDecl.name.trimmedDescription

        // ── 2. Inherit access modifier ────────────────────────────────────
        // The generated struct must have the same visibility as the protocol
        // so that users can write extensions on the functor type.
        let accessModifier: String = protocolDecl.modifiers.first { modifier in
            ["public", "package", "internal", "fileprivate", "private"]
                .contains(modifier.name.trimmedDescription)
        }?.name.trimmedDescription ?? ""

        // ── 3. Collect associated types ────────────────────────────────────
        let associatedTypes = protocolDecl.memberBlock.members.compactMap { member -> String? in
            member.decl.as(AssociatedTypeDeclSyntax.self)?.name.trimmedDescription
        }

        // ── 4. Collect and validate methods ────────────────────────────────
        // Protocol extensions are separate ExtensionDeclSyntax nodes and are
        // not included in memberBlock, so only primary declarations are counted.
        let methods = protocolDecl.memberBlock.members.compactMap { member -> FunctionDeclSyntax? in
            member.decl.as(FunctionDeclSyntax.self)
        }

        guard methods.count == 1 else {
            if emitDiagnostics {
                let diagnostic: FunctionalProtocolDiagnostic = methods.isEmpty ? .noMethods : .tooManyMethods
                context.diagnose(
                    Diagnostic(node: Syntax(protocolDecl.memberBlock), message: diagnostic)
                )
            }
            return nil
        }

        let method = methods[0]

        // ── 5. Reject method-level generics ────────────────────────────────
        // Swift cannot store a generic closure as a stored property
        // (e.g., `let f: <T>(T) -> T` is illegal). Use associatedtype instead.
        if method.genericParameterClause != nil {
            if emitDiagnostics {
                context.diagnose(
                    Diagnostic(node: Syntax(method), message: FunctionalProtocolDiagnostic.genericMethod)
                )
            }
            return nil
        }

        // ── 6. Extract method details ──────────────────────────────────────
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

        // ── 7. Check Sendable conformance ──────────────────────────────────
        let isSendable = protocolDecl.inheritanceClause?.inheritedTypes.contains {
            $0.type.trimmedDescription == "Sendable"
        } ?? false

        return ProtocolInfo(
            protocolName: protocolName,
            structName: "\(protocolName)Functor",
            accessModifier: accessModifier,
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

    /// Access modifier with trailing space, or empty string for default internal.
    private static func acc(for info: ProtocolInfo) -> String {
        info.accessModifier.isEmpty ? "" : "\(info.accessModifier) "
    }

    // ── Peer: @frozen struct <Protocol>Functor ──────────────────────────────

    private static func generateBridgeStruct(from info: ProtocolInfo) -> DeclSyntax {
        let generics  = genericClause(for: info.associatedTypes)
        let closureT  = closureTypeString(for: info)
        let params    = parameterClause(for: info.method.parameters)
        let effects   = effectsString(for: info.method)
        let retClause = returnClause(for: info.method)
        let callPfx   = callPrefix(for: info.method)
        let args      = callArguments(for: info.method.parameters)
        let access    = acc(for: info)
        let propName  = "_\(info.method.name)"
        // @frozen on an internal type requires @usableFromInline.
        let usableAnnotation = info.accessModifier.isEmpty ? "\n@usableFromInline" : ""

        // When the SAM is itself `callAsFunction`, suppress the synthesized
        // wrapper to avoid a duplicate method declaration in the struct.
        if info.method.name == "callAsFunction" {
            return """
            @frozen\(raw: usableAnnotation)
            \(raw: access)struct \(raw: info.structName)\(raw: generics): \(raw: info.protocolName) {
                @usableFromInline
                internal let \(raw: propName): \(raw: closureT)

                @inlinable
                \(raw: access)init(_ closure: @escaping \(raw: closureT)) {
                    self.\(raw: propName) = closure
                }

                @inlinable
                \(raw: access)func \(raw: info.method.name)\(raw: params)\(raw: effects)\(raw: retClause) {
                    return \(raw: callPfx)\(raw: propName)(\(raw: args))
                }
            }
            """
        } else {
            return """
            @frozen\(raw: usableAnnotation)
            \(raw: access)struct \(raw: info.structName)\(raw: generics): \(raw: info.protocolName) {
                @usableFromInline
                internal let \(raw: propName): \(raw: closureT)

                @inlinable
                \(raw: access)init(_ closure: @escaping \(raw: closureT)) {
                    self.\(raw: propName) = closure
                }

                @inlinable
                \(raw: access)func \(raw: info.method.name)\(raw: params)\(raw: effects)\(raw: retClause) {
                    return \(raw: callPfx)\(raw: propName)(\(raw: args))
                }

                @inlinable
                \(raw: access)func callAsFunction\(raw: params)\(raw: effects)\(raw: retClause) {
                    return \(raw: callPfx)\(raw: propName)(\(raw: args))
                }
            }
            """
        }
    }

    // ── Extension: static func <methodName>(...) ────────────────────────────

    private static func generateExtension(from info: ProtocolInfo) -> ExtensionDeclSyntax? {
        let generics    = genericClause(for: info.associatedTypes)
        let closureT    = closureTypeString(for: info)
        let structT     = "\(info.structName)\(generics)"
        let whereClause = "where Self == \(structT)"
        let access      = acc(for: info)

        let extensionSource: DeclSyntax = """
        extension \(raw: info.protocolName) {
            @inlinable
            \(raw: access)static func \(raw: info.method.name)\(raw: generics)(_ block: @escaping \(raw: closureT)) -> \(raw: structT) \(raw: whereClause) {
                return \(raw: info.structName)(block)
            }
        }
        """

        return extensionSource.as(ExtensionDeclSyntax.self)
    }
}
