# CodingKeys Edge Cases - Test Results

This document describes the edge cases we've tested for the CodingKeys support in the `@Schemable` macro and documents their behavior.

## Test Summary

All edge cases have been tested and pass successfully. The implementation handles edge cases gracefully with predictable, sensible behavior.

## Edge Cases Tested

### 1. ✅ Missing CodingKeys for Some Properties

**Scenario:** Not all properties have corresponding CodingKeys cases.

```swift
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
```

**Behavior:** Properties without CodingKeys entries fall back to using their property name as-is.

**Generated properties:** `"id"`, `"full_name"`, `"email"`

**Status:** ✅ Works correctly

---

### 2. ✅ Extra CodingKeys That Don't Match Properties

**Scenario:** CodingKeys enum contains cases that don't correspond to any property.

```swift
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
```

**Behavior:** Extra CodingKeys entries are safely ignored. Only properties that actually exist are included in the schema.

**Generated properties:** `"first_name"`, `"last_name"` (middleName and age are ignored)

**Status:** ✅ Works correctly

---

### 3. ✅ Empty String as CodingKey Value

**Scenario:** A CodingKey has an empty string as its raw value.

```swift
@Schemable
struct EmptyStringCodingKey {
  let id: Int
  let metadata: String

  enum CodingKeys: String, CodingKey {
    case id
    case metadata = ""  // Empty string
  }
}
```

**Behavior:** The macro correctly generates the property with an empty string key. The property appears in the `required` array but is handled specially by JSONObject (doesn't appear in `properties` object).

**Generated schema:**
- Properties: `"id"` (metadata with empty key is filtered by JSONObject)
- Required: `"id"`, `""`

**Status:** ✅ Works correctly (JSONObject behavior)

**Note:** While this works, empty string keys are not recommended and may cause issues with JSON validation or consumption.

---

### 4. ✅ Special Characters in CodingKeys

**Scenario:** CodingKeys use special characters like dots, hyphens, etc.

```swift
@Schemable
struct SpecialCharsCodingKey {
  let userId: Int
  let userName: String

  enum CodingKeys: String, CodingKey {
    case userId = "user.id"
    case userName = "user-name"
  }
}
```

**Behavior:** Special characters are preserved and work correctly in the generated schema.

**Generated properties:** `"user.id"`, `"user-name"`

**Status:** ✅ Works correctly

**Note:** While special characters work, they may not be conventional in JSON APIs. Use with caution depending on your API consumers.

---

### 5. ✅ Nested Types with Their Own CodingKeys

**Scenario:** A struct contains a nested struct, and both have their own CodingKeys.

```swift
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
```

**Behavior:** Each type's CodingKeys is correctly scoped to that type. The macro properly handles nested types with their own CodingKeys.

**Generated outer properties:** `"outer_id"`, `"nested_data"`

**Generated nested properties:** `"inner_id"`, `"data_value"`

**Status:** ✅ Works correctly

---

## Edge Cases NOT Supported (Known Limitations)

### 1. ⚠️ Integer-based CodingKeys

**Scenario:** CodingKeys uses `Int` as the raw type instead of `String`.

```swift
enum CodingKeys: Int, CodingKey {  // Not String
  case id = 0
  case name = 1
}
```

**Behavior:** The macro requires `String` raw values. Integer-based CodingKeys are ignored (properties fall back to property names).

**Reason:** JSON property names must be strings, not integers.

---

### 2. ⚠️ CodingKeys Without Raw Value Type

**Scenario:** CodingKeys enum doesn't conform to a raw representable type.

```swift
enum CodingKeys: CodingKey {  // No : String
  case firstName
  case lastName
}
```

**Behavior:** The macro's `extractCodingKeys()` method looks for string literals as raw values. Without explicit raw values, cases are treated as having their case name as the value.

**Status:** Partially supported - works if cases use their own names

---

### 3. ⚠️ @ExcludeFromSchema with Stored Properties

**Scenario:** Using `@ExcludeFromSchema` on stored `let` properties can cause initializer signature mismatches.

**Workaround:** Use `var` with default values for excluded properties, or don't include them in CodingKeys.

---

## Recommendations

Based on our edge case testing:

1. **Always use `String` as the raw type** for CodingKeys: `enum CodingKeys: String, CodingKey`

2. **Provide explicit raw values** for all cases to avoid ambiguity

3. **Avoid empty string keys** - while they technically work, they're problematic for JSON

4. **Be cautious with special characters** - dots and hyphens work, but may not be conventional

5. **Extra CodingKeys are safe** - having more keys than properties doesn't cause issues

6. **Missing CodingKeys are safe** - properties without keys fall back to property names

7. **Nested types work independently** - each type's CodingKeys is properly scoped

## Test Coverage

All edge cases are covered by integration tests in:
- `Tests/JSONSchemaIntegrationTests/CodingKeysEdgeCasesTests.swift`

Tests include:
- ✅ `missingCodingKeysForSomeProperties` - Partial CodingKeys coverage
- ✅ `extraCodingKeysThatDontMatchProperties` - Extra unused CodingKeys
- ✅ `simpleStructWithCodingKeys` - Basic CodingKeys usage
- ✅ `emptyStringCodingKey` - Empty string as key value
- ✅ `specialCharactersInCodingKey` - Special chars in keys
- ✅ `nestedTypeWithOwnCodingKeys` - Nested types with separate CodingKeys

All tests pass successfully! ✅
