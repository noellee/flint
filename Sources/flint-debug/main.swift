import Foundation
import Commander
import Debugger
import Web3
import Web3PromiseKit
import PromiseKit

struct SourceRange: Comparable, Hashable, CustomStringConvertible {
  let start: Int
  let length: Int

  var description: String { return "\(start):\(length)" }

  public static func < (lhs: SourceRange, rhs: SourceRange) -> Bool {
    return [lhs.start, lhs.length].lexicographicallyPrecedes([rhs.start, rhs.length])
  }
}

extension Dictionary {
  mutating func merge(_ dict: [Key: Value]){
    for (k, v) in dict {
      updateValue(v, forKey: k)
    }
  }
}

struct CodeFragment: ExpressibleByStringLiteral, ExpressibleByStringInterpolation, CustomStringConvertible {
  private var children: [Int: CodeFragment] = [:]

  private var string: String = ""

  struct StringInterpolation: StringInterpolationProtocol {
    // start with an empty string
    var output: CodeFragment = ""

    // allocate enough space to hold twice the amount of literal text
    init(literalCapacity: Int, interpolationCount: Int) {
      output.string.reserveCapacity(literalCapacity * 2)
    }

    // a hard-coded piece of text – just add it
    mutating func appendLiteral(_ literal: String) {
      output.string.append(literal)
    }

    // a Twitter username – add it as a link
    mutating func appendInterpolation(_ fragment: CodeFragment) {
      let position = output.string.count
      output.children[position] = fragment
      output.string.append(fragment.string)
    }
  }

   // the finished text for this whole component
   var description: String {
     get {
       return "<Code> \(string)"
     }
   }

  // create an instance from a literal string
  init(stringLiteral value: String) {
    string = value
  }

  // create an instance from an interpolated string
  init(stringInterpolation: StringInterpolation) {
    string = stringInterpolation.output.string
    children = stringInterpolation.output.children
  }

  public func generateSourceMap() -> [SourceRange: String] {
    return generateSourceMap(offset: 0)
  }

  private func generateSourceMap(offset: Int) -> [SourceRange: String] {
    var srcMap = children
      .map { pos, child in child.generateSourceMap(offset: pos + offset) }
      .reduce(into: [SourceRange:String](), { result, curr in result.merge(curr) })

    srcMap[SourceRange(start: offset, length: string.count)] = string
    return srcMap
  }
}

func main() {
  let inner: CodeFragment = "inner"
  let middle: CodeFragment = "middle \(inner) middle"
  let outer: CodeFragment = "outer \(middle) outer"
  print(inner)
  print(middle)
  print(outer)
  print(outer.generateSourceMap())
}

//func main() {
//  command(
//      Argument<String>("Transaction hash", description: "Hash of the transaction to be debugged")
//  ) { txHash in
//
//    let debugger = Debugger(txHash: txHash)
//
//    do {
//      try debugger.run()
//    } catch let err {
//      print(err)
//      exit(1)
//    }
//
//  }.run()
//}

main()
