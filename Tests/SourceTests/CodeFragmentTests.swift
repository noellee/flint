import XCTest
@testable import Source

final class CodeFragmentTests: XCTestCase {
  func testNestedCodeFragment() {
    let sourceLocA = SourceLocation(line: 1, column: 2, length: 3, file: .init(fileURLWithPath: "a"))
    let sourceLocB = SourceLocation(line: 4, column: 5, length: 6, file: .init(fileURLWithPath: "b"))
    let sourceLocC = SourceLocation(line: 7, column: 8, length: 9, file: .init(fileURLWithPath: "c"))

    let inside = ("inside" as CodeFragment).fromSource(sourceLocA)
    let middle = ("middle \(inside) middle" as CodeFragment).fromSource(sourceLocB)
    let result = ("outside \(middle) outside" as CodeFragment).fromSource(sourceLocC)
    print(result)

    //                               0         1          2         3
    //                               0123456789012345678901234567890123456789
    XCTAssert(result.description == "outside middle inside middle outside")

    let sourceMap = result.generateSourceMap()

    sourceMap
        .sorted { $0.key.start < $1.key.start }
        .filter { $0.value != .DUMMY }
        .forEach { print($0, $1) }

    XCTAssert(sourceMap[SourceRange(start: 0, length: 36)] == sourceLocC)
    XCTAssert(sourceMap[SourceRange(start: 8, length: 20)] == sourceLocB)
    XCTAssert(sourceMap[SourceRange(start: 15, length: 6)] == sourceLocA)
  }

  func testMultipleStringInterpolation() {
    let sourceLocA = SourceLocation(line: 1, column: 2, length: 3, file: .init(fileURLWithPath: "a"))
    let sourceLocB = SourceLocation(line: 4, column: 5, length: 6, file: .init(fileURLWithPath: "b"))
    let sourceLocC = SourceLocation(line: 7, column: 8, length: 9, file: .init(fileURLWithPath: "c"))

    let fragmentA = CodeFragment("Fragment A").fromSource(sourceLocA)
    let fragmentB = CodeFragment("Fragment BB").fromSource(sourceLocB)
    let fragmentC = CodeFragment("Fragment CCC").fromSource(sourceLocC)

    // 0         1         2         3
    // 0123456789012345678901234567890123456789
    // Fragment A Fragment BB Fragment CCC
    let result: CodeFragment = "\(fragmentA) \(fragmentB) \(fragmentC)"

    print(result)
    XCTAssert(result.description == "Fragment A Fragment BB Fragment CCC")

    let sourceMap = result.generateSourceMap()

    sourceMap
      .sorted { $0.key.start < $1.key.start }
      .forEach { print($0, $1) }

    XCTAssert(sourceMap[SourceRange(start: 0, length: 10)] == sourceLocA)
    XCTAssert(sourceMap[SourceRange(start: 11, length: 11)] == sourceLocB)
    XCTAssert(sourceMap[SourceRange(start: 23, length: 12)] == sourceLocC)
  }

  func testJoinCodeFragments() {
    let sourceLocA = SourceLocation(line: 1, column: 2, length: 3, file: .init(fileURLWithPath: "a"))
    let sourceLocB = SourceLocation(line: 4, column: 5, length: 6, file: .init(fileURLWithPath: "b"))
    let sourceLocC = SourceLocation(line: 7, column: 8, length: 9, file: .init(fileURLWithPath: "c"))

    let fragmentA = CodeFragment("Fragment A").fromSource(sourceLocA)
    let fragmentB = CodeFragment("Fragment BB").fromSource(sourceLocB)
    let fragmentC = CodeFragment("Fragment CCC").fromSource(sourceLocC)

    // 0         1         2         3
    // 0123456789012345678901234567890123456789
    // Fragment A Fragment BB Fragment CCC
    let result: CodeFragment = [fragmentA, fragmentB, fragmentC].joined(separator: " ")
    print(result)

    XCTAssert(result.description == "Fragment A Fragment BB Fragment CCC")

    let sourceMap = result.generateSourceMap()

    sourceMap
        .sorted { $0.key.start < $1.key.start }
        .forEach { print($0, $1) }

    XCTAssert(sourceMap[SourceRange(start: 0, length: 10)] == sourceLocA)
    XCTAssert(sourceMap[SourceRange(start: 11, length: 11)] == sourceLocB)
    XCTAssert(sourceMap[SourceRange(start: 23, length: 12)] == sourceLocC)
  }

