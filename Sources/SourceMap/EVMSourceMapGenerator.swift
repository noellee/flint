import Foundation
import Source

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
    let fileContent = try! String(contentsOf: self.file) // TODO: change this, shouldn't load file every time
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

  public init(irSourceMap: [SourceRange: SourceLocation], outputDirectory: URL) {
    self.irSourceMap = irSourceMap
    self.outputDirectory = outputDirectory
    self.sourceList = Array(Set(irSourceMap.values.map { $0.file }))
    self.sourceIndices = sourceList.enumerated().reduce(into: [URL: Int](), { (result, source) in
      let (i, url) = source
      result[url] = i
    })
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

  func merge(_ sourceMap: SourceMap) -> SourceMap {
    var newMapping = [SourceMapEntry]()
    for mapping in sourceMap.mappings {
      let match = irSourceMap
          .filter { $0.key.contains(SourceRange(start: mapping.start, length: mapping.length)) }
          .min(by: { $0.key.length < $1.key.length })
          .map { $0.value }

      if match != nil {
        newMapping.append(
            SourceMapEntry(
                start: match!.start,
                length: match!.length,
                srcIndex: getSrcIndex(match!.file),
                jump: mapping.jump,
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

    return SourceMap(mappings: newMapping)
  }
}
