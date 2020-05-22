import Foundation
import AST

protocol ExpressionContainer {
  func extractExpressions() -> [Expression]
}

extension Sequence where Self.Element: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return self.flatMap {
      $0.extractExpressions()
    }
  }
}

extension TopLevelModule: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return extractStatements().extractExpressions()
  }
}

extension TopLevelModule {
  func extractFunctionDeclarations() -> [FunctionDeclaration] {
    return self.declarations
        .compactMap { declaration -> ContractBehaviorDeclaration? in
          switch declaration {
          case .contractBehaviorDeclaration(let decl): return decl
          default: return nil
          }
        }
        .flatMap { decl in
          decl.members
        }
        .compactMap { member -> FunctionDeclaration? in
          switch member {
          case .functionDeclaration(let decl): return decl
          default: return nil
          }
        }
  }

  func extractStatements() -> [Statement] {
    return self.extractFunctionDeclarations()
        .flatMap { decl in
          decl.body
        }
  }
}

extension Statement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    switch self {
    case .expression(let container as ExpressionContainer),
         .returnStatement(let container as ExpressionContainer),
         .becomeStatement(let container as ExpressionContainer),
         .ifStatement(let container as ExpressionContainer),
         .forStatement(let container as ExpressionContainer),
         .emitStatement(let container as ExpressionContainer),
         .doCatchStatement(let container as ExpressionContainer):
      return container.extractExpressions()
    }
  }
}

extension Expression: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return [self]
  }
}

extension ReturnStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return (self.expression?.extractExpressions() ?? []) + (self.cleanupStatements?.extractExpressions() ?? [])
  }
}

extension BecomeStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return self.expression.extractExpressions()
  }
}

extension IfStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return (self.body + self.elseBody).flatMap { stmt in
      stmt.extractExpressions()
    }
  }
}

extension ForStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return self.iterable.extractExpressions() + self.body.extractExpressions()
  }
}

extension EmitStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return []
  }
}

extension DoCatchStatement: ExpressionContainer {
  func extractExpressions() -> [Expression] {
    return (self.doBody + self.catchBody).extractExpressions()
  }
}
