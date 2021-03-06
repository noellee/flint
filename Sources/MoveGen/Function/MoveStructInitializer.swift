//
// Created by matthewross on 7/08/19.
//

import Foundation
import AST
import MoveIR
import Lexer

/// Generates code for a contract initializer.
struct MoveStructInitializer {
  var initializerDeclaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  /// The properties defined in the enclosing type. The default values of each property will be set in the initializer.
  var propertiesInEnclosingType: [AST.VariableDeclaration]

  var environment: Environment

  var `struct`: MoveStruct

  var moveType: MoveIR.`Type`? {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: true)

    return CanonicalType(
        from: AST.Type(identifier: typeIdentifier).rawType,
        environment: environment
    )?.render(functionContext: fc)
  }

  var parameterNames: [String] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: true)

    return initializerDeclaration.explicitParameters.map {
      MoveIdentifier(identifier: $0.identifier, position: .left).rendered(functionContext: fc).description
    }
  }

  var parameterIRTypes: [MoveIR.`Type`] {
    let fc = FunctionContext(environment: environment,
                             scopeContext: scopeContext,
                             enclosingTypeName: typeIdentifier.name,
                             isInStructFunction: true)

    return initializerDeclaration.explicitParameters.map {
      CanonicalType(from: $0.type.rawType,
                    environment: environment)!.render(functionContext: fc)
    }
  }

  /// The function's parameters and caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return ScopeContext(parameters: initializerDeclaration.signature.parameters, localVariables: [])
  }

  func rendered() -> String {
    let parameters = zip(parameterNames, parameterIRTypes).map { param in
      let (name, type): (String, MoveIR.`Type`) = param
      return "\(name): \(type)"
    }.joined(separator: ", ")

    let body = MoveStructInitializerBody(
        declaration: initializerDeclaration,
        typeIdentifier: typeIdentifier,
        environment: environment,
        properties: `struct`.structDeclaration.variableDeclarations
    ).rendered()

    let name = Mangler.mangleInitializerName(
        typeIdentifier.name,
        parameterTypes: initializerDeclaration.explicitParameters.map { $0.type.rawType }
    )

    let modifiers = initializerDeclaration.signature.modifiers
        .compactMap { (modifier: Token) -> String? in
          switch modifier.kind {
          case .public: return "public "
          default: return nil
          }
        }.reduce("", +)

    return """
           \(modifiers)\(name)(\(parameters)): \
           \(moveType?.description ?? "V#Self.\(`struct`.structDeclaration.identifier.name)") {
             \(body.indented(by: 2))
           }
           """
  }
}

struct MoveStructInitializerBody {
  var declaration: SpecialDeclaration
  var typeIdentifier: AST.Identifier

  var environment: Environment
  let properties: [AST.VariableDeclaration]

  /// The function's parameters and caller caller binding, as variable declarations in a `ScopeContext`.
  var scopeContext: ScopeContext {
    return declaration.scopeContext
  }

  init(declaration: SpecialDeclaration,
       typeIdentifier: AST.Identifier,
       environment: Environment,
       properties: [AST.VariableDeclaration]) {
    self.declaration = declaration
    self.typeIdentifier = typeIdentifier
    self.environment = environment
    self.properties = properties
  }

  func rendered() -> String {
    let functionContext: FunctionContext = FunctionContext(environment: environment,
                                                           scopeContext: scopeContext,
                                                           enclosingTypeName: typeIdentifier.name,
                                                           isInStructFunction: true,
                                                           isConstructor: true)
    return renderBody(declaration.body, functionContext: functionContext)
  }

  func renderMoveType(functionContext: FunctionContext) -> MoveIR.`Type` {
    return CanonicalType(
        from: AST.Type(identifier: typeIdentifier).rawType,
        environment: environment
    )!.render(functionContext: functionContext)
  }

