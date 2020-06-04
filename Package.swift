// swift-tools-version:5.0

import PackageDescription

let package = Package(
  name: "flintc",
  platforms: [
    .macOS(.v10_14),
  ],
  products: [
    .executable(
      name: "flintc",
      targets: [
        "flintc",
      ]
    ),
    .executable(
      name: "lite",
      targets: [
        "lite",
      ]
    ),
    .executable(
      name: "file-check",
      targets: [
        "file-check",
      ]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-package-manager",
             .exact(Version(0, 4, 0))),
    .package(url: "https://github.com/krzyzanowskim/CryptoSwift.git", 
             .revision("5d114736f5a98caa8a0ca1c254526f1ce5688f91")),
    .package(url: "https://github.com/onevcat/Rainbow.git", 
             .revision("9c52c1952e9b2305d4507cf473392ac2d7c9b155")),
    .package(url: "https://github.com/kylef/Commander.git", 
             .revision("dc97e80a1cf5df6c5768528f039c65ad8c564712")),
    .package(url: "https://github.com/llvm-swift/Lite.git", 
             .revision("769455af208c8a4e191f187be9d6400422d258a4")),
    .package(url: "https://github.com/llvm-swift/FileCheck.git",
             .revision("00945abac615e5203701be0f090ed0e2d2ff15bf")),
    .package(url: "https://github.com/llvm-swift/Symbolic.git", 
             .revision("076fbd317c880af5ee622633c0b1a9386e2e16bc")),
    .package(url: "https://github.com/flintlang/Cuckoo.git", .branch("master")),
    .package(url: "https://github.com/behrang/YamlSwift.git", 
             .revision("287f5cab7da0d92eb947b5fd8151b203ae04a9a3")),
    .package(url: "https://github.com/attaswift/BigInt.git", 
             .revision("7bd99f7ebb8886cd3a0dfac26fea9c1049027a08")),
    .package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", 
             .revision("bad5f2f94a71216a32c030a3586bdcfc1f7e660b")),
    .package(url: "https://github.com/noellee/Web3.swift",
        .revision("b5ee7c9750f7e97b30ba70840821f4db96b98095")),
    .package(url: "https://github.com/noellee/SwiftDAP",
        .revision("4df9883b11eda511df23c40d2f077e477ce8b68d")),
  ],
  targets: [
    .target(
      name: "flint-lsp",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "LSP", "Compiler", "Utils"]),
    .target(
      name: "flint-ca",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "ContractAnalysis", "Compiler", "Utils"]),
    .target(
      name: "flint-test",
      dependencies: ["Parser", "Lexer", "SemanticAnalyzer", "TypeChecker", "Optimizer", "IRGen", "Commander", "Rainbow", "Symbolic", "Diagnostic", "JSTranslator", "Compiler", "Coverage", "Utils"]),
    .target(
      name: "flint-repl",
      dependencies: ["Commander", "Rainbow", "Symbolic", "Diagnostic", "REPL", "Utils"]),
    .target(
      name: "flint-debug",
      dependencies: ["Commander", "Debugger"]),
    .target(
        name: "flint-da",
        dependencies: ["Commander", "DebugAdapterProtocol", "Debugger", "Rainbow", "Source"]),
    .target(
      name: "Source",
      dependencies: ["Utils"]
    ),
    .testTarget(
      name: "SourceTests",
      dependencies: [
        "Source",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Source"]
    ),
    // MARK: Compiler -
    .target(
      name: "Compiler",
      dependencies: [
        "Parser",
        "Lexer",
        "ASTPreprocessor",
        "SemanticAnalyzer",
        "TypeChecker",
        "Optimizer",
        "IRGen",
        "MoveGen",
        "Verifier",
        "Commander",
        "Rainbow",
        "Symbolic",
        "Diagnostic",
        "Utils",
        "Source",
        "SourceMap",
      ]
    ),
    .testTarget(
      name: "CompilerTests",
      dependencies: [
        "Compiler",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Compiler"]
    ),
    // MARK: Diagnostic -
    .target(
      name: "Diagnostic",
      dependencies: [
        "Source",
        "Rainbow",
        "Utils",
      ]
    ),
    .testTarget(
      name: "DiagnosticTests",
      dependencies: [
        "Diagnostic",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Diagnostic"]
    ),
    // MARK: Debugger -
    .target(
      name: "Debugger",
      dependencies: [
        "Rainbow",
        "CryptoSwift",
        "Source",
        "SourceMap",
        "Utils",
        "Web3",
        "Web3PromiseKit",
        "Web3ContractABI",
      ]
    ),
    // MARK: SourceMap
    .target(
      name: "SourceMap",
      dependencies: [
        "AST",
        "Source",
        "Utils",
      ]
    ),
    // MARK: Lexer -
    .target(
      name: "Lexer",
      dependencies: [
        "Source",
        "Diagnostic",
      ]
    ),
    .testTarget(
      name: "LexerTests",
      dependencies: [
        "Lexer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Lexer"]
    ),
    // MARK: AST -
    .target(
      name: "AST",
      dependencies: [
        "Source",
        "Diagnostic",
        "Lexer",
        "ABI",
        "Utils",
      ],
      exclude: ["ASTPass/ASTPass.template.swift"]
    ),
    .testTarget(
      name: "ASTTests",
      dependencies: [
        "AST",
        "Cuckoo",
        "Utils",
      ],
      sources: [".", "../../.derived-tests/AST"]
    ),
    // MARK: Parser -
    .target(
      name: "Parser",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Lexer",
        "Utils",
      ]
    ),
    .testTarget(
      name: "ParserTests",
      dependencies: [
        "Parser",
        "Cuckoo",
        "Utils",
      ],
      sources: [".", "../../.derived-tests/Parser"]
    ),
    // MARK: SemanticAnalyzer -
    .target(
      name: "SemanticAnalyzer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Utils",
      ]
    ),
    .testTarget(
      name: "SemanticAnalyzerTests",
      dependencies: [
        "SemanticAnalyzer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/SemanticAnalyzer"]
    ),
    // MARK: ASTPreprocessor -
    .target(
      name: "ASTPreprocessor",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Utils",
      ]
    ),
    .testTarget(
      name: "ASTPreprocessorTests",
      dependencies: [
        "ASTPreprocessor",
        "Cuckoo",
        "Utils",
        ],
      sources: [".", "../../.derived-tests/ASTPreprocessor"]
    ),
    // MARK: TypeChecker -
    .target(
      name: "TypeChecker",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Utils",
      ]
    ),
    .testTarget(
      name: "TypeCheckerTests",
      dependencies: [
        "TypeChecker",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/TypeChecker"]
    ),
    // MARK: Optimizer -
    .target(
      name: "Verifier",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "Lexer",
        "Yaml",
        "BigInt",
      ]
    ),
    .target(
      name: "Optimizer",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
      ]
    ),
    .testTarget(
      name: "OptimizerTests",
      dependencies: [
        "Optimizer",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/Optimizer"]
    ),
    // MARK: IRGen -
    .target(
      name: "IRGen",
      dependencies: [
        "Source",
        "Diagnostic",
        "AST",
        "CryptoSwift",
        "YUL",
        "Utils",
      ]
    ),
    .testTarget(
      name: "IRGenTests",
      dependencies: [
        "IRGen",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/IRGen"]
    ),
    .target(
        name: "MoveGen",
        dependencies: [
          "Source",
          "Diagnostic",
          "AST",
          "CryptoSwift",
          "MoveIR",
          "Utils",
        ]
    ),
    // MARK: YUL -
    .target(
      name: "YUL",
      dependencies: [
        "Source",
        "Utils",
      ]
    ),
    .target(
      name: "MoveIR",
      dependencies: [
        "Utils",
      ]
    ),
    // MARK: ABI -
    .target(
      name: "ABI",
      dependencies: [
        "Source",
        "CryptoSwift",
      ]
    ),
    .testTarget(
      name: "ABITests",
      dependencies: [
        "ABI",
        "Cuckoo",
      ],
      sources: [".", "../../.derived-tests/ABI"]
    ),
    // MARK: Utils -
    .target(
      name: "Utils",
      dependencies: ["Symbolic"]
    ),
    .testTarget(
      name: "UtilsTests",
      dependencies: [
        "Utils",
        "Cuckoo"
      ],
      sources: [".", "../../.derived-tests/Utils"]
    ),
    // MARK: flintc -
    .target(
      name: "flintc",
      dependencies: [
        "Compiler",
      ]
    ),
    // MARK: lite -
    .target(
        name: "lite",
        dependencies: [
          "LiteSupport",
          "Rainbow",
          "Symbolic",
          "Utils"
      ]
    ),
    // MARK: file-check
    .target(
        name: "file-check",
        dependencies: ["FileCheck", "Commander"]),
    .target(
        name: "LSP",
        dependencies: ["Diagnostic", "AST"]),
    .target(
        name: "ContractAnalysis",
        dependencies: ["AST"]),
    .target(
        name: "JSTranslator",
        dependencies: ["AST", "Parser", "Lexer"]),
    .target(
        name: "REPL",
        dependencies: ["AST", "Parser", "Lexer", "Compiler", "Diagnostic", "JSTranslator", "SwiftyJSON", "Rainbow"]),
    .target(
        name: "Coverage",
        dependencies: ["AST", "Parser", "Lexer", "Compiler", "Diagnostic", "SwiftyJSON", "Rainbow"])
    ]
)
