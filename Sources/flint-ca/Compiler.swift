//
//  Compiler.swift
//  flintcPackageDescription
//

//

import Foundation
import AST
import Diagnostic
import Lexer
import Parser
import SemanticAnalyzer
import TypeChecker
import Optimizer
import ContractAnalysis
import IRGen

/// Runs the different stages of the compiler.
struct Compiler {
  var sourceFiles: [URL]
  var sourceCode: String
  var stdlibFiles: [URL]
  var outputDirectory : URL
  var diagnostics: DiagnosticPool
 
  

  var sourceContext: SourceContext {
    return SourceContext(sourceFiles: sourceFiles, sourceCodeString: sourceCode, isForServer: true)
  }

  func tokenizeFiles() throws -> [Token] {
    let stdlibTokens = try StandardLibrary.default.files.flatMap { try Lexer(sourceFile: $0, isFromStdlib: true).lex() }
    let userTokens = try Lexer(sourceFile: sourceFiles[0], isFromStdlib: false, isForServer: true, sourceCode: sourceCode).lex()
    return stdlibTokens + userTokens
  }
    
  func getAST() throws -> (TopLevelModule, Environment) {
    
    let tokens = try tokenizeFiles()
    
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    
    if let failed = try diagnostics.checkpoint(parserDiagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
    }
    
    guard let ast = parserAST else {
        exitWithFailure()
    }
    
    let astPasses: [ASTPass] = [
        SemanticAnalyzer(),
        TypeChecker(),
        Optimizer(),
        IRPreprocessor()
    ]
    
    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast)
        .run(passes: astPasses, in: environment, sourceContext: sourceContext)
    if let failed = try diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
    }
    
    return (parserAST!, environment)
    
  }
    
    
  func compile() throws
  {
    let tokens = try tokenizeFiles()

    // Turn the tokens into an Abstract Syntax Tree (AST).
    let (parserAST, environment, parserDiagnostics) = Parser(tokens: tokens).parse()
    
    if let failed = try diagnostics.checkpoint(parserDiagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
    }
    
    guard let ast = parserAST else {
        exitWithFailure()
    }
    
    let astPasses: [ASTPass] = [
        SemanticAnalyzer(),
        TypeChecker(),
        Optimizer(),
        IRPreprocessor()
    ]
    
    // Run all of the passes.
    let passRunnerOutcome = ASTPassRunner(ast: ast)
        .run(passes: astPasses, in: environment, sourceContext: sourceContext)
    if let failed = try diagnostics.checkpoint(passRunnerOutcome.diagnostics) {
        if failed {
            exitWithFailure()
        }
        exit(0)
    }
    
    // Generate YUL IR code.
    let irCode = IRCodeGenerator(topLevelModule: passRunnerOutcome.element, environment: passRunnerOutcome.environment)
        .generateCode()
    
    // Compile the YUL IR code using solc.
    try SolcCompiler(inputSource: irCode, outputDirectory: outputDirectory, emitBytecode: false).compile()
    
    // these are warnings from the solc compiler
    try diagnostics.display()
    
    let fileName = "main.sol"
    let irFileURL: URL
    irFileURL = outputDirectory.appendingPathComponent(fileName)
    do {
        try irCode.write(to: irFileURL, atomically: true, encoding: .utf8)
    } catch {
        exitWithUnableToWriteIRFile(irFileURL: irFileURL)
    }
    
  }
        
  func exitWithFailure() -> Never {
        print("ERROR")
        exit(0)
  }
}

func exitWithSolcNotInstalledDiagnostic() -> Never {
    let diagnostic = Diagnostic(
        severity: .error,
        sourceLocation: nil,
        message: "ERROR Missing dependency: solc",
        notes: [
            Diagnostic(
                severity: .note,
                sourceLocation: nil,
                message: "Refer to http://solidity.readthedocs.io/en/develop/installing-solidity.html " +
                "for installation instructions.")
        ]
    )
    // swiftlint:disable force_try
    print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
    // swiftlint:enable force_try
    exit(1)
}

func exitWithUnableToWriteIRFile(irFileURL: URL) {
    let diagnostic = Diagnostic(severity: .error,
                                sourceLocation: nil,
                                message: "ERROR Could not write IR file: '\(irFileURL.path)'.")
    // swiftlint:disable force_try
    print(try! DiagnosticsFormatter(diagnostics: [diagnostic], sourceContext: nil).rendered())
    // swiftlint:enable force_try
    exit(1)
}

