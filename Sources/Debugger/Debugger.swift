import Foundation
import Rainbow
import Web3
import Web3PromiseKit
import PromiseKit

public class Debugger {
  var txHash: EthereumData
  var trace: EthereumTransactionTraceObject?
  var currentLogIndex: Int = 0
  var breakpoints: Set<Int> = []
  var sourceCodeManager: SourceCodeManager?
  let contractName: String

  public init(txHash: String, contractName: String) {
    self.txHash = try! EthereumData(ethereumValue: txHash)
    self.contractName = contractName
  }

  private func loadTransaction() throws {
    let web3 = Web3(rpcURL: "http://localhost:8545")
    try firstly {
      web3.debug.traceTransaction(transactionHash: txHash)
    }.done(on: DispatchQueue.global(qos: .userInteractive)) { trace in
      self.trace = trace
    }.wait()
  }

  private func printInstrAt(index: Int, highlightStart: Int = 0, highlightEnd: Int = 0) {
    let log = trace!.structLogs[index]
    print(log.pc, log.op)
    let underline = String(repeating: "^", count: highlightEnd - highlightStart)
    if underline.count > 0 {
      let padding = String(repeating: " ", count: String(log.pc).count)
      print(padding, underline)
    }
  }

  private func printSourceAt(index: Int) {
    let loc = sourceCodeManager!.getSourceLocation(pc: Int(trace!.structLogs[index].pc))
    guard loc != nil else { return }
    let line = sourceCodeManager!.getLine(at: loc!)
    let lineLabel = "\(loc!.line): "

    print("\n\(loc!.file.relativeString):\n")
    print(lineLabel, line)
    let padding = String(repeating: " ", count: lineLabel.count)
    print(padding,
          String(repeating: " ", count: loc!.column) + String(repeating: "^", count: min(loc!.length, line.count)))
  }

  private func printSourceContext() {
    let start = max(currentLogIndex - 3, 0)
    let end = min(currentLogIndex + 3, trace!.structLogs.count - 1)
    for i in start...end {
      if i == currentLogIndex {
        printInstrAt(index: i, highlightStart: 0, highlightEnd: trace!.structLogs[i].op.count)
      } else {
        printInstrAt(index: i)
      }
    }
    printSourceAt(index: currentLogIndex)
  }

  private func stepNext() {
    let initLoc = sourceCodeManager!.getSourceLocation(pc: Int(trace!.structLogs[currentLogIndex].pc))
    var currLoc = initLoc
    repeat {
      currentLogIndex += 1
      currLoc = sourceCodeManager!.getSourceLocation(pc: Int(trace!.structLogs[currentLogIndex].pc))

      if currLoc != initLoc && currLoc != nil { break }

    } while currentLogIndex < trace!.structLogs.count && !shouldBreak()
  }

  private func addBreakpoint(breakpoint: Int) {
    breakpoints.insert(breakpoint)
    print("Breakpoint set at \(breakpoint)")
  }

  private func removeBreakpoint(breakpoint: Int) {
    breakpoints.remove(breakpoint)
    print("Breakpoint \(breakpoint) removed")
  }

  private func continueRun() {
    repeat {
      currentLogIndex += 1
    }
    while currentLogIndex < trace!.structLogs.count && !shouldBreak()
  }

  private func shouldBreak() -> Bool {
    return breakpoints.contains(Int(trace!.structLogs[currentLogIndex].pc))
  }

  private func printBreakpoints() {
    if breakpoints.isEmpty {
      print("No breakpoints set.")
      return
    }
    for breakpoint in breakpoints {
      print("Breakpoint at \(breakpoint)")
    }
  }

  private func loadSourceMap() throws {
    sourceCodeManager = try SoliditySourceCodeManager(compilerArtifact: URL(fileURLWithPath: "bin/srcMap.json"),
                                                      contractName: contractName)
  }

  public func run() throws {
    try loadTransaction()
    try loadSourceMap()
    guard self.trace != nil else {
      print("Unable to obtain trace for this transaction".lightRed.bold)
      return
    }
    mainLoop: while currentLogIndex < trace!.structLogs.count {
      printSourceContext()
      print("fdb> ".lightMagenta, terminator: "")
      let line = readLine()
      guard line != nil else {
        break
      }

      let input = line!
      guard input != "exit" else {
        break
      }

      let tokens = input.split(separator: " ")
      guard tokens.count > 0 else {
        continue
      }

      switch tokens[0] {
      case "n":
        stepNext()
      case "c":
        continueRun()
      case "b":
        let breakpoint = Int(tokens[1])
        if breakpoint == nil {
          print("Breakpoint must be an integer")
          continue
        }
        addBreakpoint(breakpoint: breakpoint!)
      case "B":
        let breakpoint = Int(tokens[1])
        if breakpoint == nil {
          print("Breakpoint must be an integer")
          continue
        }
        removeBreakpoint(breakpoint: breakpoint!)
      case "?":
        printBreakpoints()
      case "exit":
        break mainLoop
      default:
        print("Unknown command \(tokens[0])".lightRed.bold)
      }
    }
    print("Done!")
  }
}
