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

  private var reverse: Bool = false

  let debugger: Debugger

  public init(txHash: String, artifactDirectory: String, rpcURL: String) throws {
    self.debugger = try Debugger(
        txHash: txHash,
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
      print(padding, underline.green)
    }
  }

  private func printSourceAt(index: Int) {
    guard let loc = debugger.currentSourceLocation else {
      return
    }
    let extraBefore = 2
    let extraAfter = 1
    let lines = sourceCodeManager!.getLines(at: loc, extraBefore: extraBefore, extraAfter: extraAfter)

    print("\n\(loc.file.relativeString):\n")
    for (i, line) in lines.enumerated() {
      let lineLabel = "\(loc.line - extraBefore + i): "
      print(lineLabel, line)

      if i == extraBefore {
        let padding = String(repeating: " ", count: lineLabel.count)
        let underline = String(repeating: "^", count: min(loc.length, line.count)).green
        print(padding, String(repeating: " ", count: loc.column - 1) + underline)
      }
    }
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

  private func printVariables(location: String) {
    let variables: [(name: String, value: String)]
    switch location {
    case "stack":
      variables = debugger.stackVariables
    case "memory":
      variables = debugger.memoryVariables
    case "storage":
      variables = debugger.storageVariables
    case "evm":
      variables = debugger.evmVariables
    case "flint":
      variables = debugger.flintVariables
    default:
      variables = []
    }
    print(variables.map { "\($0.name): \($0.value)" }.joined(separator: "\n"))
  }

  private func toggleReverse() {
    reverse.toggle()
  }

  public func run() throws {
    guard self.trace != nil else {
      print("Unable to obtain trace for this transaction".lightRed.bold)
      return
    }
    mainLoop: while currentLogIndex < trace!.structLogs.count {
      print()
      printSourceContext()
      print()
      if reverse {
        print()
        print("Reverse debugging: ON".lightCyan)
      }
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
      case "i":
        if reverse {
          debugger.stepBack()
        } else {
          debugger.stepIn()
        }
      case "o":
        debugger.stepOut()
      case ";":
        var count = 1
        if tokens.count == 2, let arg = Int(tokens[1]) {
          count = arg
        }
        debugger.stepInstruction(count: count, reverse: reverse)
      case "c":
        debugger.continueRun(reverse: reverse)
      case "b":
        guard let breakpoint = Int(tokens[1]) else {
          print("Breakpoint must be an integer")
          continue
        }
        debugger.addBreakpoint(breakpoint)
      case "B":
        guard let breakpoint = Int(tokens[1]) else {
          print("Breakpoint must be an integer")
          continue
        }
        debugger.removeBreakpoint(breakpoint: breakpoint)
      case "r":
        toggleReverse()
      case "p":
        guard tokens.count > 1 else {
          continue
        }
        printVariables(location: String(tokens[1]))
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
