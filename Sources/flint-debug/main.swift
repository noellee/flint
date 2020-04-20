import Foundation
import Commander
import Debugger
import Web3
import Web3PromiseKit
import PromiseKit

func main() {
  command(
      Argument<String>("Transaction hash", description: "Hash of the transaction to be debugged")
  ) { txHash in

    let debugger = Debugger(txHash: txHash)

    do {
      try debugger.run()
    } catch let err {
      print(err)
      exit(1)
    }

  }.run()
}

main()
