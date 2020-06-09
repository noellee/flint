import Foundation
import Source
import SourceMap
import Utils
import Web3
import Web3PromiseKit

protocol SourceCodeManager {
  func getSourceLocation(pc: Int) -> SourceLocation?
  func getLines(at: SourceLocation, extraBefore: Int, extraAfter: Int) -> [String]
  func getJumpType(pc: Int) -> JumpType
  func resolveStorageVariable(_ position: Int) -> (name: String, variable: StorageVariable)?
  func resolveTypeState(_ value: Int) -> String?
  var storageRange: Range<Int> { get }
}

class FlintSourceCodeManager: SourceCodeManager {
  var sources: [URL]
  var mappings: [SourceMapEntry] { return contractInfo.srcMapRuntime.mappings }
  var pcToInstrIndex: [Int]
  var contractInfo: ContractInfo

  init(compilerArtifact: URL, contractCode: String) throws {
    guard let artifact = try? SolcArtifact.from(file: compilerArtifact) else {
      throw DebuggerError.invalidSourceMap(compilerArtifact.path)
    }

    self.contractInfo = try FlintSourceCodeManager.resolveContractInfo(artifact: artifact, code: contractCode)
    self.sources = artifact.sourceList.map { URL(fileURLWithPath: $0) }

    guard let bin = contractInfo.binRuntime.data(using: .hexadecimal) else {
      throw DebuggerError.invalidSourceMap(compilerArtifact.path, details: "Corrupted compiler artifact")
    }

    self.pcToInstrIndex = FlintSourceCodeManager.buildPcToInstrIdxTable(bin: bin)
  }

  private static func resolveContractInfo(artifact: CompilerArtifact, code: String) throws -> ContractInfo {
    let match = artifact.contracts.first {
      EthereumUtils.contractCodeEquivalent($0.value.binRuntime, code)
    }
    guard let contractInfo = match?.value else {
      throw DebuggerError.unknownContract
    }
    return contractInfo
  }

  func resolveStorageVariable(_ position: Int) -> (name: String, variable: StorageVariable)? {
    guard let metadata = contractInfo.metadata else {
      return nil
    }
    var offset = 0
    for variable in metadata.storage {
      if let size = variable.size, offset <= position, position < offset + size {  // fixed array type
        let index = position - offset
        return ("\(variable.name)[\(index)]", variable)
      }

      if offset == position {
        return (variable.name, variable)
      }
      offset += variable.size ?? 1
    }
    return nil
  }

  var storageRange: Range<Int> {
    let size = contractInfo.metadata?.storage.map { $0.size ?? 1 }.reduce(0, +) ?? 0
    return 0..<size
  }

  func resolveTypeState(_ value: Int) -> String? {
    let states = self.contractInfo.metadata?.typeStates ?? []
    guard !states.isEmpty else {
      return nil
    }
    return states[value]
  }

  func getSourceLocation(pc: Int) -> SourceLocation? {
    let instrIndex = pcToInstrIndex[pc]
    let mapping = mappings[instrIndex]
    guard mapping.srcIndex >= 0 else {
      return nil
    }

    let url = sources[mapping.srcIndex]

    let source: String = try! String(contentsOf: url)  // TODO: cache source files?
    let srcPos = source.characterLineAndColumnAt(position: mapping.start)
    return SourceLocation(line: srcPos.line,
                          column: srcPos.column,
                          length: mapping.length,
                          file: url)
  }

  func getLines(at sourceLocation: SourceLocation, extraBefore: Int, extraAfter: Int) -> [String] {
    let sourceCode = try! String(contentsOf: sourceLocation.file)
    let sourceLines = sourceCode.components(separatedBy: .newlines)
    let line = sourceLocation.line - 1
    let start = max(line - extraBefore, 0)
    let end = min(line + extraAfter, sourceLines.count)
    return Array(sourceLines[start...end])
  }

  func getJumpType(pc: Int) -> JumpType {
    let instrIndex = pcToInstrIndex[pc]
    let mapping = mappings[instrIndex]
    return mapping.jump
  }

  static func buildPcToInstrIdxTable(bin: Data) -> [Int] {
    var table = [Int]()
    var byteIndex = 0
    var instIndex = 0
    while byteIndex < bin.count {
      let length = EthereumUtils.getInstructionLength(instr: bin[byteIndex])
      for _ in 0..<length {
        table.append(instIndex)
      }
      byteIndex += Int(length)
      instIndex += 1
    }
    return table
  }
}

extension String {
  /// Return the line adn column of a character in a string
  ///
  /// - Parameter position: 0-indexed position
  /// - Returns: 1-indexed line and column of the character at the given position. If the position is out of range, both
  ///            the returned line and column would be 0.
  func characterLineAndColumnAt(position: Int) -> (line: Int, column: Int) {
    guard 0 <= position, position < self.count else {
      return (line: 0, column: 0)
    }
    let range = NSRange(location: 0, length: position)
    let regex = try! NSRegularExpression(pattern: "[\n\r]")
    let matches = regex.matches(in: self, range: range)
    let line = matches.count
    let lineBeginningPos = line == 0 ? 0 : matches[line - 1].range.upperBound
    let column = position - lineBeginningPos
    return (line: line + 1, column: column + 1)
  }
}
