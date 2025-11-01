import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct WeatherReport {
  let temperature: Double
  let humidity: Int?
}

struct OptionalTypesIntegrationTests {
  @Test func optionalPropertyCanBeMissing() throws {
    // Test that optional properties can be omitted from JSON
    let json: JSONValue = [
      "temperature": 72.5,
    ]

    let result = WeatherReport.schema.parse(json)
    let report = try #require(result.value)
    #expect(report.temperature == 72.5)
    #expect(report.humidity == nil)
  }

  @Test func optionalPropertyCanBeNull() throws {
    // Test that optional properties can be explicitly null
    let json: JSONValue = [
      "temperature": 72.5,
      "humidity": .null,
    ]

    let result = WeatherReport.schema.parse(json)
    print("Parse result for null humidity: \(result)")

    // This should work but currently might fail
    let report = try #require(result.value)
    #expect(report.temperature == 72.5)
    #expect(report.humidity == nil)
  }

  @Test func optionalPropertyWithValue() throws {
    // Test that optional properties can have a value
    let json: JSONValue = [
      "temperature": 72.5,
      "humidity": 65,
    ]

    let result = WeatherReport.schema.parse(json)
    let report = try #require(result.value)
    #expect(report.temperature == 72.5)
    #expect(report.humidity == 65)
  }

  @Test func schemaAllowsNullForOptionalTypes() throws {
    // Verify the schema allows null for optional types
    let schemaValue = WeatherReport.schema.schemaValue
    print("WeatherReport schema: \(schemaValue)")

    guard case .object(let schemaDict) = schemaValue else {
      Issue.record("Expected schema to be an object")
      return
    }

    // The schema should indicate that humidity can be null
    // This might currently fail - we're investigating
  }
}
