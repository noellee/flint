import Foundation

public enum DebuggerError: Error, CustomStringConvertible {
  case initialization(_ details: String)
  case unknownContract(_ contract: String)
  case invalidTransaction(_ txHash: String)
  case invalidSourceMap(_ sourceMapFile: String, details: String?)
  case invalidLaunchArgument(_ argument: String, _ type: String)

  static func invalidSourceMap(_ sourceMapFile: String) -> DebuggerError {
    return .invalidSourceMap(sourceMapFile, details: nil)
  }

  public var description: String {
    switch self {
    case .initialization(let details): return "Error initializing debugger: \(details)"
    case .unknownContract(let contract): return "Unknown contract: \(contract)"
    case .invalidTransaction(let txHash): return "Invalid transaction: \(txHash)"
    case .invalidSourceMap(let sourceMapFile, let details):
      return "Invalid source map \(sourceMapFile)" + (details == nil ? "" : ": \(details!)")
    case .invalidLaunchArgument(let argument, let type):
      return "Invalid launch argument \"\(argument)\": Expected argument \"\(argument)\" of type \"\(type)\""
    }
  }
}
