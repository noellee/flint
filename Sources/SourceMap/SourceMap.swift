import Foundation

public enum JumpType {
  case None    // Not a jump instr
  case Into    // Jump into a function
  case Return  // Return from a function
  case Regular // Generic jump

  static func fromString(s: String) -> JumpType {
    switch s {
    case "i":
      return .Into
    case "o":
      return .Return
    case "-":
      return .Regular
    default:
      return .None
    }
  }

  func toString() -> String {
    switch self {
    case .Into:
      return "i"
    case .Return:
      return "o"
    case .Regular:
      return "-"
    case .None:
      return ""
    }
  }
}

public struct SourceMapEntry {
  public var start: Int
  public var length: Int
  public var srcIndex: Int
  public var jump: JumpType
  public var modifierDepth: Int

  public func toString() -> String {
    return "\(start):\(length):\(srcIndex):\(jump.toString()):\(modifierDepth)"
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
      for (fieldIdx, field) in line.enumerated() {
        if field == "" {
          lines[lineIdx][fieldIdx] = lines[lineIdx - 1][fieldIdx]
        }
      }
    }

    // instruction index -> location
    let mappings: [SourceMapEntry] = lines.map { line in
      SourceMapEntry(
          start: Int(line[0])!,
          length: Int(line[1])!,
          srcIndex: Int(line[2])!,
          jump: JumpType.fromString(s: line[3]),
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
