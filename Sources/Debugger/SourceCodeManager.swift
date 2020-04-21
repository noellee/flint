import Foundation
import Source
import SourceMap
import Utils
import Web3
import Web3PromiseKit

protocol SourceCodeManager {
  func getSourceLocation(pc: Int) -> SourceLocation?
  func getLine(at: SourceLocation) -> String
}

class SoliditySourceCodeManager: SourceCodeManager {
  var sources: [URL]
  var mappings: [SourceMapEntry] { return contractInfo.srcMapRuntime.mappings }
  var pcToInstrIndex: [Int]
  var contractInfo: ContractInfo

  init(compilerArtifact: URL, contractName: String) throws {
    let artifact = try SolcArtifact.from(file: compilerArtifact)
    self.contractInfo = artifact.contracts[contractName]!
    self.sources = artifact.sourceList.map{ URL(fileURLWithPath: $0) }
    self.pcToInstrIndex = SoliditySourceCodeManager.buildPcToInstrIdxTable(bin: contractInfo.binRuntime.data(using: .hexadecimal)!)
  }

  func getSourceLocation(pc: Int) -> SourceLocation? {
    let instrIndex = pcToInstrIndex[pc]
    let mapping = mappings[instrIndex]
    guard mapping.srcIndex >= 0 else {
      return nil
    }

    let url = sources[mapping.srcIndex]

    let source: String = try! String(contentsOf: url)  // TODO: cache source files?
    let srcPos = source.characterRowAndLineAt(position: mapping.start)
    return SourceLocation(line: srcPos.line,
                          column: srcPos.column,
                          length: mapping.length,
                          file: url)
  }

  func getLine(at sourceLocation: SourceLocation) -> String {
    let sourceCode = try! String(contentsOf: sourceLocation.file)
    let sourceLines = sourceCode.components(separatedBy: .newlines)
    return sourceLines[sourceLocation.line - 1]
  }

  static func getInstructionLength(instr: UInt8) -> UInt8 {
    if 0x60 <= instr && instr < 0x7f {
      return 1 + instr - 0x5f
    }
    return 1
  }

  static func buildPcToInstrIdxTable(bin: Data) -> [Int] {
    var table = [Int]()
    var byteIndex = 0
    var instIndex = 0
    while byteIndex < bin.count {
      let length = getInstructionLength(instr: bin[byteIndex])
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
  func characterRowAndLineAt(position: Int) -> (line: Int, column: Int) {
    let range = NSRange(location: 0, length: position)
    let regex = try! NSRegularExpression(pattern: "[\n\r]")
    let matches = regex.matches(in: self, range: range)
    let line = matches.count
    let lineBeginningPos = line == 0 ? 0 : matches[line - 1].range.upperBound
    let column = position - lineBeginningPos
    return (line: line + 1, column: column)
  }
}
