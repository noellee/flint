import Foundation
import DebugAdapterProtocol
import Debugger
import Source

struct ExtraLaunchArguments {
  var txHash: String
  var artifactDirectory: String

  init(_ args: LaunchArguments) throws {
    guard let txHash = args.extraArgs["txHash"] as? String else {
      throw DebuggerError.invalidLaunchArgument("txHash", "String")
    }
    guard let artifactDirectory = args.extraArgs["artifactDirectory"] as? String else {
      throw DebuggerError.invalidLaunchArgument("artifactDirectory", "String")
    }

    self.txHash = txHash
    self.artifactDirectory = artifactDirectory
  }
}

class FlintDAPMessageHandler: ProtocolMessageHandler {
  let THREAD_ID = 1 // dummy thread id

  let send: ProtocolMessageSender
  let logger: Logger?
  let rpcURL: String
  var debugger: Debugger?

  var currSeq: Int = 1

  init(send: @escaping ProtocolMessageSender, rpcURL: String, logger: Logger? = nil) {
    self.send = send
    self.logger = logger
    self.rpcURL = rpcURL
  }

  func handle(message: ProtocolMessage) {
    switch message {
    case .request(seq: let seq, request: let request):
      do {
        try processRequest(seq, request)
      } catch let error {
        logger?.log("\(error)", level: .error)
        sendResponse(.error(RequestResult(requestSeq: seq, success: false, message: "\(error)")))
      }
    default: // ignore other cases
      break
    }
  }

  func processRequest(_ seq: Int, _ request: RequestMessage) throws {
    logger?.log("Processing request \(request.label)", level: .debug)
    let result = RequestResult(requestSeq: seq, success: true, message: nil)
    switch request {
    case .goto:
      break
    case .next:
      sendResponse(.next(result))
      self.debugger!.stepNext()
    case .stepIn:
      sendResponse(.stepIn(result))
      self.debugger!.stepIn()
    case .stepOut:
      sendResponse(.stepOut(result))
      self.debugger!.stepOut()
    case .stepBack:
      sendResponse(.stepBack(result))
      self.debugger!.stepBack()
    case .continue:
      sendResponse(.continue(result, ContinueResponse(allThreadsContinued: true)))
      self.debugger!.continueRun()
    case .reverseContinue:
      sendResponse(.reverseContinue(result))
      self.debugger!.continueRun(reverse: true)
    case .initialize:
      let capabilities = Capabilities(supportsConfigurationDoneRequest: true, supportsStepBack: true)
      sendResponse(.initialize(result, capabilities))
      sendEvent(.initialized)
    case .launch(let args):
      let extras = try ExtraLaunchArguments(args)
      try initDebugger(args: extras)
      self.debugger!.stopOnEntry()
      sendResponse(.launch(result))
    case .setBreakpoints(let args):
      let breakpoints = args.breakpoints?.map { bp in
        Breakpoint(
            verified: true,
            source: args.source,
            line: bp.line,
            column: bp.column)
      } ?? []
      self.debugger!.clearBreakpoints()
      args.breakpoints?.forEach { bp in self.debugger!.addBreakpoint(bp.line) }
      sendResponse(.setBreakpoints(result, SetBreakpointsResponse(breakpoints: breakpoints)))
    case .setFunctionBreakpoints:
      sendResponse(.setFunctionBreakpoints(result, SetFunctionBreakpointsResponse(breakpoints: [])))
    case .setDataBreakpoints:
      sendResponse(.setDataBreakpoints(result, SetDataBreakpointsResponse(breakpoints: [])))
    case .setExceptionBreakpoints:
      sendResponse(.setExceptionBreakpoints(result))
    case .configurationDone:
      sendResponse(.configurationDone(result))
      sendEvent(.stopped(StoppedEvent(reason: .entry, threadId: THREAD_ID)))
    case .threads:
      sendResponse(.threads(result, ThreadsResponse(threads: [Thread(id: THREAD_ID, name: "Main thread")])))
    case .stackTrace:
      let frames: [StackFrame] = self.debugger!.stackFrame
          .filter { return $0.sourceLoc != nil }
          .enumerated()
          .map { item in
            let i = item.offset
            let frame = item.element
            let file = frame.sourceLoc!.file
            return StackFrame(
                id: i,
                name: frame.name,
                source: Source(name: file.lastPathComponent, path: file.path),
                line: frame.sourceLoc!.line,
                column: frame.sourceLoc!.column,
                endLine: frame.sourceLoc!.line,
                endColumn: frame.sourceLoc!.column + frame.sourceLoc!.length,
                presentationHint: .emphasize)
          }
      sendResponse(.stackTrace(result, StackTraceResponse(stackFrames: frames, totalFrames: frames.count)))
    case .scopes:
      sendResponse(.scopes(result, ScopesResponse(scopes: [
        Scope(name: "stack", variablesReference: 1, expensive: false),
        Scope(name: "memory", variablesReference: 2, expensive: false),
        Scope(name: "storage", variablesReference: 3, expensive: false),
        Scope(name: "flint", variablesReference: 4, expensive: false),
        Scope(name: "evm", variablesReference: 5, expensive: false)
      ])))
    case .variables(let args):
      var vars: [(name: String, value: String)]
      switch args.variablesReference {
      case 1:
        vars = self.debugger!.stackVariables
      case 2:
        vars = self.debugger!.memoryVariables
      case 3:
        vars = self.debugger!.storageVariables
      case 4:
        vars = self.debugger!.flintVariables
      case 5:
        vars = self.debugger!.evmVariables
      default:
        vars = []
      }
      let variables = vars.map { name, value in
        Variable(name: name, value: value, variablesReference: 0)
      }.sorted()
      sendResponse(.variables(result, VariablesResponse(variables: variables)))
    case .disconnect:
      sendResponse(.disconnect(result))
      sendEvent(.terminated(nil))
      sendEvent(.exited(ExitedEvent(exitCode: 0)))
    }
  }

  private func initDebugger(args: ExtraLaunchArguments) throws {
    self.debugger = try Debugger(txHash: args.txHash,
                                 artifactDirectory: args.artifactDirectory,
                                 rpcURL: self.rpcURL)
    self.debugger!.on(event: .done) { self.sendEvent(.terminated(TerminatedEvent())) }
    self.debugger!.on(event: .breakpoint) {
      self.sendEvent(.stopped(StoppedEvent(reason: .breakpoint, threadId: self.THREAD_ID)))
    }
    self.debugger!.on(event: .step) {
      self.sendEvent(.stopped(StoppedEvent(reason: .step, threadId: self.THREAD_ID)))
    }
  }

  func sendResponse(_ response: ResponseMessage) {
    send(.response(seq: currSeq, response: response))
    currSeq += 1
  }

  func sendEvent(_ event: EventMessage) {
    send(.event(seq: currSeq, event: event))
    currSeq += 1
  }
}