  func testIndentation() {
    let sourceLocA = SourceLocation(line: 1, column: 2, length: 3, file: .init(fileURLWithPath: "a"))
    let sourceLocB = SourceLocation(line: 4, column: 5, length: 6, file: .init(fileURLWithPath: "b"))
    let sourceLocC = SourceLocation(line: 7, column: 8, length: 9, file: .init(fileURLWithPath: "c"))

    let fragmentA = CodeFragment("Fragment A").fromSource(sourceLocA)
    let fragmentB = CodeFragment("Fragment BB").fromSource(sourceLocB)
    let fragmentC = CodeFragment("Fragment CCC").fromSource(sourceLocC)

    // 0         1         2         3
    // 0123456789012345678901234567890123456789
    // Fragment A Fragment BB Fragment CCC
    let fragment: CodeFragment = "\(fragmentA)\n\(fragmentB)\n\(fragmentC)"
    let indented = fragment.indented(by: 2)

    print(indented)
    XCTAssert(fragment.description == """
                                      Fragment A
                                      Fragment BB
                                      Fragment CCC
                                      """)
    XCTAssert(indented.description == """
                                      Fragment A
                                        Fragment BB
                                        Fragment CCC
                                      """)

    let sourceMap = indented.generateSourceMap()

    sourceMap
        .sorted { $0.key.start < $1.key.start }
        .forEach { print($0, $1) }

    XCTAssert(sourceMap[SourceRange(start: 0, length: 10)] == sourceLocA)
    XCTAssert(sourceMap[SourceRange(start: 13, length: 11)] == sourceLocB)
    XCTAssert(sourceMap[SourceRange(start: 27, length: 12)] == sourceLocC)
  }

  func testIndentationAndFirst() {
    let sourceLocA = SourceLocation(line: 1, column: 2, length: 3, file: .init(fileURLWithPath: "a"))
    let sourceLocB = SourceLocation(line: 4, column: 5, length: 6, file: .init(fileURLWithPath: "b"))
    let sourceLocC = SourceLocation(line: 7, column: 8, length: 9, file: .init(fileURLWithPath: "c"))

    let fragmentA = CodeFragment("Fragment A").fromSource(sourceLocA)
    let fragmentB = CodeFragment("Fragment BB").fromSource(sourceLocB)
    let fragmentC = CodeFragment("Fragment CCC").fromSource(sourceLocC)

    // 0         1         2         3
    // 0123456789012345678901234567890123456789
    // Fragment A Fragment BB Fragment CCC
    let fragment: CodeFragment = "\(fragmentA)\n\(fragmentB)\n\(fragmentC)"
    let indented = fragment.indented(by: 2, andFirst: true)

    print(indented)
    XCTAssert(fragment.description == """
                                      Fragment A
                                      Fragment BB
                                      Fragment CCC
                                      """)
    XCTAssert(indented.description == """
                                        Fragment A
                                        Fragment BB
                                        Fragment CCC
                                      """)

    let sourceMap = indented.generateSourceMap()

    sourceMap
        .sorted { $0.key.start < $1.key.start }
        .forEach { print($0, $1) }

    XCTAssert(sourceMap[SourceRange(start: 2, length: 10)] == sourceLocA)
    XCTAssert(sourceMap[SourceRange(start: 15, length: 11)] == sourceLocB)
    XCTAssert(sourceMap[SourceRange(start: 29, length: 12)] == sourceLocC)
  }

  static var allTests = [
    ("testNestedCodeFragment", testNestedCodeFragment),
    ("testMultipleStringInterpolation", testMultipleStringInterpolation),
    ("testJoinCodeFragments", testJoinCodeFragments),
    ("testIndentation", testIndentation),
    ("testIndentationAndFirst", testIndentationAndFirst)
  ]
}
