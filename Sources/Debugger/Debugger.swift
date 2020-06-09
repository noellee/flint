import Foundation
import Source
import Web3
import Web3PromiseKit
import PromiseKit

public class Debugger: EventEmitter<DebuggerEvent> {
  var trace: EthereumTransactionTraceObject
  var currentLogIndex: Int = 0
  var breakpoints: Set<Int> = []
  var sourceCodeManager: SourceCodeManager
  public var stackFrame: [(name: String, sourceLoc: SourceLocation?)] {
    return [(name: "frame", sourceLoc: currentSourceLocation)]
  }

  public init(txHash: String, artifactDirectory: String,
              rpcURL: String = "http://localhost:8545") throws {
    let web3 = Web3(rpcURL: rpcURL)
    guard let txHashData = try? EthereumData(ethereumValue: txHash) else {
      throw DebuggerError.initialization("Invalid tx hash \"\(txHash)\"")
    }

    let code = try EthereumUtils.getContractCode(web3: web3, txHash: txHashData)
    self.trace = try EthereumUtils.getTransaction(web3: web3, txHash: txHashData)
    self.sourceCodeManager = try Debugger.loadSourceMap(artifactDirectory, for: code)
    super.init()
  }

  private static func loadSourceMap(_ artifactDirectory: String,
                                    `for` contractCode: String) throws -> FlintSourceCodeManager {
    let artifactDirURL = URL(fileURLWithPath: artifactDirectory, isDirectory: true)
    let artifactURL = URL(fileURLWithPath: "srcmap.json", relativeTo: artifactDirURL)
    return try FlintSourceCodeManager(compilerArtifact: artifactURL, contractCode: contractCode)
  }

  public var currentSourceLocation: SourceLocation? {
    return currentLogEntry != nil ? sourceCodeManager.getSourceLocation(pc: Int(currentLogEntry!.pc)) : nil
  }

  public var currentLogEntry: EthereumStructLogEntry? {
    return trace.structLogs.indices.contains(currentLogIndex) ? trace.structLogs[currentLogIndex] : nil
  }

  public var stackVariables: [(name: String, value: String)] {
    return currentLogEntry?.stack?.enumerated().map { i, item in
      (name: "\(i)", value: item.string ?? "")
    } ?? []
  }

  public var evmVariables: [(name: String, value: String)] {
    guard let log = currentLogEntry else {
      return []
    }
    return [
      (name: "op", value: log.op),
      (name: "pc", value: "\(log.pc)"),
      (name: "gas", value: "\(log.gas)"),
      (name: "gasCost", value: "\(log.gasCost)"),
      (name: "jump", value: "\(sourceCodeManager.getJumpType(pc: Int(log.pc)))")
    ]
  }

  public var flintVariables: [(name: String, value: String)] {
    let rawTypeState = currentLogEntry?.storage?.first { (key, _) in
      if let position = Int(key, radix: 16),
         sourceCodeManager.storageRange.contains(position) {
        return false
      }
      return true
    }?.value.string
    guard rawTypeState != nil,
          let rawTypeStateInt = Int(rawTypeState!),
          let typeState = sourceCodeManager.resolveTypeState(rawTypeStateInt) else {
      return []
    }

    return [(name: "state", value: typeState)]
  }

  public var memoryVariables: [(name: String, value: String)] {
    return currentLogEntry?.memory?
        .enumerated()
        .map {i, item in (name: "\(i)", value: item.string ?? "")} ?? []
  }

  public var storageVariables: [(name: String, value: String)] {
    return currentLogEntry?.storage?
        .compactMap { (key, val) -> (name: String, value: String)? in
          guard let value = val.string,
                let position = Int(key, radix: 16),
                let name = sourceCodeManager.resolveStorageVarName(position) else {
            return nil
          }
          return (name: name, value: value)
        }
        ?? []
  }

  public func stepOut() {
    var log = currentLogEntry!
    repeat {
      currentLogIndex += 1
      log = currentLogEntry!
      if case .return = sourceCodeManager.getJumpType(pc: Int(log.pc)) {
        break
      }
    } while currentLogIndex < trace.structLogs.count && !shouldBreak()
    stepInternal()
    emitLineEvent()
  }

  public func stepNext() {
    var log = currentLogEntry!
    let isAtBreakpoint = shouldBreak()
    if sourceCodeManager.getJumpType(pc: Int(log.pc)) == .into {
      let targetFramePointer = log.stack!.count
      repeat {
        currentLogIndex += 1
        log = currentLogEntry!
        if targetFramePointer == log.stack!.count {
          break
        }
      } while currentLogIndex < trace.structLogs.count && (isAtBreakpoint || !shouldBreak())
    }
    stepInternal(ignoreBreakpoints: isAtBreakpoint)
    emitLineEvent()
  }

  private func emitLineEvent() {
    if shouldBreak() {
      emit(.breakpoint)
    } else if currentLogIndex >= trace.structLogs.count {
      emit(.done)
    } else {
      emit(.step)
    }
  }

  private func stepInternal(reverse: Bool = false, ignoreBreakpoints: Bool = false) {
    if currentLogIndex <= 0 && reverse {
      return
    }

    if currentLogIndex >= trace.structLogs.count && !reverse {
      return
    }

    let initLoc = currentSourceLocation
    var currLoc = initLoc
    repeat {
      currentLogIndex += reverse ? -1 : 1
      currLoc = currentSourceLocation

      if currLoc != initLoc && currLoc != nil {
        break
      }
    } while currentLogIndex > 0 && currentLogIndex < trace.structLogs.count && (ignoreBreakpoints || !shouldBreak())
  }

  public func stepInstruction(count: Int = 1, reverse: Bool = false) {
    if currentLogIndex <= 0 && reverse {
      return
    }

    if currentLogIndex >= trace.structLogs.count && !reverse {
      return
    }

    currentLogIndex += reverse ? -count : count
  }

  public func stepIn() {
    stepInternal()
    emitLineEvent()
  }

  public func stepBack() {
    stepInternal(reverse: true)
    emitLineEvent()
  }

  public func stopOnEntry() {
    repeat {
      currentLogIndex += 1
    } while currentLogIndex < trace.structLogs.count && currentSourceLocation == nil
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

  public func continueRun(reverse: Bool = false) {
    repeat {
      currentLogIndex += reverse ? -1 : 1
    } while currentLogIndex < trace.structLogs.count && !shouldBreak()
    emitLineEvent()
  }

  private func shouldBreak() -> Bool {
    return breakpoints.contains(currentSourceLocation?.line ?? -1)
  }
}
