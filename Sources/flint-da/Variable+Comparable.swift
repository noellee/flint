import Foundation
import DebugAdapterProtocol

extension Variable: Comparable {
  public static func < (lhs: Variable, rhs: Variable) -> Bool {
    return lhs.name < rhs.name
  }

  public static func == (lhs: Variable, rhs: Variable) -> Bool {
    return lhs.name == rhs.name
        && lhs.value == rhs.value
        && lhs.type == rhs.type
        && lhs.evaluateName == rhs.evaluateName
        && lhs.variablesReference == rhs.variablesReference
        && lhs.namedVariables == rhs.namedVariables
        && lhs.indexedVariables == rhs.indexedVariables
        && lhs.memoryReference == rhs.memoryReference
  }
}
