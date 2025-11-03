import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

// Custom type with custom Codable encoding
// NOTE: Don't use @Schemable on types with custom Codable implementations!
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

// ✅ Manually define the schema to match the custom encoding
extension IntRange: Schemable {
  static var schema: some JSONSchemaComponent<IntRange> {
    JSONArray {
      JSONInteger()
    }
    .minItems(2)
    .maxItems(2)
    .description("An IntRange encoded as [lowerBound, upperBound]")
    .compactMap { array -> IntRange? in
      guard array.count == 2, array[0] < array[1] else { return nil }
      return IntRange(lowerBound: array[0], upperBound: array[1])
    }
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
    // The manually defined schema now matches the actual encoding
    let schemaValue = Config.schema.schemaValue
    print("Config schema: \(schemaValue)")

    // Verify IntRange schema is an array
    guard case .object(let configDict) = schemaValue,
      case .object(let properties) = configDict["properties"],
      case .object(let rangeSchema) = properties["failedRequestStatusCodes"]
    else {
      Issue.record("Unexpected schema structure")
      return
    }

    #expect(rangeSchema["type"] == .string("array"))
    #expect(rangeSchema["minItems"] == .integer(2))
    #expect(rangeSchema["maxItems"] == .integer(2))
  }

  @Test func customCodableParsing() throws {
    // Now parsing works because our manual schema matches the encoding!
    let json: JSONValue = [
      "failedRequestStatusCodes": [500, 599],
    ]

    let result = Config.schema.parse(json)
    print("Parse result: \(result)")

    // This now works! ✅
    let config = try #require(result.value)
    #expect(config.failedRequestStatusCodes == IntRange(lowerBound: 500, upperBound: 599))
    #expect(config.failedRequestStatusCodes.lowerBound == 500)
    #expect(config.failedRequestStatusCodes.upperBound == 599)
  }

  @Test func usingBuiltInRangeConversion() throws {
    // Even better: Use the built-in RangeConversion for Range<Int>
    struct ConfigWithRange: Codable {
      let statusCodes: Range<Int>
    }

    // Manually define schema using RangeConversion
    @JSONSchemaBuilder var configSchema: some JSONSchemaComponent<ConfigWithRange> {
      JSONSchema(ConfigWithRange.init) {
        JSONObject {
          JSONProperty(key: "statusCodes") {
            RangeConversion.schema
          }
          .required()
        }
      }
    }

    // Test encoding
    let config = ConfigWithRange(statusCodes: 400..<500)
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    let jsonString = String(data: data, encoding: .utf8)!
    print("Encoded with Range<Int>: \(jsonString)")
    #expect(jsonString.contains("[400,500]"))

    // Test parsing
    let json: JSONValue = ["statusCodes": [400, 500]]
    let result = configSchema.parse(json)
    let parsed = try #require(result.value)
    #expect(parsed.statusCodes == 400..<500)
  }
}
