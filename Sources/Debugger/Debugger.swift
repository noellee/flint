import Foundation
import Source
import Web3
import Web3PromiseKit
import PromiseKit

public class Debugger: EventEmitter<DebuggerEvent> {
  var trace: EthereumTransactionTraceObject?
  var currentLogIndex: Int = 0
  var breakpoints: Set<Int> = []
  var sourceCodeManager: SourceCodeManager

  public init(txHash: String, contractName: String, artifactDirectory: String,
              rpcURL: String = "http://localhost:8545") throws {
    self.sourceCodeManager = try Debugger.loadSourceMap(artifactDirectory, for: contractName)
    super.init()
    try loadTransaction(rpcURL: rpcURL, txHash: txHash)
  }

  private func loadTransaction(rpcURL: String, txHash: String) throws {
    let web3 = Web3(rpcURL: rpcURL)

    guard let txHashData = try? EthereumData(ethereumValue: txHash) else {
      throw DebuggerError.initialization("Invalid tx hash \"\(txHash)\"")
    }

    try firstly {
      web3.debug.traceTransaction(transactionHash: txHashData)
    }.done(on: DispatchQueue.global(qos: .userInteractive)) { txTrace in
      guard let trace = txTrace else { throw DebuggerError.invalidTransaction(txHash) }
      self.trace = trace
    }.wait()
  }

  private static func loadSourceMap(_ artifactDirectory: String,
                                    `for` contract: String) throws -> SoliditySourceCodeManager {
    let artifactDirURL = URL(fileURLWithPath: artifactDirectory, isDirectory: true)
    let artifactURL = URL(fileURLWithPath: "srcmap.json", relativeTo: artifactDirURL)
    return try SoliditySourceCodeManager(compilerArtifact: artifactURL, contractName: contract)
  }

  public var currentSourceLocation: SourceLocation? {
    return sourceCodeManager.getSourceLocation(pc: Int(trace!.structLogs[currentLogIndex].pc))
  }

  public func stepNext() {
    let initLoc = currentSourceLocation
    var currLoc = initLoc
    repeat {
      currentLogIndex += 1
      currLoc = currentSourceLocation

      if currLoc != initLoc && currLoc != nil {
        break
      }

    } while currentLogIndex < trace!.structLogs.count && !shouldBreak()

    if shouldBreak() {
      emit(.breakpoint)
    }

    if currentLogIndex >= trace!.structLogs.count {
      emit(.done)
    }
  }

  public func clearBreakpoints() {
    breakpoints.removeAll()
  }

  public func addBreakpoint(_ breakpoint: Int) {
    breakpoints.insert(breakpoint)
  }

  public func removeBreakpoint(breakpoint: Int) {
    breakpoints.remove(breakpoint)
  }

  public func continueRun() {
    repeat {
      currentLogIndex += 1
    } while currentLogIndex < trace!.structLogs.count && !shouldBreak()

    if shouldBreak() {
      emit(.breakpoint)
    }

    if currentLogIndex >= trace!.structLogs.count {
      emit(.done)
    }
  }

  private func shouldBreak() -> Bool {
    return breakpoints.contains(currentSourceLocation?.line ?? -1)
  }
}
