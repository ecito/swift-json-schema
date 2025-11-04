import InlineSnapshotTesting
import JSONSchemaBuilder
import Testing

// MARK: - Trait-based Key Encoding Tests
//
// These tests verify the SnakeCase and KebabCase trait behavior. The traits are defined in
// Package@swift-6.1.swift and can be enabled by client packages when adding JSONSchemaBuilder
// as a dependency.
//
// To test with a trait enabled, modify Package@swift-6.1.swift to include:
//   traits: [
//     .default(enabledTraits: ["SnakeCase"])  // or ["KebabCase"]
//   ]
//
// When a key encoding trait is enabled:
// - All @Schemable types will use that encoding strategy by default
// - Explicit keyStrategy parameter on @Schemable overrides the trait
//
// IMPORTANT: SnakeCase and KebabCase are mutually exclusive. Enabling both traits
// simultaneously will result in a compile-time error.

#if SnakeCase

// When the SnakeCase trait is enabled, all @Schemable types use snake_case by default
@Schemable
struct TraitSnakeCaseUser {
  let firstName: String
  let lastName: String
  let emailAddress: String
}

// Explicit override still works
@Schemable(keyStrategy: .kebabCase)
struct TraitSnakeCaseOverriddenUser {
  let firstName: String
  let lastName: String
}

struct KeyEncodingSnakeCaseTraitTests {
  @Test(.snapshots(record: false)) func traitSnakeCaseDefault() {
    let schema = TraitSnakeCaseUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "email_address" : {
            "type" : "string"
          },
          "first_name" : {
            "type" : "string"
          },
          "last_name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first_name",
          "last_name",
          "email_address"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func traitSnakeCaseExplicitOverride() {
    let schema = TraitSnakeCaseOverriddenUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "first-name" : {
            "type" : "string"
          },
          "last-name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first-name",
          "last-name"
        ],
        "type" : "object"
      }
      """#
    }
  }
}

#elseif KebabCase

// When the KebabCase trait is enabled, all @Schemable types use kebab-case by default
@Schemable
struct TraitKebabCaseUser {
  let firstName: String
  let lastName: String
  let emailAddress: String
}

// Explicit override still works
@Schemable(keyStrategy: .snakeCase)
struct TraitKebabCaseOverriddenUser {
  let firstName: String
  let lastName: String
}

struct KeyEncodingKebabCaseTraitTests {
  @Test(.snapshots(record: false)) func traitKebabCaseDefault() {
    let schema = TraitKebabCaseUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "email-address" : {
            "type" : "string"
          },
          "first-name" : {
            "type" : "string"
          },
          "last-name" : {
            "type" : "string"
          }
        },
        "required" : [
          "first-name",
          "last-name",
          "email-address"
        ],
        "type" : "object"
      }
      """#
    }
  }

  @Test(.snapshots(record: false)) func traitKebabCaseExplicitOverride() {
    let schema = TraitKebabCaseOverriddenUser.schema.schemaValue
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
}

#else

// When neither trait is enabled, @Schemable uses identity (camelCase) by default
@Schemable
struct KeyEncodingTraitDisabledUser {
  let firstName: String
  let lastName: String
  let emailAddress: String
}

struct KeyEncodingTraitDisabledTests {
  @Test(.snapshots(record: false)) func traitDisabledIdentity() {
    let schema = KeyEncodingTraitDisabledUser.schema.schemaValue
    assertInlineSnapshot(of: schema, as: .json) {
      #"""
      {
        "properties" : {
          "emailAddress" : {
            "type" : "string"
          },
          "firstName" : {
            "type" : "string"
          },
          "lastName" : {
            "type" : "string"
          }
        },
        "required" : [
          "firstName",
          "lastName",
          "emailAddress"
        ],
        "type" : "object"
      }
      """#
    }
  }
}

#endif
