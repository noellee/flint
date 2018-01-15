//
//  IRInterface.swift
//  IRGen
//
//  Created by Franklin Schrans on 12/29/17.
//

import AST

struct IULIAInterface {
  var contract: IULIAContract
  var context: Context

  func rendered() -> String {
    let functionSignatures = contract.contractBehaviorDeclarations.flatMap { contractBehaviorDeclaration in
      return contractBehaviorDeclaration.functionDeclarations.flatMap { functionDeclaration in
        return render(functionDeclaration)
      }
    }.joined(separator: "\n")

    let events = contract.contractDeclaration.variableDeclarations.filter { $0.type.isEventType }
    let eventDeclarations = events.map { event -> String in
      let parameters = event.type.genericArguments.map { type in
        return CanonicalType(from: type.rawType)!.rawValue
      }.joined(separator: ",")

      return "event \(event.identifier.name)(\(parameters));"
    }.joined(separator: "\n")

    return """
    interface _Interface\(contract.contractDeclaration.identifier.name) {
      \(functionSignatures.indented(by: 2))
      \(eventDeclarations.indented(by: 2))
    }
    """
  }

  func render(_ functionDeclaration: FunctionDeclaration) -> String? {
    guard functionDeclaration.isPublic else { return nil }

    let parameters = functionDeclaration.explicitParameters.map { render($0) }.joined(separator: ", ")

    var attribute = ""

    if !functionDeclaration.isMutating, !functionDeclaration.containsEventCall(context: context, contractIdentifier: contract.contractDeclaration.identifier) {
      attribute = "view "
    }

    if functionDeclaration.isPayable {
      attribute = "payable "
    }

    let returnCode: String
    if let resultType = functionDeclaration.resultType {
      returnCode = " returns (\(CanonicalType(from: resultType.rawType)!) ret)"
    } else {
      returnCode = ""
    }

    return "function \(functionDeclaration.identifier.name)(\(parameters)) \(attribute)public\(returnCode);"
  }

  func render(_ functionParameter: Parameter) -> String {
    return "\(CanonicalType(from: functionParameter.type.rawType)!.rawValue) \(functionParameter.identifier.name)"
  }
}

fileprivate extension FunctionDeclaration {
  func containsEventCall(context: Context, contractIdentifier: Identifier) -> Bool {
    for statement in body {
      guard case .expression(.functionCall(let functionCall)) = statement else {
        continue
      }
      if context.matchEventCall(functionCall, contractIdentifier: contractIdentifier) != nil {
        return true
      }
    }

    return false
  }
}
