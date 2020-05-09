import Foundation
import Rainbow
import Web3
import Web3PromiseKit
import PromiseKit

public class DebuggerCLI {
  private var trace: EthereumTransactionTraceObject? { return debugger.trace }
  private var currentLogIndex: Int { return debugger.currentLogIndex}
  private var breakpoints: Set<Int> { return debugger.breakpoints }
  private var sourceCodeManager: SourceCodeManager? { return debugger.sourceCodeManager }

  let debugger: Debugger

  public init(txHash: String, contractName: String, artifactDirectory: String, rpcURL: String) throws {
    self.debugger = try Debugger(
        txHash: txHash,
        contractName: contractName,
        artifactDirectory: artifactDirectory,
        rpcURL: rpcURL
    )
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
          String(repeating: " ", count: loc!.column - 1) + String(repeating: "^", count: min(loc!.length, line.count)))
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

  private func printBreakpoints() {
    if breakpoints.isEmpty {
      print("No breakpoints set.")
      return
    }
    for breakpoint in breakpoints {
      print("Breakpoint at \(breakpoint)")
    }
  }

  public func run() throws {
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
        debugger.stepNext()
      case "c":
        debugger.continueRun()
      case "b":
        let breakpoint = Int(tokens[1])
        if breakpoint == nil {
          print("Breakpoint must be an integer")
          continue
        }
        debugger.addBreakpoint(breakpoint!)
      case "B":
        let breakpoint = Int(tokens[1])
        if breakpoint == nil {
          print("Breakpoint must be an integer")
          continue
        }
        debugger.removeBreakpoint(breakpoint: breakpoint!)
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
