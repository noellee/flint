import Foundation
import Commander
import Debugger
import Web3
import Web3PromiseKit
import PromiseKit

func main() {
  command(
      Argument<String>("Transaction hash", description: "Hash of the transaction to be debugged"),
      Argument<String>("Contract name", description: "Name of the smart contract")
  ) { txHash, contractName in

    let debugger = Debugger(txHash: txHash, contractName: contractName)

    do {
      try debugger.run()
    } catch let err {
      print(err)
      exit(1)
    }

  }.run()
}

main()
