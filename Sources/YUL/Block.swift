//
//  Block.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Utils
import Source

public struct Block: RenderableToCodeFragment, CustomStringConvertible {
  public var statements: [Statement]

  public init(_ statements: Statement...) {
    self.statements = statements
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    let statement_description = statements.map { $0 }.joined(separator: "\n")

    return """
    {
      \(statement_description.indented(by: 2))
    }
    """
  }
}
