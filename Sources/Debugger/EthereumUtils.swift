import Foundation
import Web3
import Web3PromiseKit
import PromiseKit

class EthereumUtils {
  static func getTransaction(web3: Web3, txHash: EthereumData) throws -> EthereumTransactionTraceObject {
    return try firstly {
      web3.debug.traceTransaction(transactionHash: txHash)
    }.then(on: .global(qos: .userInteractive)) { txTrace -> Promise<EthereumTransactionTraceObject> in
      guard let trace = txTrace else {
        throw DebuggerError.invalidTransaction(txHash.hex())
      }
      return Promise.value(trace)
    }.wait()
  }

  static func getContractCode(web3: Web3, txHash: EthereumData) throws -> String {
    return try firstly {
      web3.eth.getTransactionByHash(blockHash: txHash)
    }.then(on: .global(qos: .userInteractive)) { transaction -> Promise<EthereumAddress> in
      guard let tx = transaction, let to = tx.to else {
        throw DebuggerError.invalidTransaction(txHash.hex())
      }
      return Promise.value(to)
    }.then(on: .global(qos: .userInteractive)) { address -> Promise<EthereumData> in
      web3.eth.getCode(address: address, block: .latest)
    }.wait().hex()
  }

  static func contractCodeEquivalent(_ code1: String, _ code2: String) -> Bool {
    var code1 = code1.dropHexPrefix()
    var code2 = code2.dropHexPrefix()
    if code1 == code2 {
      return true
    }
    code1 = code1.dropContractMetadata()
    code2 = code2.dropContractMetadata()
    return code1 == code2
  }

  static func getInstructionLength(instr: UInt8) -> UInt8 {
    if 0x60 <= instr && instr < 0x7f {
      return 1 + instr - 0x5f
    }
    return 1
  }
}

fileprivate extension String {
  func dropHexPrefix() -> String {
    return String(self.dropFirst(self.hasPrefix("0x") ? 2 : 0))
  }

  func dropContractMetadata() -> String {
    // https://solidity.readthedocs.io/en/v0.4.25/metadata.html#encoding-of-the-metadata-hash-in-the-bytecode
    // 0xa1 0x65 'b' 'z' 'z' 'r' '0' 0x58 0x20 <32 bytes swarm hash> 0x00 0x29
    // a1   65   62  7a  7a  72  30  58   20   ...                   00   29
    let regex = try! NSRegularExpression(pattern: "a165627a7a72305820[a-f0-9]{64}0029$", options: .caseInsensitive)
    let range = NSRange(self.startIndex..., in: self)
    return regex.stringByReplacingMatches(in: self, range: range, withTemplate: "")
  }
}
