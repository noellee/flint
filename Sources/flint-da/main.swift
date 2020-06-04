import Foundation
import Rainbow
import DebugAdapterProtocol
import Commander

func main() {
  command(
      Option<String?>("log-file", default: nil, description: "File to write logs to"),
      Option<LoggingLevel?>("log-level", default: nil, description: "Logging level"),
      Option<String>("rpc-url", default: "http://localhost:8545", description: "Ethereum client RPC URL"),
      Option<String?>("input", default: nil, description: "Input, defaults to stdin"),
      Option<String?>("output", default: nil, description: "Output, defaults to stdout")
  ) { logFile, loggingLevel, rpcURL, inputPath, outputPath in

    var input = FileHandle.standardInput
    if let path = inputPath {
      input = FileHandle(forReadingAtPath: path)!
    }

    var output = FileHandle.standardOutput
    if let path = outputPath {
      output = FileHandle(forWritingAtPath: path)!
    }

    let logger = createLogger(fromFile: logFile, minimumLevel: loggingLevel)

    DebugAdapter(input, output, logger)
        .withMessageHandler { sender in
          FlintDAPMessageHandler(send: sender, rpcURL: rpcURL, logger: logger)
        }
        .start()

  }.run()
}

func createLogger(fromFile: String?, minimumLevel: LoggingLevel?) -> Logger? {
  guard let logFile = fromFile else {
    return nil
  }
  let fileManager = FileManager.default
  if fileManager.fileExists(atPath: logFile) {
    try! fileManager.removeItem(atPath: logFile)
  }
  fileManager.createFile(atPath: logFile, contents: Data())
  let fileHandle = FileHandle(forWritingAtPath: logFile)!
  return minimumLevel != nil ? FileLogger(file: fileHandle, minimumLevel: minimumLevel!) : FileLogger(file: fileHandle)
}

main()
