import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
enum CancellationReason: Int, Codable {
  case dontListen = 0
  case expensive = 1
  case other = 2
}

@Schemable
struct CancellationConfig: Codable {
  let reasonMessages: [CancellationReason: String]
}

struct IntEnumKeysIntegrationTests {
  @Test func intEnumDictionaryKeyEncoding() throws {
    // Test how Codable actually encodes Int-backed enum dictionary keys
    let config = CancellationConfig(reasonMessages: [
      .dontListen: "User doesn't want to listen",
      .expensive: "Too expensive",
    ])

    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    let jsonString = String(data: data, encoding: .utf8)!
    print("Encoded JSON: \(jsonString)")

    // Swift Codable encodes Int enum dictionary keys as INTEGERS in an array format
    // [key1, value1, key2, value2, ...]
    #expect(jsonString.contains("[0,") || jsonString.contains(",0,"))
  }

  @Test func intEnumDictionaryKeyParsing() throws {
    // The schema should expect the array-based encoding that Codable uses
    // Codable encodes dictionaries with non-String keys as: [key1, val1, key2, val2, ...]
    let json: JSONValue = [
      "reasonMessages": [0, "User doesn't want to listen", 1, "Too expensive"],
    ]

    let result = CancellationConfig.schema.parse(json)
    print("Parse result: \(result)")

    // This should work but currently fails because schema expects object, not array
    let config = try #require(result.value)
    #expect(config.reasonMessages[.dontListen] == "User doesn't want to listen")
    #expect(config.reasonMessages[.expensive] == "Too expensive")
  }

  @Test func schemaUsesRawValuesForIntEnumKeys() throws {
    // Verify the schema uses raw values for Int enum keys
    let schemaValue = CancellationConfig.schema.schemaValue
    print("CancellationConfig schema: \(schemaValue)")

    // The schema should use propertyNames with raw values
  }
}
