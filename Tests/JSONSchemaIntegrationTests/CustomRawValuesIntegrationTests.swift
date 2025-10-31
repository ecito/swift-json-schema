import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
enum OrderStatus: String {
  case active = "ACTIVE"
  case inactive = "INACTIVE"
  case pending = "PENDING"
}

@Schemable
enum TaskPriority: String {
  case low
  case medium = "MEDIUM"
  case high = "HIGH"
  case critical
}

@Schemable
enum HTTPMethod: String {
  case `get` = "GET"
  case `post` = "POST"
  case `delete`
  case patch = "PATCH"
}

struct CustomRawValuesIntegrationTests {
  @Test func statusCustomRawValues() throws {
    // Test parsing with custom raw values
    let activeJSON: JSONValue = "ACTIVE"
    let activeResult = OrderStatus.schema.parse(activeJSON)
    let activeStatus = try #require(activeResult.value)
    #expect(activeStatus == .active)

    let inactiveJSON: JSONValue = "INACTIVE"
    let inactiveResult = OrderStatus.schema.parse(inactiveJSON)
    let inactiveStatus = try #require(inactiveResult.value)
    #expect(inactiveStatus == .inactive)

    let pendingJSON: JSONValue = "PENDING"
    let pendingResult = OrderStatus.schema.parse(pendingJSON)
    let pendingStatus = try #require(pendingResult.value)
    #expect(pendingStatus == .pending)

    // Test that lowercase values don't match
    let lowercaseJSON: JSONValue = "active"
    let lowercaseResult = OrderStatus.schema.parse(lowercaseJSON)
    #expect(lowercaseResult.value == nil)
  }

  @Test func priorityMixedRawValues() throws {
    // Test parsing with mixed raw values (some custom, some default)
    let lowJSON: JSONValue = "low"
    let lowResult = TaskPriority.schema.parse(lowJSON)
    let lowPriority = try #require(lowResult.value)
    #expect(lowPriority == .low)

    let mediumJSON: JSONValue = "MEDIUM"
    let mediumResult = TaskPriority.schema.parse(mediumJSON)
    let mediumPriority = try #require(mediumResult.value)
    #expect(mediumPriority == .medium)

    let highJSON: JSONValue = "HIGH"
    let highResult = TaskPriority.schema.parse(highJSON)
    let highPriority = try #require(highResult.value)
    #expect(highPriority == .high)

    let criticalJSON: JSONValue = "critical"
    let criticalResult = TaskPriority.schema.parse(criticalJSON)
    let criticalPriority = try #require(criticalResult.value)
    #expect(criticalPriority == .critical)

    // Test that wrong case doesn't match for custom values
    let wrongCaseJSON: JSONValue = "medium"
    let wrongCaseResult = TaskPriority.schema.parse(wrongCaseJSON)
    #expect(wrongCaseResult.value == nil)
  }

  @Test func statusSchemaGeneration() throws {
    // Verify the schema contains the correct enum values
    let schemaValue = OrderStatus.schema.schemaValue
    guard case .object(let schemaDict) = schemaValue else {
      Issue.record("Expected schema to be an object")
      return
    }

    // Check that enum values are present
    if case .array(let enumValues) = schemaDict["enum"] {
      let stringValues = enumValues.compactMap { value -> String? in
        if case .string(let str) = value {
          return str
        }
        return nil
      }
      #expect(stringValues.contains("ACTIVE"))
      #expect(stringValues.contains("INACTIVE"))
      #expect(stringValues.contains("PENDING"))
      #expect(!stringValues.contains("active"))
      #expect(!stringValues.contains("inactive"))
      #expect(!stringValues.contains("pending"))
    }
  }

  @Test func backtickedEnumCasesWithCustomRawValues() throws {
    // Test that backticked enum cases work with custom raw values
    let getJSON: JSONValue = "GET"
    let getResult = HTTPMethod.schema.parse(getJSON)
    let getMethod = try #require(getResult.value)
    #expect(getMethod == .get)

    let postJSON: JSONValue = "POST"
    let postResult = HTTPMethod.schema.parse(postJSON)
    let postMethod = try #require(postResult.value)
    #expect(postMethod == .post)

    let patchJSON: JSONValue = "PATCH"
    let patchResult = HTTPMethod.schema.parse(patchJSON)
    let patchMethod = try #require(patchResult.value)
    #expect(patchMethod == .patch)
  }

  @Test func backtickedEnumCasesWithDefaultRawValues() throws {
    // Test that backticked enum cases work with default raw values (case name)
    let deleteJSON: JSONValue = "delete"
    let deleteResult = HTTPMethod.schema.parse(deleteJSON)
    let deleteMethod = try #require(deleteResult.value)
    #expect(deleteMethod == .delete)

    // Uppercase should not match for default raw values
    let uppercaseDeleteJSON: JSONValue = "DELETE"
    let uppercaseResult = HTTPMethod.schema.parse(uppercaseDeleteJSON)
    #expect(uppercaseResult.value == nil)
  }
}
