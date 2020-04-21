//
//  SolcCompiler.swift
//  flintc
//
//  Created by Franklin Schrans on 1/8/18.
//

import Foundation
import Utils

/// The solc compiler, used to compile YUL IR.
struct SolcCompiler {
  var inputSource: String
  var outputDirectory: URL
  var emitBytecode: Bool
  var emitSourceMap: Bool

  func compile() throws {
    let temporaryFile = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
      .appendingPathComponent(UUID().uuidString)
    try inputSource.write(to: temporaryFile, atomically: true, encoding: .utf8)

    verifySolc(launchPath: Configuration.solcLocation.path)
    let arguments: [String] =
      [temporaryFile.path, "--bin", "--overwrite"]
      + (emitBytecode ? ["--opcodes"] : [])
      + ["-o", outputDirectory.path]
      + (emitSourceMap ? ["--combined-json", "srcmap-runtime,srcmap,bin,bin-runtime"] : [])
    let processResult = Process.run(executableURL: Configuration.solcLocation,
                                    arguments: arguments,
                                    currentDirectoryURL: nil)
    processResult.standardOutputResult.map { print($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
  }

  private func verifySolc(launchPath: String) {
    guard FileManager.default.isExecutableFile(atPath: launchPath) else {
      exitWithSolcNotInstalledDiagnostic()
    }
  }
}
