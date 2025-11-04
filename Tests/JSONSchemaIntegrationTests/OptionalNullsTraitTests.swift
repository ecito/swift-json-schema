import InlineSnapshotTesting
import JSONSchema
import JSONSchemaBuilder
import Testing

// MARK: - Trait-based OptionalNulls Tests
//
// These tests verify the OptionalNulls trait behavior. The trait is defined in Package@swift-6.0.swift
// and can be enabled by client packages when adding JSONSchemaBuilder as a dependency.
//
// To test with the trait enabled, modify Package@swift-6.0.swift to include:
//   traits: [
//     .default(enabledTraits: ["OptionalNulls"])
//   ]
//
// When the OptionalNulls trait is enabled:
// - All @Schemable types will have optionalNulls: true by default
// - Optional properties will automatically accept explicit null values using appropriate style
// - Scalar primitives (Int?, String?, etc.) use .type style: ["integer", "null"]
// - Complex types ([T]?, [K:V]?) use .union style with oneOf composition
//
// The trait can be overridden per-type with explicit optionalNulls parameter.

#if OptionalNulls

// When the trait is enabled, this struct should automatically accept nulls for optional properties
@Schemable
struct TraitEnabledUser {
  let name: String
  let age: Int?
  let email: String?
}

@Schemable
struct TraitEnabledProduct {
  let id: Int
  let tags: [String]?
  let metadata: [String: String]?
}

// Explicit override to disable even when trait is active
@Schemable(optionalNulls: false)
struct TraitOverriddenUser {
  let name: String
  let age: Int?
}

struct OptionalNullsTraitEnabledTests {
  @Test(.snapshots(record: false)) func traitEnabledScalarOptionals() {
    let schema = TraitEnabledUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "age" : {
            "type" : [
              "integer",
              "null"
            ]
          },
          "email" : {
            "type" : [
              "string",
              "null"
            ]
          },
          "name" : {
            "type" : "string"
          }
        },
        "required" : [
          "name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func traitEnabledComplexOptionals() {
    let schema = TraitEnabledProduct.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "id" : {
            "type" : "integer"
          },
          "metadata" : {
            "oneOf" : [
              {
                "additionalProperties" : {
                  "type" : "string"
                },
                "type" : "object"
              },
              {
                "type" : "null"
              }
            ]
          },
          "tags" : {
            "oneOf" : [
              {
                "items" : {
                  "type" : "string"
                },
                "type" : "array"
              },
              {
                "type" : "null"
              }
            ]
          }
        },
        "required" : [
          "id"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func traitExplicitOverride() {
    let schema = TraitOverriddenUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "age" : {
            "type" : "integer"
          },
          "name" : {
            "type" : "string"
          }
        },
        "required" : [
          "name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test func traitEnabledParsingNull() {
    let result = TraitEnabledUser.schema.parse([
      "name": .string("Alice"),
      "age": .null,
      "email": .null,
    ])

    #expect(result.value?.name == "Alice")
    #expect(result.value?.age == nil)
    #expect(result.value?.email == nil)
    #expect(result.errors == nil)
  }

  @Test func traitEnabledParsingMissing() {
    let result = TraitEnabledUser.schema.parse([
      "name": .string("Bob")
    ])

    #expect(result.value?.name == "Bob")
    #expect(result.value?.age == nil)
    #expect(result.value?.email == nil)
    #expect(result.errors == nil)
  }

  @Test func traitOverriddenRejectsNull() {
    let result = TraitOverriddenUser.schema.parse([
      "name": .string("Charlie"),
      "age": .null,
    ])

    // Should reject null when trait is explicitly overridden
    #expect(result.value == nil)
    #expect(result.errors != nil)
  }
}

#else

// When the trait is NOT enabled, @Schemable without explicit optionalNulls parameter
// will NOT accept null for optional properties
@Schemable
struct TraitDisabledUser {
  let name: String
  let age: Int?
  let email: String?
}

struct OptionalNullsTraitDisabledTests {
  @Test(.snapshots(record: false)) func traitDisabledOptionals() {
    let schema = TraitDisabledUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "age" : {
            "type" : "integer"
          },
          "email" : {
            "type" : "string"
          },
          "name" : {
            "type" : "string"
          }
        },
        "required" : [
          "name"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test func traitDisabledRejectsNull() {
    let result = TraitDisabledUser.schema.parse([
      "name": .string("Alice"),
      "age": .null,
    ])

    // Should reject null when trait is not enabled
    #expect(result.value == nil)
    #expect(result.errors != nil)
  }

  @Test func traitDisabledAcceptsMissing() {
    let result = TraitDisabledUser.schema.parse([
      "name": .string("Bob")
    ])

    #expect(result.value?.name == "Bob")
    #expect(result.value?.age == nil)
    #expect(result.errors == nil)
  }
}

#endif
