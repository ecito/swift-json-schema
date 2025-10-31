# CodingKeys Support in @Schemable Macro

## Overview

The `@Schemable` macro now supports custom `CodingKeys` enums, allowing you to define custom JSON property names that will be automatically respected in the generated JSON schema.

## Features

### 1. Basic CodingKeys Support

When you define a `CodingKeys` enum with custom string raw values, the macro will use those values as the JSON property names in the generated schema:

```swift
@Schemable
struct User {
  let firstName: String
  let lastName: String
  let emailAddress: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case emailAddress = "email"
  }
}
```

**Generated schema properties:** `"first_name"`, `"last_name"`, `"email"`

### 2. Partial CodingKeys

You can omit raw values for some cases, and they will use the case name as-is:

```swift
@Schemable
struct Product {
  let name: String
  let productId: Int
  let price: Double

  enum CodingKeys: String, CodingKey {
    case name                      // Uses "name"
    case productId = "product_id"  // Uses "product_id"
    case price = "unit_price"      // Uses "unit_price"
  }
}
```

**Generated schema properties:** `"name"`, `"product_id"`, `"unit_price"`

### 3. Priority Order

The macro respects the following priority order for determining property keys:

1. **@SchemaOptions(.key(...))** - Highest priority (explicit override)
2. **CodingKeys enum** - Second priority (custom coding keys)
3. **keyStrategy parameter** - Third priority (type-wide strategy)
4. **Property name** - Default (no transformation)

#### Example with Override:

```swift
@Schemable
struct Customer {
  let firstName: String
  @SchemaOptions(.key("family_name"))  // Takes priority over CodingKeys
  let lastName: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"  // Will be overridden
  }
}
```

**Generated schema properties:** `"first_name"`, `"family_name"` (not `"last_name"`)

#### Example with keyStrategy:

```swift
@Schemable(keyStrategy: .snakeCase)
struct Employee {
  let firstName: String      // Uses CodingKeys value
  let middleName: String     // Uses CodingKeys value
  let lastName: String       // Uses CodingKeys value

  enum CodingKeys: String, CodingKey {
    case firstName = "given_name"  // Takes priority over keyStrategy
    case middleName                // No raw value, uses "middleName"
    case lastName = "family_name"  // Takes priority over keyStrategy
  }
}
```

**Generated schema properties:** `"given_name"`, `"middleName"`, `"family_name"`

Note: Even though `keyStrategy: .snakeCase` is specified, the `CodingKeys` values take priority. If `firstName` didn't have a CodingKeys entry, it would be transformed to `"first_name"` by the snake_case strategy.

## Implementation Details

The macro uses the `extractCodingKeys()` method to scan the member block for an enum named `CodingKeys` and extracts the mapping from case names to raw string values. This mapping is then passed to the schema generator, which uses it when determining property keys.

### How it Works:

1. The macro scans the struct/class members for an enum named "CodingKeys"
2. For each case in the CodingKeys enum:
   - If a raw value exists, it uses that string
   - If no raw value exists, it uses the case name
3. During schema generation, the macro checks this mapping before falling back to keyStrategy or the property name

## Testing

The feature is thoroughly tested with:

- **Integration Tests**: `Tests/JSONSchemaIntegrationTests/CodingKeysIntegrationTests.swift`
  - Basic CodingKeys usage
  - Partial CodingKeys (some with, some without raw values)
  - CodingKeys with @SchemaOptions override

- **Macro Expansion Tests**: `Tests/JSONSchemaMacroTests/SchemableExpansionTests.swift`
  - `customCodingKeys()` - Tests basic CodingKeys for struct and class
  - `customCodingKeysWithSchemaOptionsOverride()` - Tests priority of @SchemaOptions
  - `customCodingKeysWithKeyStrategy()` - Tests interaction with keyStrategy

## Example

See `Examples/CodingKeysExample.swift` for comprehensive examples of all supported patterns.

## Compatibility

- Works with both `struct` and `class` types
- Compatible with existing `@SchemaOptions`, `keyStrategy`, and other macro features
- No breaking changes to existing code
