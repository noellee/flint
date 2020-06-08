import Foundation
import Source
import AST

public enum SourceMapGenerationError: LocalizedError {
  case fileNotFound(file: URL)

  public var errorDescription: String? {
    switch self {
    case .fileNotFound(let file):
      return "Cannot generate source map: \(file.path) not found"
    }
  }
}

extension SourceLocation {
  var start: Int {
    guard let fileContent = try? String(contentsOf: self.file) else { // TODO: shouldn't load file every time
      return 0
    }
    return fileContent
        .components(separatedBy: .newlines)
        .map { $0.count + 1 }
        .prefix(upTo: self.line - 1)
        .reduce(0, { $0 + $1 }) + self.column - 1
  }
}

public class EVMSourceMapGenerator {
  let irSourceMap: [SourceRange: SourceLocation]
  let outputDirectory: URL
  let sourceList: [URL]
  let sourceIndices: [URL: Int]
  let funcCalls: [SourceLocation: String]
  let functionDeclarations: [FunctionDeclaration]
  let variableDeclarations: [String: [VariableDeclaration]]  // contract name -> [state variables]

  public init(irSourceMap: [SourceRange: SourceLocation], topLevelModule: TopLevelModule, outputDirectory: URL) {
    self.irSourceMap = irSourceMap
    self.outputDirectory = outputDirectory
    self.sourceList = Array(Set(irSourceMap.values.map { $0.file }))
    self.sourceIndices = sourceList.enumerated().reduce(into: [URL: Int]()) { (result, source) in
      let (i, url) = source
      result[url] = i
    }

    self.funcCalls = topLevelModule.extractExpressions()
        .compactMap { expr -> FunctionCall? in
          if case let .functionCall(call) = expr {
            return call
          } else {
            return nil
          }
        }
        .reduce(into: [SourceLocation: String]()) { result, call in
          result[call.sourceLocation] = call.identifier.name
        }
    self.functionDeclarations = topLevelModule.extractFunctionDeclarations()
    self.variableDeclarations = topLevelModule.extractContractDeclarations()
        .reduce(into: [String: [VariableDeclaration]]()) { (dict, contract) in
          dict[contract.identifier.name] = contract.extractVariableDeclarations()
        }
  }

  public func generate(filename: String = "srcmap.json") throws {
    let combinedJsonUrl = URL(fileURLWithPath: "combined.json", relativeTo: outputDirectory)
    guard FileManager.default.fileExists(atPath: combinedJsonUrl.path) else {
      throw SourceMapGenerationError.fileNotFound(file: combinedJsonUrl)
    }

    var artifact = try SolcArtifact.from(file: combinedJsonUrl)
    artifact.version = "flintc"
    artifact.sourceList = sourceList.map { $0.path }
    artifact.contracts = [String: ContractInfo](
      uniqueKeysWithValues: artifact.contracts
        .map { (String($0.key.split(separator: ":")[1]), $0.value ) }
        .filter { k, _ in !k.starts(with: "_Interface") }
    )
    for (key, contract) in artifact.contracts {
      artifact.contracts[key]?.srcMap = merge(contract.srcMap)
      artifact.contracts[key]?.srcMapRuntime = merge(contract.srcMapRuntime)
      artifact.contracts[key]?.metadata = generateMetadata(contractName: key)
    }
    try artifact.to(file: URL(fileURLWithPath: filename, relativeTo: outputDirectory))
  }

  private func generateMetadata(contractName: String) -> ContractMetadata {
    let varDecls: [VariableDeclaration] = self.variableDeclarations[contractName] ?? []
    let storage: [StorageVariable] = varDecls.map { varDecl in
      let name = varDecl.identifier.name
      switch varDecl.type.rawType {
      case .fixedSizeArrayType(_, let size):
        return StorageVariable(name: name, size: size)
      default:
        return StorageVariable(name: name, size: nil)
      }
    }
    return ContractMetadata(storage: storage)
  }

  private func getSrcIndex(_ src: URL) -> Int {
    return sourceIndices[src] ?? -1
  }

  private func getReturnInstrs(_ sourceMap: SourceMap) -> [Int] {
    return self.functionDeclarations.compactMap { decl -> Int? in
      sourceMap.mappings.enumerated().filter { _, entry in
        entry.start == decl.sourceLocation.start && entry.length == decl.sourceLocation.length
      }.map { $0.offset }.max()
    }
  }

  func merge(_ sourceMap: SourceMap) -> SourceMap {
    var newMapping = [SourceMapEntry]()
    for mapping in sourceMap.mappings {
      let match = irSourceMap
          .filter { $0.key.contains(SourceRange(start: mapping.start, length: mapping.length)) }
          .min(by: { $0.key.length < $1.key.length })
          .map { $0.value }

      let newEntry: SourceMapEntry
      if let srcLoc = match {
        let isFuncCall = self.funcCalls[srcLoc] != nil
        let jump = isFuncCall ? JumpType.into : mapping.jump
        newEntry = SourceMapEntry(
            start: srcLoc.start,
            length: srcLoc.length,
            srcIndex: getSrcIndex(srcLoc.file),
            jump: jump
        )
      } else {
        newEntry = SourceMapEntry(
            start: 0,
            length: 0,
            srcIndex: -1,
            jump: mapping.jump
        )
      }
      newMapping.append(newEntry)
    }

    var result = SourceMap(mappings: newMapping)
    let returnInstrs = getReturnInstrs(result)
    returnInstrs.forEach { instr in
      result.mappings[instr].jump = .return
    }
    return result
  }
}
