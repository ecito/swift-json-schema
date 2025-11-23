import Foundation
import JSONSchema
import JSONSchemaBuilder
import Testing

@Schemable
struct Address: Sendable {
    let street: String
    let city: String
}

@Schemable
struct Person: Sendable {
    let homeAddress: Address
    let workAddress: Address
    let billingAddress: Address
}

@Schemable
struct SingleAddress: Sendable {
  let address: Address
}

@Schemable
struct Contact: Sendable {
  let email: String
  let phone: String
}

@Schemable
struct Company: Sendable {
  let primaryContact: Contact
  let secondaryContact: Contact
  let billingContact: Contact
  let address: Address
  let mailingAddress: Address
}

struct MultiplePropertiesTests {
  @Test func multiplePropertiesOfSameType() throws {
    // Generate the schema
    let schema = Person.schema.definition()

    // Verify the schema has $defs with the deduplicated Address schema
    let encoder = JSONEncoder()
    let data = try encoder.encode(schema)
    let json = try JSONDecoder().decode(JSONValue.self, from: data)

    guard case .object(let dict) = json,
          case .object(let defs) = dict[Keywords.Defs.name] else {
      Issue.record("Expected $defs to be created")
      return
    }

    // Should have one schema definition for Address
    #expect(defs.count == 1)

    // Verify the def is named "Address" not "Schema0"
    #expect(defs["Address"] != nil)

    // Verify all properties use $ref
    guard case .object(let props) = dict[Keywords.Properties.name] else {
      Issue.record("Expected properties")
      return
    }
    for (propName, propValue) in props {
      guard case .object(let propDict) = propValue else {
        Issue.record("Expected property to be an object")
        continue
      }
      // Each property should have a $ref
      #expect(propDict[Keywords.Reference.name] != nil, "Property \(propName) should use $ref")
    }

    // Verify that the schema validates correctly
    let validJson = """
      {
        "homeAddress": {"street": "123 Main St", "city": "Springfield"},
        "workAddress": {"street": "456 Business Ave", "city": "Metropolis"},
        "billingAddress": {"street": "789 Invoice Ln", "city": "Capital City"}
      }
      """
    let result = try Person.schema.parse(instance: validJson)
    #expect(result.value != nil)
    #expect(result.errors == nil)
  }

  @Test func deduplicationCanBeDisabled() throws {
    // Test that deduplication can be turned off
    let schemaWithoutDedupe = Person.schema.definition(deduplicate: false)
    let encoder = JSONEncoder()
    let data = try encoder.encode(schemaWithoutDedupe)
    let json = try JSONDecoder().decode(JSONValue.self, from: data)

    // Without deduplication, there should be no $defs
    guard case .object(let dict) = json else {
      Issue.record("Expected object schema")
      return
    }
    #expect(dict[Keywords.Defs.name] == nil)

    // Each property should have the full schema inlined
    guard case .object(let props) = dict[Keywords.Properties.name] else {
      Issue.record("Expected properties")
      return
    }

    // Check that homeAddress has full schema (not a $ref)
    guard case .object(let homeAddr) = props["homeAddress"] else {
      Issue.record("Expected homeAddress object")
      return
    }
    #expect(homeAddr[Keywords.Reference.name] == nil)
    #expect(homeAddr[Keywords.Properties.name] != nil)
  }

  @Test func singlePropertyNotDeduplicated() throws {
    // A type with only one usage should not be extracted to $defs
    let schema = SingleAddress.schema.definition()
    let encoder = JSONEncoder()
    let data = try encoder.encode(schema)
    let json = try JSONDecoder().decode(JSONValue.self, from: data)

    // No $defs should be created for single usage
    guard case .object(let dict) = json else {
      Issue.record("Expected object schema")
      return
    }
    #expect(dict[Keywords.Defs.name] == nil)
  }

  @Test func nestedDeduplication() throws {
    // Test deduplication with more complex nesting
    let schema = Company.schema.definition()
    let encoder = JSONEncoder()
    let data = try encoder.encode(schema)
    let json = try JSONDecoder().decode(JSONValue.self, from: data)

    // Should have $defs for both Contact (3 uses) and Address (2 uses)
    guard case .object(let dict) = json,
          case .object(let defs) = dict[Keywords.Defs.name] else {
      Issue.record("Expected $defs")
      return
    }

    // Should have extracted 2 schemas
    #expect(defs.count == 2)

    // Verify validation still works
    let validJson = """
      {
        "primaryContact": {"email": "primary@example.com", "phone": "111-1111"},
        "secondaryContact": {"email": "secondary@example.com", "phone": "222-2222"},
        "billingContact": {"email": "billing@example.com", "phone": "333-3333"},
        "address": {"street": "123 Main St", "city": "Springfield"},
        "mailingAddress": {"street": "456 PO Box", "city": "Shelbyville"}
      }
      """
    let result = try Company.schema.parse(instance: validJson)
    #expect(result.value != nil)
    #expect(result.errors == nil)
  }
}
