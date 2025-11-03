import Foundation
import JSONSchema
import JSONSchemaBuilder
import JSONSchemaConversion
import Testing

struct RangeConversionTests {
  @Test func rangeSchemaFormat() {
    let schema = RangeConversion.schema

    // Verify the schema expects an array
    let schemaValue = schema.schemaValue
    print("Range schema: \(schemaValue)")

    guard case .object(let schemaDict) = schemaValue else {
      Issue.record("Expected schema to be an object")
      return
    }

    // Should have type: array
    #expect(schemaDict["type"] == .string("array"))
  }

  @Test func parseValidRange() throws {
    let schema = RangeConversion.schema

    // Test parsing a valid range [0, 10]
    let json: JSONValue = [0, 10]
    let result = schema.parse(json)

    let range = try #require(result.value)
    #expect(range == 0..<10)
    #expect(range.lowerBound == 0)
    #expect(range.upperBound == 10)
  }

  @Test func parseAnotherValidRange() throws {
    let schema = RangeConversion.schema

    // Test parsing [500, 599]
    let json: JSONValue = [500, 599]
    let result = schema.parse(json)

    let range = try #require(result.value)
    #expect(range == 500..<599)
  }

  @Test func rejectInvalidRanges() {
    let schema = RangeConversion.schema

    // Wrong number of elements
    let tooFew: JSONValue = [5]
    #expect(schema.parse(tooFew).value == nil)

    let tooMany: JSONValue = [1, 2, 3]
    #expect(schema.parse(tooMany).value == nil)

    // Lower bound >= upper bound
    let invalid: JSONValue = [10, 5]
    #expect(schema.parse(invalid).value == nil)

    let equal: JSONValue = [5, 5]
    #expect(schema.parse(equal).value == nil)

    // Wrong types
    let wrongType: JSONValue = ["a", "b"]
    #expect(schema.parse(wrongType).value == nil)
  }

  @Test func integrationWithCodable() throws {
    // Test that it works with actual Codable encoding
    struct Config: Codable {
      let statusCodeRange: Range<Int>
    }

    // Manually create schema using RangeConversion
    @JSONSchemaBuilder var configSchema: some JSONSchemaComponent<Config> {
      JSONSchema(Config.init) {
        JSONObject {
          JSONProperty(key: "statusCodeRange") {
            RangeConversion.schema
          }
          .required()
        }
      }
    }

    // Test encoding
    let config = Config(statusCodeRange: 500..<600)
    let encoder = JSONEncoder()
    let data = try encoder.encode(config)
    let jsonString = String(data: data, encoding: .utf8)!
    print("Encoded: \(jsonString)")
    #expect(jsonString.contains("[500,600]"))

    // Test parsing with our schema
    let json: JSONValue = ["statusCodeRange": [500, 600]]
    let result = configSchema.parse(json)
    let parsed = try #require(result.value)
    #expect(parsed.statusCodeRange == 500..<600)
  }
}
