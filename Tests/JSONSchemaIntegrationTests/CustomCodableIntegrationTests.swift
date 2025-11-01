import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

// Custom type with custom Codable encoding
@Schemable
struct IntRange: Codable, Equatable {
  let lowerBound: Int
  let upperBound: Int

  // Custom encoding - encodes as a 2-element array [lowerBound, upperBound]
  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(lowerBound)
    try container.encode(upperBound)
  }

  init(from decoder: Decoder) throws {
    var container = try decoder.unkeyedContainer()
    lowerBound = try container.decode(Int.self)
    upperBound = try container.decode(Int.self)
  }

  init(lowerBound: Int, upperBound: Int) {
    self.lowerBound = lowerBound
    self.upperBound = upperBound
  }
}

@Schemable
struct Config: Codable {
  let failedRequestStatusCodes: IntRange
}

struct CustomCodableIntegrationTests {
  @Test func customCodableEncoding() throws {
    // Test how custom Codable types are actually encoded
    let config = Config(failedRequestStatusCodes: IntRange(lowerBound: 500, upperBound: 599))

    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    let jsonString = String(data: data, encoding: .utf8)!
    print("Encoded JSON: \(jsonString)")

    // IntRange encodes as [500, 599]
    #expect(jsonString.contains("[500,599]"))
  }

  @Test func customCodableSchemaExpectation() throws {
    // The current schema will expect an object with lowerBound/upperBound
    // But the actual encoding is an array
    let schemaValue = Config.schema.schemaValue
    print("Config schema: \(schemaValue)")

    // The schema currently expects: {"lowerBound": 500, "upperBound": 599}
    // But actual encoding is: [500, 599]
  }

  @Test func customCodableParsing() throws {
    // Try parsing with the array format that Codable actually uses
    let json: JSONValue = [
      "failedRequestStatusCodes": [500, 599],
    ]

    let result = Config.schema.parse(json)
    print("Parse result: \(result)")

    // This will likely fail because schema expects object, not array
    if let config = result.value {
      #expect(config.failedRequestStatusCodes == IntRange(lowerBound: 500, upperBound: 599))
    } else {
      Issue.record("Failed to parse - schema expects object but encoding is array")
    }
  }
}
