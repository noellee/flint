//
//  FunctionDefinition.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public struct FunctionDefinition: RenderableToCodeFragment, CustomStringConvertible {
  public let identifier: Identifier
  public let arguments: [TypedIdentifier]
  public let returns: [TypedIdentifier]
  public let body: Block

  public init(identifier: Identifier,
              arguments: [TypedIdentifier],
              returns: [TypedIdentifier] = [],
              body: Block) {
    self.identifier = identifier
    self.arguments = arguments
    self.returns = returns
    self.body = body
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    let args = render(typedIdentifiers: self.arguments)

    var ret = ""
    if !self.returns.isEmpty {
      let retargs = render(typedIdentifiers: self.returns)
      ret = "-> \(retargs)"
    }

    return "\(self.identifier)(\(args)) \(ret) \(self.body)"
  }
}
