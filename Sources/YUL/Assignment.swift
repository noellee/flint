//
//  Assignment.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public struct Assignment: RenderableToCodeFragment, CustomStringConvertible, Throwing {
  public let identifiers: [Identifier]
  public let expression: Expression

  public init(_ identifiers: [Identifier], _ expression: Expression) {
    self.identifiers = identifiers
    self.expression = expression
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    let lhs = self.identifiers.joined(separator: ", ")
    return "\(lhs) := \(self.expression)"
  }
}
