# JSON Schema Library Limitations - Investigation Summary

This document summarizes the investigation into three known limitations of the swift-json-schema library's `@Schemable` macro.

## Overview

All three issues stem from a fundamental challenge: **The `@Schemable` macro generates schemas by analyzing Swift syntax and type information, but it cannot detect or analyze runtime encoding/decoding behavior.**

## Issue #1: Optional Types and Null Values

### Status: ⚠️ Documented - Complex Fix Required

### Problem
Swift `Optional<T>` types generate schemas that allow properties to be **missing**, but not explicitly **`null`**.

```swift
@Schemable
struct Weather {
  let humidity: Int?  // Optional property
}
```

**Current behavior:**
- ✅ `{"temperature": 72.5}` - valid (humidity missing)
- ❌ `{"temperature": 72.5, "humidity": null}` - INVALID
- ✅ `{"temperature": 72.5, "humidity": 65}` - valid

**Expected behavior:** All three should be valid.

### Root Cause
The macro marks optional properties as not-required, but doesn't add `anyOf` to allow null values in the schema.

### Solution Complexity
**High** - Requires:
1. Wrapping optional types with `JSONComposition.AnyOf`
2. Handling double-optional type inference issues
3. Updating ~50+ existing tests (breaking change)

### Recommendation
- **Breaking change** - requires major version bump
- Need decision on whether to proceed
- Could be made opt-in via `@Schemable(nullableOptionals: true)`

**See:** `OPTIONAL_TYPES_INVESTIGATION.md` for detailed analysis

---

## Issue #2: Int-Backed Enum Dictionary Keys

### Status: ✅ Documented - Known Limitation

### Problem
Dictionaries with enum keys that have non-String raw types are encoded by `Codable` as **arrays**, not objects.

```swift
@Schemable
enum CancellationReason: Int {
  case dontListen = 0
  case expensive = 1
}

let reasonMessages: [CancellationReason: String]
```

**Codable encoding:**
```json
{
  "reasonMessages": [0, "User doesn't want to listen", 1, "Too expensive"]
}
```

**Current schema:** Expects an object with `propertyNames`

### Root Cause
Swift's `Codable` encodes dictionaries with non-String keys as alternating key-value arrays `[k1, v1, k2, v2, ...]`. The schema generator assumes all dictionaries are JSON objects.

### Solution Complexity
**Very High** - Requires:
1. Detecting enum raw types
2. Generating array schemas instead of object schemas
3. Custom parsing logic to convert arrays to dictionaries
4. Significant changes to schema generation logic

### Recommendation
- **Document as known limitation**
- Recommend using String-backed enums for dictionary keys
- Consider as future enhancement if there's demand

**See:** `INT_ENUM_KEYS_INVESTIGATION.md` for detailed analysis

---

## Issue #3: Custom Codable Implementations

### Status: ✅ Documented - Working As Designed

### Problem
Types with custom `encode(to:)` / `init(from:)` implementations have schemas generated from their stored properties, which don't match actual encoding behavior.

```swift
@Schemable
struct IntRange: Codable {
  let lowerBound: Int
  let upperBound: Int

  func encode(to encoder: Encoder) throws {
    var container = encoder.unkeyedContainer()
    try container.encode(lowerBound)
    try container.encode(upperBound)
  }
}
```

**Actual encoding:** `[500, 599]`
**Generated schema:** Expects `{"lowerBound": 500, "upperBound": 599}`

### Root Cause
The macro analyzes syntax and type information only. It cannot detect or analyze custom Codable implementations.

### Solution
**Use manual schema definition:**

```swift
// Don't use @Schemable on types with custom Codable
struct IntRange: Codable {
  // ... custom implementation ...
}

// Manually conform to Schemable
extension IntRange: Schemable {
  static var schema: some JSONSchemaComponent<IntRange> {
    JSONArray()
      .prefixItems {
        JSONInteger()
        JSONInteger()
      }
      .map { IntRange(lowerBound: $0[0], upperBound: $0[1]) }
  }
}
```

### Recommendation
- **Document the pattern** - this is already supported
- Add examples to documentation
- Consider compiler warning when custom Codable is detected (future enhancement)

**See:** `CUSTOM_CODABLE_INVESTIGATION.md` for detailed analysis

---

## Test Files Created

During this investigation, the following integration test files were created:

1. `Tests/JSONSchemaIntegrationTests/OptionalTypesIntegrationTests.swift`
2. `Tests/JSONSchemaIntegrationTests/IntEnumKeysIntegrationTests.swift`
3. `Tests/JSONSchemaIntegrationTests/CustomCodableIntegrationTests.swift`

These tests demonstrate the issues and can be used to verify future fixes.

---

## Recommendations Summary

| Issue | Action | Priority |
|-------|--------|----------|
| Optional null values | Decide: breaking change vs opt-in feature | Medium |
| Int enum keys | Document limitation, recommend String keys | Low |
| Custom Codable | Document manual schema pattern | High (docs) |

---

## Next Steps

1. **Documentation Updates:**
   - Add "Known Limitations" section to README
   - Document manual schema pattern for custom Codable
   - Add examples of working with optional types

2. **Optional Types Decision:**
   - Decide on approach (breaking change vs feature flag)
   - If proceeding, create separate PR with migration guide

3. **Future Enhancements:**
   - Consider adding compiler warnings for custom Codable
   - Explore solutions for Int enum dictionary keys if demand exists
