//
//  Expression.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public indirect enum ExpressionType {
  case functionCall(FunctionCall)
  case identifier(Identifier)
  case literal(Literal)
  case catchable(value: Expression, success: Expression)

  // TODO: these three should really be statements
  case variableDeclaration(VariableDeclaration)
  case assignment(Assignment)
  case noop

  case inline(String)
}

public struct Expression: RenderableToCodeFragment, CustomStringConvertible, Throwing {
  public let type: ExpressionType
  public var sourceLocation: SourceLocation?

  init (_ type: ExpressionType, from sourceLocation: SourceLocation? = nil) {
    self.type = type
    self.sourceLocation = sourceLocation
  }

  public var catchableSuccesses: [Expression] {
    switch self.type {
    case .variableDeclaration(let decl):
      return decl.catchableSuccesses
    case .assignment(let assign):
      return assign.catchableSuccesses
    case .functionCall(let f):
      return f.catchableSuccesses
    case .catchable(_, let success):
      return [success]
    default:
      return []
    }
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    switch self.type {
    case .functionCall(let e as RenderableToCodeFragment),
         .literal(let e as RenderableToCodeFragment),
         .variableDeclaration(let e as RenderableToCodeFragment),
         .assignment(let e as RenderableToCodeFragment),
         .catchable(let e as RenderableToCodeFragment, _):
      return e.rendered().fromSource(sourceLocation)
    case .identifier(let id):
      return CodeFragment(id).fromSource(sourceLocation)
    case .noop:
      return ""
    case .inline(let s):
      return CodeFragment(s).fromSource(sourceLocation)
    }
  }

  // Convenience functions for backwards compatibility

  public static func functionCall(_ fc: FunctionCall) -> Expression {
    return Expression(.functionCall(fc))
  }

  public static func identifier(_ id: Identifier) -> Expression {
    return Expression(.identifier(id))
  }

  public static func literal(_ lit: Literal) -> Expression {
    return Expression(.literal(lit))
  }

  public static func catchable(value: Expression, success: Expression) -> Expression {
    return Expression(.catchable(value: value, success: success))
  }

  public static func variableDeclaration(_ vd: VariableDeclaration) -> Expression {
    return Expression(.variableDeclaration(vd))
  }

  public static func assignment(_ a: Assignment) -> Expression {
    return Expression(.assignment(a))
  }

  public static var noop: Expression {
    return Expression(.noop)
  }

  public static func inline(_ s: String) -> Expression {
    return Expression(.inline(s))
  }
}
