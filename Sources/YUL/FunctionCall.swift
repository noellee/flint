//
//  FunctionCall.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public struct FunctionCall: RenderableToCodeFragment, CustomStringConvertible, Throwing {
  public let name: Identifier
  public let arguments: [Expression]

  public init(_ name: Identifier, _ arguments: [Expression]) {
    self.name = name
    self.arguments = arguments
  }

  public init(_ name: Identifier, _ arguments: Expression...) {
    self.init(name, arguments)
  }

  public var catchableSuccesses: [Expression] {
    return arguments.flatMap { argument in argument.catchableSuccesses }
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    let args = arguments.joined(separator: ", ")
    return "\(name)(\(args))"
  }
}
