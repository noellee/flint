import Foundation

public typealias CompilerArtifact = SolcArtifact

public struct SolcArtifact: Codable {
  public var contracts: [String: ContractInfo]
  public var sourceList: [String]
  public var version: String

  public static func from(file: URL) throws -> SolcArtifact {
    let fileContents = try String(contentsOf: file)
    return try from(string: fileContents)
  }

  public static func from(string: String) throws -> SolcArtifact {
    let decoder = JSONDecoder()
    let jsonData = string.data(using: .utf8)!
    return try decoder.decode(SolcArtifact.self, from: jsonData)
  }

  public func to(file: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(self)
    try data.write(to: file)
  }
}

public struct StorageVariable: Codable {
  public var name: String
  public var size: Int?  // non-nil if variable is fixed size array
}

public struct ContractMetadata: Codable {
  public var storage: [StorageVariable]
  public var typeStates: [String]
}

public struct ContractInfo: Codable {
  public var binRuntime: String
  public var srcMapRuntime: SourceMap
  public var bin: String
  public var srcMap: SourceMap
  public var metadata: ContractMetadata?

  private enum CodingKeys: String, CodingKey {
    case binRuntime = "bin-runtime"
    case srcMapRuntime = "srcmap-runtime"
    case bin = "bin"
    case srcMap = "srcmap"
    case metadata = "metadata"
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    binRuntime = try values.decode(String.self, forKey: .binRuntime)
    bin = try values.decode(String.self, forKey: .bin)
    srcMapRuntime = SourceMap.decompress(try values.decode(String.self, forKey: .srcMapRuntime))
    srcMap = SourceMap.decompress(try values.decode(String.self, forKey: .srcMap))
    metadata = try values.decodeIfPresent(ContractMetadata.self, forKey: .metadata)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(binRuntime, forKey: .binRuntime)
    try container.encode(bin, forKey: .bin)
    try container.encode(srcMapRuntime.compress(), forKey: .srcMapRuntime)
    try container.encode(srcMap.compress(), forKey: .srcMap)
    try container.encodeIfPresent(metadata, forKey: .metadata)
  }
}
