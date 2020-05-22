import Foundation
import DebugAdapterProtocol
import Rainbow

class FileLogger: Logger {
  let file: FileHandle
  let minimumLevel: LoggingLevel

  init(file: FileHandle, minimumLevel: LoggingLevel = .debug, enableColors: Bool = true) {
    self.file = file
    self.minimumLevel = minimumLevel
    if enableColors {
      Rainbow.outputTarget = OutputTarget.console
    }
  }

  func log(_ message: CustomStringConvertible) {
    log(message, level: .info)
  }

  func log(_ message: CustomStringConvertible, level: LoggingLevel) {
    guard level >= minimumLevel else { return }

    let levelTag = "[\(level)]".applyingColor(level.color)
    let fullMessage = "\(Date()) \(levelTag) \(message)\n"

    guard let data = fullMessage.data(using: .utf8) else { return }

    self.file.write(data)
  }
}

fileprivate extension LoggingLevel {
  var color: Color {
    switch self {
    case .error:
      return .red
    case .warning:
      return .yellow
    case .info:
      return .blue
    case .debug:
      return .white
    }
  }
}
