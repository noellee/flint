//
// Created by matthewross on 29/07/19.
//

import Foundation
import AST
import Diagnostic
import Source

public struct MoveGenerator {
  var topLevelModule: TopLevelModule
  var environment: Environment

  // stdlibIncluded:  doesn't include the stdlib, but notifies if it was included
  public init(ast topLevelModule: TopLevelModule,
              environment: Environment,
              sourceContext: SourceContext,
              stdlibIncluded: Bool = true) {
    self.topLevelModule = topLevelModule
    self.environment = environment
    Diagnostics.sourceContext = sourceContext

    if stdlibIncluded {
      MoveRuntimeType.includeStdlib()
      MoveRuntimeFunction.includeStdlib()
    }
  }

  public func generateCode() -> CodeFragment {

    let externalTraitDeclarations = topLevelModule.declarations.compactMap { declaration -> TraitDeclaration? in
      switch declaration {
      case .traitDeclaration(let traitDeclaration):
        return traitDeclaration.moduleAddress != nil ? traitDeclaration : nil
      default:
        return nil
      }
    }

    var contracts: [MoveContract] = []
    // Find the contract behavior declarations associated with each contract.
    for case .contractDeclaration(let contractDeclaration) in topLevelModule.declarations {
      let behaviorDeclarations: [ContractBehaviorDeclaration] = topLevelModule.declarations
          .compactMap { declaration in
            switch declaration {
            case .contractBehaviorDeclaration(let contractBehaviorDeclaration): return contractBehaviorDeclaration
            default: return nil } }
          .filter { $0.contractIdentifier.name == contractDeclaration.identifier.name }

      // Find the struct declarations.
      let structDeclarations = topLevelModule.declarations.compactMap { declaration -> StructDeclaration? in
        guard case .structDeclaration(let structDeclaration) = declaration else { return nil }
        return structDeclaration
      }

      let contract = MoveContract(contractDeclaration: contractDeclaration,
                                  contractBehaviorDeclarations: behaviorDeclarations,
                                  structDeclarations: structDeclarations,
                                  environment: environment,
                                  externalTraitDeclarations: externalTraitDeclarations)
      contracts.append(contract)
    }

    // Generate an IR contract
    let code = contracts.map { $0.rendered() }.joined(separator: "\n")
    return CodeFragment(code)
  }
}
