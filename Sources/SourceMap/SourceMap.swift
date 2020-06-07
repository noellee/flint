import Foundation

public enum JumpType: String {
  case into = "i"      // Jump into a function
  case `return` = "o"  // Return from a function
  case regular = "-"   // Generic jump
}

public struct SourceMapEntry {
  public var start: Int
  public var length: Int
  public var srcIndex: Int
  public var jump: JumpType
  public var modifierDepth: Int

  public func toString() -> String {
    return "\(start):\(length):\(srcIndex):\(jump):\(modifierDepth)"
  }
}

public struct SourceMap {
  public var mappings: [SourceMapEntry]

  public static func fromString(_ string: String) -> SourceMap {
    guard !string.isEmpty else {
      return SourceMap(mappings: [])
    }

    var lines: [[String]] = string
        .split(separator: ";", omittingEmptySubsequences: false)
        .map { line in
          line.split(separator: ":", omittingEmptySubsequences: false)
        }
        .map { line in
          line.map(String.init) + Array(repeating: "", count: 5 - line.count)
        }

    for (lineIdx, line) in lines.enumerated().dropFirst() {
      for (fieldIdx, field) in line.enumerated() where field == "" {
        lines[lineIdx][fieldIdx] = lines[lineIdx - 1][fieldIdx]
      }
    }

    // instruction index -> location
    let mappings: [SourceMapEntry] = lines.map { line in
      SourceMapEntry(
          start: Int(line[0])!,
          length: Int(line[1])!,
          srcIndex: Int(line[2])!,
          jump: JumpType(rawValue: line[3]) ?? .regular,
          modifierDepth: Int(line[4]) ?? 0
      )
    }

    return SourceMap(mappings: mappings)
  }

  public func toString() -> String {
    return mappings
        .map { mapping in
          mapping.toString()
        }
        .joined(separator: ";")
  }
}
