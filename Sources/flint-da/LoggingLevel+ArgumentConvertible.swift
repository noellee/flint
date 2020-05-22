import Foundation
import DebugAdapterProtocol
import Commander

extension LoggingLevel: ArgumentConvertible {
  public init(parser: ArgumentParser) throws {
    guard let value = parser.shift() else {
      throw ArgumentError.missingValue(argument: nil)
    }
    guard let level = LoggingLevel(rawValue: value) else {
      throw ArgumentError.invalidType(value: value, type: "Log level", argument: nil)
    }
    self = level
  }
}
