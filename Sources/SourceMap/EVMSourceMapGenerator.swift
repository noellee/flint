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

  public init(irSourceMap: [SourceRange: SourceLocation], topLevelModule: TopLevelModule, outputDirectory: URL) {
    self.irSourceMap = irSourceMap
    self.outputDirectory = outputDirectory
    self.sourceList = Array(Set(irSourceMap.values.map { $0.file }))
    self.sourceIndices = sourceList.enumerated().reduce(into: [URL: Int](), { (result, source) in
      let (i, url) = source
      result[url] = i
    })

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
  }

  public func generate(filename: String = "srcmap.json") throws {
    let combinedJsonUrl = URL(fileURLWithPath: "combined.json", relativeTo: outputDirectory)
    guard FileManager.default.fileExists(atPath: combinedJsonUrl.path) else {
      throw SourceMapGenerationError.fileNotFound(file: combinedJsonUrl)
    }

    var artifact = try SolcArtifact.from(file: combinedJsonUrl)
    artifact.version = "asfads"
    artifact.sourceList = sourceList.map { $0.path }
    artifact.contracts = [String: ContractInfo](
      uniqueKeysWithValues: artifact.contracts
        .map { (String($0.key.split(separator: ":")[1]), $0.value ) }
        .filter { k, _ in !k.starts(with: "_Interface") }
    )
    for (key, contract) in artifact.contracts {
      artifact.contracts[key]?.srcMap = merge(contract.srcMap)
      artifact.contracts[key]?.srcMapRuntime = merge(contract.srcMapRuntime)
    }
    try artifact.to(file: URL(fileURLWithPath: filename, relativeTo: outputDirectory))
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

      if let srcLoc = match {
        let isFuncCall = self.funcCalls[srcLoc] != nil
        let jump = isFuncCall ? JumpType.Into : mapping.jump
        newMapping.append(
            SourceMapEntry(
                start: srcLoc.start,
                length: srcLoc.length,
                srcIndex: getSrcIndex(srcLoc.file),
                jump: jump,
                modifierDepth: mapping.modifierDepth))
      } else {
        newMapping.append(SourceMapEntry(
            start: 0,
            length: 0,
            srcIndex: -1,
            jump: mapping.jump,
            modifierDepth: mapping.modifierDepth))
      }
    }

    var result = SourceMap(mappings: newMapping)
    let returnInstrs = getReturnInstrs(result)
    returnInstrs.forEach { instr in
      result.mappings[instr].jump = .Return
    }
    return result
  }
}
