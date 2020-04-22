import Foundation
import Utils

public protocol RenderableToCodeFragment {
  func rendered() -> CodeFragment
}

public struct SourceRange: Comparable, Hashable, CustomStringConvertible {
  public let start: Int
  public let length: Int

  public init(start: Int, length: Int) {
    self.start = start
    self.length = length
  }

  public var description: String { return "\(start):\(length)" }

  public func contains(_ other: SourceRange) -> Bool {
    return other.start >= self.start && other.start + other.length <= self.start + self.length
  }

  public static func < (lhs: SourceRange, rhs: SourceRange) -> Bool {
    return [lhs.start, lhs.length].lexicographicallyPrecedes([rhs.start, rhs.length])
  }
}

extension Dictionary {
  mutating func merge(_ dict: [Key: Value]) {
    for (k, v) in dict {
      updateValue(v, forKey: k)
    }
  }
}

public extension Sequence where Self.Element == CodeFragment {
  func joined(separator: String = "") -> CodeFragment {
    var iterator = self.makeIterator()
    let first = iterator.next()
    if first == nil {
      return CodeFragment()
    }

    return self.dropFirst().reduce(first!, { curr, next in curr + separator + next })
  }
}

public extension Sequence where Self.Element: RenderableToCodeFragment {
  func joined(separator: String = "") -> CodeFragment {
    return self.map { $0.rendered() }.joined(separator: separator)
  }
}

public struct CodeFragment: CustomStringConvertible {
  public var fromSource: SourceLocation?
  private var children: [CodeFragment] = []

  private var text: String = ""

  public var description: String {
    return children.isEmpty ? text : children.map { $0.description }.joined()
  }

  init() {
    self.init("")
  }

  public init(_ value: String, fromSource: SourceLocation?) {
    self.text = value
    self.fromSource = fromSource
  }

  public init(_ value: String) {
    self.init(stringLiteral: value)
  }

  public func generateSourceMap() -> [SourceRange: SourceLocation] {
    return generateSourceMap(offset: 0).srcMap
  }

  private func generateSourceMap(offset: Int) -> (srcMap: [SourceRange: SourceLocation], codeLength: Int) {
    var srcMap = [SourceRange: SourceLocation]()
    var pos = offset
    for child in children {
      let (childSrcMap, childLength) = child.generateSourceMap(offset: pos)
      srcMap.merge(childSrcMap)
      pos += childLength
    }

    let length = children.isEmpty ? text.count : pos - offset
    if fromSource != nil {
      srcMap[SourceRange(start: offset, length: length)] = fromSource
    }
    return (srcMap, length)
  }
}

extension CodeFragment: ExpressibleByStringLiteral {
  public init(stringLiteral value: String) {
    self.text = value
  }
}

extension CodeFragment: ExpressibleByStringInterpolation {
  public init(stringInterpolation: StringInterpolation) {
    self.text = stringInterpolation.output.text
    self.children = stringInterpolation.output.children
  }

  public struct StringInterpolation: StringInterpolationProtocol {
    var output: CodeFragment = ""

    public init(literalCapacity: Int, interpolationCount: Int) {
      output.text.reserveCapacity(literalCapacity * 2)
    }

    public mutating func appendLiteral(_ literal: String) {
      if !literal.isEmpty {
        output += literal
      }
    }

    public mutating func appendInterpolation(_ fragment: CodeFragment) {
      output += fragment
    }

    public mutating func appendInterpolation(_ renderable: RenderableToCodeFragment) {
      output += renderable.rendered()
    }

    public mutating func appendInterpolation(_ string: String) {
      if !string.isEmpty {
        appendInterpolation(CodeFragment(string))
      }
    }
  }
}

extension CodeFragment {
  public func write(to url: URL, atomically useAuxiliaryFile: Bool, encoding enc: String.Encoding) throws {
    try self.text.write(to: url, atomically: useAuxiliaryFile, encoding: enc)
  }

  public func indented(by level: Int, andFirst: Bool = false) -> CodeFragment {
    var copy = self
    if copy.children.isEmpty {
      copy.text = copy.text.indented(by: level, andFirst: andFirst)
    } else {

    }
    return copy
  }

  public func fromSource(_ fromSource: SourceLocation?) -> CodeFragment {
    var copy = self
    copy.fromSource = fromSource
    return copy
  }

  public static func + (left: CodeFragment, right: String) -> CodeFragment {
    return left + CodeFragment(stringLiteral: right)
  }

  public static func + (left: String, right: CodeFragment) -> CodeFragment {
    return CodeFragment(stringLiteral: left) + right
  }

  public static func + (left: CodeFragment, right: CodeFragment) -> CodeFragment {
    var copy: CodeFragment
    if left.children.isEmpty || left.fromSource != nil {
      copy = CodeFragment(left.text)
      copy.children.append(left)
    } else {
      copy = left
    }

    copy.children.append(right)
    copy.text.append(right.text)

    return copy
  }

  public static func += (left: inout CodeFragment, right: CodeFragment) {
    // swiftlint:disable:next shorthand_operator
    left = left + right
  }

  public static func += (left: inout CodeFragment, right: String) {
    // swiftlint:disable:next shorthand_operator
    left = left + right
  }
}
