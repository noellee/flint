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
  public var stackFrame: [(name: String, sourceLoc: SourceLocation?)] {
    return [(name: "frame", sourceLoc: currentSourceLocation)]
  }

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

  public var variables: [(name: String, value: String)] {
    let log = trace!.structLogs[currentLogIndex]
    return (log.stack?.enumerated().map { i, item in
      (name: "\(i)", value: item.string ?? "")
    } ?? []) + [
      (name: "op", value: log.op),
      (name: "pc", value: "\(log.pc)"),
      (name: "jump", value: "\(sourceCodeManager.getJumpType(pc: Int(log.pc)))")
    ]
  }

  public func stepOut() {
    var log = trace!.structLogs[currentLogIndex]
    repeat {
      currentLogIndex += 1
      log = trace!.structLogs[currentLogIndex]
      if case .Return = sourceCodeManager.getJumpType(pc: Int(log.pc)) {
        break
      }
    } while currentLogIndex < trace!.structLogs.count && !shouldBreak()
    stepInInternal()
    emitLineEvent()
  }

  public func stepNext() {
    var log = trace!.structLogs[currentLogIndex]
    let isAtBreakpoint = shouldBreak()
    switch sourceCodeManager.getJumpType(pc: Int(log.pc)) {
    case .Into:
      let targetFramePointer = log.stack!.count
      repeat {
        currentLogIndex += 1
        log = trace!.structLogs[currentLogIndex]
        if targetFramePointer == log.stack!.count {
          break
        }
      } while currentLogIndex < trace!.structLogs.count && (isAtBreakpoint || !shouldBreak())
    default:
      break
    }
    stepInInternal()
    emitLineEvent()
  }

  private func emitLineEvent() {
    if shouldBreak() {
      emit(.breakpoint)
    } else if currentLogIndex >= trace!.structLogs.count {
      emit(.done)
    } else {
      emit(.step)
    }
  }

  private func stepInInternal() {
    let initLoc = currentSourceLocation
    var currLoc = initLoc
    repeat {
      currentLogIndex += 1
      currLoc = currentSourceLocation

      if currLoc != initLoc && currLoc != nil {
        break
      }
    } while currentLogIndex < trace!.structLogs.count && !shouldBreak()
  }

  public func stepIn() {
    stepInInternal()
    emitLineEvent()
  }

  public func stopOnEntry() {
    repeat {
      currentLogIndex += 1
    } while currentLogIndex < trace!.structLogs.count && currentSourceLocation == nil
    emit(.step)
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