  func renderBody<S: RandomAccessCollection & RangeReplaceableCollection>(_ statements: S,
                                                                          functionContext: FunctionContext) -> String
      where S.Element == AST.Statement, S.Index == Int {
    guard !statements.isEmpty else { return "" }
    var declarations = self.properties
    var statements = statements

    while !declarations.isEmpty {
      let property: AST.VariableDeclaration = declarations.removeFirst()
      let propertyType = CanonicalType(
          from: property.type.rawType,
          environment: environment
      )!.render(functionContext: functionContext)
      functionContext.emit(.expression(.variableDeclaration(
          MoveIR.VariableDeclaration((
                                         MoveSelf.prefix + property.identifier.name,
                                         propertyType
                                     ))
      )))
    }

    var unassigned: [AST.Identifier] = properties.map { $0.identifier }

    while !(statements.isEmpty || unassigned.isEmpty) {
      let statement: AST.Statement = statements.removeFirst()

      if case .expression(let expression) = statement,
         case .binaryExpression(let binary) = expression,
         case .punctuation(let op) = binary.op.kind,
         case .equal = op {
        switch binary.lhs {
        case .identifier(let identifier):
          if let type = identifier.enclosingType,
             type == typeIdentifier.name {
            unassigned = unassigned.filter { $0.name != identifier.name }
          }
        case .binaryExpression(let lhs):
          if case .punctuation(let op) = lhs.op.kind,
             case .dot = op,
             case .`self` = lhs.lhs,
             case .identifier(let field) = lhs.rhs {
            unassigned = unassigned.filter { $0.name != field.name }
          }
        default: break
        }
      }
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }

    let constructor = Expression.structConstructor(StructConstructor(
        typeIdentifier.name,
        properties.map {
          ($0.identifier.name, .transfer(.move(.identifier(MoveSelf.prefix + $0.identifier.name))))
        }
    ))

    guard !statements.isEmpty else {
      functionContext.emitReleaseReferences()
      functionContext.emit(.return(constructor))
      return functionContext.finalise()
    }

    functionContext.isConstructor = false

    let shadowSelfName = "flint$self_raw"
    let selfType = renderMoveType(functionContext: functionContext)
    functionContext.emit(
        .expression(.variableDeclaration(MoveIR.VariableDeclaration((MoveSelf.name, .mutableReference(to: selfType))))),
        at: 0
    )
    functionContext.emit(
        .expression(.variableDeclaration(MoveIR.VariableDeclaration((Mangler.mangleName(shadowSelfName), selfType)))),
        at: 0
    )
    let selfIdentifier = MoveSelf.generate(sourceLocation: declaration.sourceLocation).identifier
    let shadowSelfIdentifier = AST.Identifier(name: shadowSelfName, sourceLocation: declaration.sourceLocation)
    functionContext.scopeContext.localVariables.append(AST.VariableDeclaration(
        modifiers: [],
        declarationToken: nil,
        identifier: selfIdentifier,
        type: AST.Type(inferredType: .inoutType(.userDefinedType(functionContext.enclosingTypeName)),
                       identifier: selfIdentifier)
    ))
    functionContext.scopeContext.localVariables.append(AST.VariableDeclaration(
        modifiers: [],
        declarationToken: nil,
        identifier: shadowSelfIdentifier,
        type: AST.Type(inferredType: .userDefinedType(functionContext.enclosingTypeName),
                       identifier: shadowSelfIdentifier)
    ))
    functionContext.emit(.expression(.assignment(Assignment(Mangler.mangleName(shadowSelfName), constructor))))
    functionContext.emit(.expression(.assignment(Assignment(
        MoveSelf.name,
        MoveIdentifier(identifier: shadowSelfIdentifier).rendered(functionContext: functionContext)
    ))))

    while !statements.isEmpty {
      let statement: AST.Statement = statements.removeFirst()
      functionContext.emit(MoveStatement(statement: statement).rendered(functionContext: functionContext))
    }

    functionContext.emitReleaseReferences()
    let selfExpression = MoveSelf.generate(sourceLocation: declaration.closeBraceToken.sourceLocation)
        .rendered(functionContext: functionContext, forceMove: true)
    functionContext.emit(.inline("_ = \(selfExpression)"))
    let shadowSelfExpression: MoveIR.Expression = MoveIdentifier(identifier: shadowSelfIdentifier)
        .rendered(functionContext: functionContext, forceMove: true)
    functionContext.emit(.return(shadowSelfExpression))
    return functionContext.finalise()
  }
}
