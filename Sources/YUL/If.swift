//
//  If.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

// swiftlint:disable type_name
public struct If: RenderableToCodeFragment, CustomStringConvertible, Throwing {
// swiftlint:enable type_name
  public let expression: Expression
  public let block: Block

  public init(_ expression: Expression, _ block: Block) {
    self.expression = expression
    self.block = block
  }

  public var catchableSuccesses: [Expression] {
    return expression.catchableSuccesses
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    return "if \(expression) \(self.block)"
  }
}
