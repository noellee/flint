import Foundation

public enum JumpType: String, CustomStringConvertible {
  case into = "i"      // Jump into a function
  case `return` = "o"  // Return from a function
  case regular = "-"   // Generic jump

  public var description: String { return self.rawValue }
}

public struct SourceMapEntry {
  static let NUM_FIELDS = 4

  public var start: Int
  public var length: Int
  public var srcIndex: Int
  public var jump: JumpType

  public func toStringArray() -> [String] {
    return ([start, length, srcIndex, jump] as [CustomStringConvertible]).map { $0.description }
  }
}

public struct SourceMap {
  public var mappings: [SourceMapEntry]

  public static func decompress(_ string: String) -> SourceMap {
    guard !string.isEmpty else {
      return SourceMap(mappings: [])
    }

    var lines: [[String]] = string
        .split(separator: ";", omittingEmptySubsequences: false)
        .map { line in
          line.split(separator: ":", omittingEmptySubsequences: false)
        }
        .map { line in
          line.map(String.init) + Array(repeating: "", count: SourceMapEntry.NUM_FIELDS - line.count)
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
          jump: JumpType(rawValue: line[3]) ?? .regular
      )
    }

    return SourceMap(mappings: mappings)
  }

  public func compress() -> String {
    var lines = mappings.map { $0.toStringArray() }

    guard let first = lines.first else {
      return ""
    }

    var prev = first
    lines = lines.dropFirst().map { curr in
      defer {
        prev = curr
      }
      return curr.enumerated().map { (idx, item) in
        prev[idx] == item ? "" : item
      }.reversed().drop { item in
        item.isEmpty
      }.reversed()
    }
    lines.insert(first, at: 0)

    return lines.map { line in line.joined(separator: ":") }.joined(separator: ";")
  }
}
