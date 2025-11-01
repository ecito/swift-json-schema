# Optional Types Investigation

## Problem Statement

Swift `Optional<T>` types currently generate JSON schemas that:
1. ✅ Allow the property to be **missing** from the JSON object (not required)
2. ❌ Do NOT allow the property value to be explicitly **`null`**

This creates a mismatch with how `Codable` actually encodes optionals - it can encode them as `null`.

## Current Behavior

For a struct like:
```swift
@Schemable
struct Weather {
  let temperature: Double
  let humidity: Int?
}
```

The generated schema for `humidity` is:
```json
{
  "type": "integer"
}
```

And `humidity` is NOT in the `required` array.

This means:
- ✅ `{"temperature": 72.5}` - valid (humidity missing)
- ❌ `{"temperature": 72.5, "humidity": null}` - INVALID (null not allowed)
- ✅ `{"temperature": 72.5, "humidity": 65}` - valid

## Desired Behavior

The schema for `humidity` should allow null:
```json
{
  "anyOf": [
    {"type": "integer"},
    {"type": "null"}
  ]
}
```

This would make all three cases valid.

## Implementation Attempt

### Approach
Wrap optional types with `JSONComposition.AnyOf` to create a union of the base type and null.

### Code Changes
1. Added `unwrappedType` property to `TypeSyntax` extension
2. Modified `SchemableMember.generateSchema()` to wrap optional types

### Issues Encountered

1. **Type Inference Problems**: The Swift compiler struggles to infer generic types when using `.map { $0 }` and `.map { nil }` in the anyOf builder

2. **Double Optional Problem**: When generating code like:
   ```swift
   JSONComposition.AnyOf(into: String?.self) {
     JSONString().map { $0 as String? }
     JSONNull().map { nil as String? }
   }
   ```
   The anyOf returns `String?`, but the property is already typed as `String?`, creating `String??`

3. **Init Signature Mismatch**: The generated init expects `(String, String?, ...)` but gets `(String, String??, ...)`

## Root Cause

The fundamental issue is that `JSONComposition.AnyOf` produces an output type, and when that output type is `T?`, it conflicts with the already-optional property type.

## Possible Solutions

### Option 1: Change AnyOf to Return Unwrapped Type
Make the anyOf return the unwrapped type `T` instead of `T?`, and handle the optionality at the property level. This would require changes to how the parsing works.

### Option 2: Use a Different Schema Pattern
Instead of anyOf, use a modifier or different schema construct that allows null without changing the output type.

### Option 3: Make it a Breaking Change
Accept that this changes the generated code significantly and update all existing tests. The anyOf would return `T?` and properties would need to be restructured.

### Option 4: Add a Feature Flag
Make nullable support opt-in via a macro parameter like `@Schemable(nullableOptionals: true)`.

## Impact

This is a **breaking change** that would:
- Change generated code for ALL structs with optional properties
- Require updating ~50+ existing tests
- Change the JSON schema output format
- Potentially affect runtime behavior for existing users

## Recommendation

Before proceeding, we should:
1. Discuss whether this breaking change is acceptable
2. Consider if there's a non-breaking way to add this functionality
3. Create a migration guide if we proceed
4. Add comprehensive tests for the new behavior

## Test Files Created

- `Tests/JSONSchemaIntegrationTests/OptionalTypesIntegrationTests.swift` - Integration tests showing the problem
- `Tests/JSONSchemaMacroTests/OptionalNullableTests.swift` - Macro expansion test (currently failing)

## Next Steps

1. Decide on approach (breaking change vs. opt-in vs. alternative solution)
2. If proceeding with breaking change:
   - Fix the type inference/double-optional issues
   - Update all existing tests
   - Add migration documentation
3. Consider the other two issues mentioned in the original summary:
   - Int-backed enum dictionary keys
   - Custom Codable encoding (IntRange)
