# Custom Codable Encoding Investigation

## Problem Statement

Types with custom `Codable` implementations have a schema generated from their stored properties, which doesn't match their actual JSON encoding/decoding behavior.

## Example

```swift
@Schemable
struct IntRange: Codable {
  let lowerBound: Int
  let upperBound: Int

  // Custom encoding - encodes as [lowerBound, upperBound]
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
}
```

**Actual encoding:**
```json
[500, 599]
```

**Generated schema expects:**
```json
{
  "lowerBound": 500,
  "upperBound": 599
}
```

## Root Cause

The `@Schemable` macro generates schemas by inspecting:
1. Stored properties of the struct
2. Their types
3. CodingKeys (if present)

It has **no way** to detect or analyze custom `encode(to:)` / `init(from:)` implementations.

## Possible Solutions

### Option 1: Manual Schema Specification
Exclude the type from `@Schemable` and manually define its schema:

```swift
struct IntRange: Codable {
  // ... custom Codable implementation ...
}

extension IntRange: Schemable {
  static var schema: some JSONSchemaComponent<IntRange> {
    JSONArray()
      .prefixItems {
        JSONInteger() // lowerBound
        JSONInteger() // upperBound
      }
      .items(false) // exactly 2 items
      .map { array in
        IntRange(lowerBound: array[0], upperBound: array[1])
      }
  }
}
```

### Option 2: Schema Override Annotation
Add a way to provide custom schema via macro parameter:

```swift
@Schemable(customSchema: IntRangeSchema.self)
struct IntRange: Codable {
  // ...
}

struct IntRangeSchema: CustomSchemaProvider {
  static var schema: some JSONSchemaComponent<IntRange> {
    // custom schema here
  }
}
```

### Option 3: Detect and Warn
The macro could detect if `encode(to:)` or `init(from:)` are implemented and emit a compiler warning/error suggesting manual schema definition.

## Recommendation

**Option 1 (Manual Schema)** is the most straightforward and is already supported. The solution is to:

1. **Don't** use `@Schemable` on types with custom Codable implementations
2. Manually conform to `Schemable` and provide the correct schema
3. Document this pattern in the library documentation

Example documentation:

```swift
/// For types with custom Codable implementations, manually define the schema
/// to match your actual encoding/decoding behavior.
///
/// ❌ Don't do this:
/// @Schemable
/// struct IntRange: Codable {
///   func encode(to encoder: Encoder) throws { /* custom */ }
/// }
///
/// ✅ Do this instead:
/// struct IntRange: Codable {
///   func encode(to encoder: Encoder) throws { /* custom */ }
/// }
///
/// extension IntRange: Schemable {
///   static var schema: some JSONSchemaComponent<IntRange> {
///     // Define schema that matches your custom encoding
///   }
/// }
```

## Test File Created

- `Tests/JSONSchemaIntegrationTests/CustomCodableIntegrationTests.swift` - Integration tests showing the problem

## Next Steps

1. Document the limitation and recommended pattern
2. Consider adding compiler warning when custom Codable is detected (future enhancement)
3. Add examples to documentation showing how to manually define schemas for custom Codable types
