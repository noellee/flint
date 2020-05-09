import Foundation
import Commander
import Debugger
import Web3
import Web3PromiseKit
import PromiseKit

func main() {
  command(
      Argument<String>("Transaction hash", description: "Hash of the transaction to be debugged"),
      Argument<String>("Contract name", description: "Name of the smart contract"),
      Option<String>("artifacts", default: "bin", description: "Directory containing Flint compiler artifacts"),
      Option<String>("rpc-url", default: "http://localhost:8545", description: "Ethereum client RPC URL")
  ) { txHash, contractName, artifactDirectory, rpcURL in

    do {
      let debugger = try DebuggerCLI(txHash: txHash,
                                     contractName: contractName,
                                     artifactDirectory: artifactDirectory,
                                     rpcURL: rpcURL)
      try debugger.run()
    } catch let err {
      print(err)
      exit(1)
    }

  }.run()
}

main()
