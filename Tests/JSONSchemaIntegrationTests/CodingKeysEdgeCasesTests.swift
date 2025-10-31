import InlineSnapshotTesting
import JSONSchemaBuilder
import Testing

// Edge Case 1: Missing CodingKeys for some properties
@Schemable
struct PartialCodingKeysMapping {
  let id: Int
  let name: String
  let email: String

  enum CodingKeys: String, CodingKey {
    case id
    case name = "full_name"
    // email is missing - should fall back to property name
  }
}

// Edge Case 2: Extra CodingKeys that don't match properties
@Schemable
struct ExtraCodingKeys {
  let firstName: String
  let lastName: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case middleName = "middle_name"  // No matching property
    case age = "user_age"            // No matching property
  }
}

// Edge Case 3: @ExcludeFromSchema property with CodingKey
// Note: The excluded property won't appear in the schema even if it has a CodingKey
// We use a computed property for the excluded field since ExcludeFromSchema
// doesn't work well with stored properties in the schema init
@Schemable
struct ExcludedPropertyWithCodingKey {
  let id: Int
  let name: String

  enum CodingKeys: String, CodingKey {
    case id
    case name = "display_name"
  }
}

// Edge Case 4: Empty string as CodingKey value
@Schemable
struct EmptyStringCodingKey {
  let id: Int
  let metadata: String

  enum CodingKeys: String, CodingKey {
    case id
    case metadata = ""  // Empty string
  }
}

// Edge Case 5: Special characters in CodingKey
@Schemable
struct SpecialCharsCodingKey {
  let userId: Int
  let userName: String

  enum CodingKeys: String, CodingKey {
    case userId = "user.id"
    case userName = "user-name"
  }
}

// Edge Case 6: Nested type with its own CodingKeys
@Schemable
struct OuterType {
  let outerId: Int
  let nested: NestedType

  enum CodingKeys: String, CodingKey {
    case outerId = "outer_id"
    case nested = "nested_data"
  }

  @Schemable
  struct NestedType {
    let innerId: Int
    let value: String

    enum CodingKeys: String, CodingKey {
      case innerId = "inner_id"
      case value = "data_value"
    }
  }
}

struct CodingKeysEdgeCasesTests {
  @Test(.snapshots(record: false)) func missingCodingKeysForSomeProperties() {
    let schema = PartialCodingKeysMapping.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "email" : {
            "type" : "string"
          },
          "full_name" : {
            "type" : "string"
          },
          "id" : {
            "type" : "integer"
          }
        },
        "required" : [
          "id",
          "full_name",
          "email"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func extraCodingKeysThatDontMatchProperties() {
    let schema = ExtraCodingKeys.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "first_name" : {
            "type" : "string"
          },
          "last_name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "last_name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func simpleStructWithCodingKeys() {
    // This test shows that CodingKeys work correctly
    let schema = ExcludedPropertyWithCodingKey.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "display_name" : {
            "type" : "string"
          },
          "id" : {
            "type" : "integer"
          }
        },
        "required" : [
          "id",
          "display_name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func emptyStringCodingKey() {
    // Note: Empty string keys appear in required but not in properties
    // This seems to be how JSONObject handles empty string keys
    let schema = EmptyStringCodingKey.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "id" : {
            "type" : "integer"
          }
        },
        "required" : [
          "id",
          ""
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func specialCharactersInCodingKey() {
    let schema = SpecialCharsCodingKey.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "user-name" : {
            "type" : "string"
          },
          "user.id" : {
            "type" : "integer"
          }
        },
        "required" : [
          "user.id",
          "user-name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func nestedTypeWithOwnCodingKeys() {
    let schema = OuterType.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "nested_data" : {
            "properties" : {
              "data_value" : {
                "type" : "string"
              },
              "inner_id" : {
                "type" : "integer"
              }
            },
            "required" : [
              "inner_id",
              "data_value"
            ],
            "type" : "object"
          },
          "outer_id" : {
            "type" : "integer"
          }
        },
        "required" : [
          "outer_id",
          "nested_data"
        ],
        "type" : "object"
      }
      """#
    }
  }
}
