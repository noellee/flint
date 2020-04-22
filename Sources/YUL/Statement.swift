//
//  Statement.swift
//  YUL
//
//  Created by Aurel Bílý on 12/26/18.
//

import Source

public enum StatementType {
  case block(Block)
  case functionDefinition(FunctionDefinition)
  case `if`(If)
  case expression(Expression)
  case `switch`(Switch)
  case `for`(ForLoop)
  case `break`
  case `continue`
  case noop
  case inline(String)
}

public struct Statement: RenderableToCodeFragment, CustomStringConvertible, Throwing {
  public let type: StatementType
  public var sourceLocation: SourceLocation?

  public init(_ type: StatementType, from sourceLocation: SourceLocation? = nil) {
    self.type = type
    self.sourceLocation = sourceLocation
  }

  public var catchableSuccesses: [Expression] {
    switch self.type {
    case .if(let ifs):
      return ifs.catchableSuccesses
    case .expression(let e):
      return e.catchableSuccesses
    case .switch(let sw):
      return sw.catchableSuccesses
    default:
      return []
    }
  }

  public var description: String {
    return rendered().description
  }

  public func rendered() -> CodeFragment {
    switch self.type {
    case .block(let s as RenderableToCodeFragment),
         .functionDefinition(let s as RenderableToCodeFragment),
         .if(let s as RenderableToCodeFragment),
         .expression(let s as RenderableToCodeFragment),
         .switch(let s as RenderableToCodeFragment),
         .`for`(let s as RenderableToCodeFragment):
      return s.rendered().fromSource(sourceLocation)
    case .break:
      return CodeFragment("break", fromSource: sourceLocation)
    case .continue:
      return CodeFragment("continue", fromSource: sourceLocation)
    case .noop:
      return ""
    case .inline(let s):
      return CodeFragment(s, fromSource: sourceLocation)
    }
  }

  // Convenience functions for backwards compatibility

  public static func block(_ block: Block) -> Statement {
    return Statement(.block(block))
  }

  public static func functionDefinition(_ functionDefinition: FunctionDefinition) -> Statement {
    return Statement(.functionDefinition(functionDefinition))
  }

  public static func `if`(_ ifs: If) -> Statement {
    return Statement(.if(ifs))
  }

  public static func expression(_ expr: Expression) -> Statement {
    return Statement(.expression(expr))
  }

  public static func `switch`(_ sw: Switch) -> Statement {
    return Statement(.switch(sw))
  }

  public static func `for`(_ forLoop: ForLoop) -> Statement {
    return Statement(.for(forLoop))
  }

  public static var `break`: Statement {
    return Statement(.break)
  }
  public static var `continue`: Statement {
    return Statement(.continue)
  }

  public static var noop: Statement {
    return Statement(.noop)
  }

  public static func inline(_ string: String) -> Statement {
    return Statement(.inline(string))
  }
}
