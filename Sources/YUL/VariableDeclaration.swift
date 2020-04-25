//
//  VariableDeclaration.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public struct VariableDeclaration: RenderableToCodeFragment, CustomStringConvertible, Throwing {
  public let declarations: [TypedIdentifier]
  public let expression: Expression?

  public init(_ declarations: [TypedIdentifier], _ expression: Expression? = nil) {
    self.declarations = declarations
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression?.catchableSuccesses ?? []
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    let decls = render(typedIdentifiers: self.declarations)
    if self.expression == nil {
      return "let \(decls)"
    }
    return "let \(decls) := \(self.expression!)"
  }
}
