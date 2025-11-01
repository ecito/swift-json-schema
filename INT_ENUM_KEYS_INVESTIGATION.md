# Int-Backed Enum Dictionary Keys Investigation

## Problem Statement

Dictionaries with Int-backed enum keys are encoded by Swift's `Codable` as **arrays** in alternating key-value format, but the schema generates an **object** expecting key-value pairs.

## Current Behavior

For a dictionary like:
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

**Current schema:**
```json
{
  "type": "object",
  "propertyNames": {
    "type": "string",
    "enum": ["dontListen", "expensive", "other"]
  },
  "additionalProperties": {"type": "string"}
}
```

**Result:** Type mismatch - array vs object

## Root Cause

Swift's `Codable` protocol encodes dictionaries with non-String Codable keys as arrays:
- Format: `[key1, value1, key2, value2, ...]`
- This is a limitation/feature of JSONEncoder to handle non-String keys

The schema generator assumes all dictionaries are JSON objects with string keys.

## Required Fix

For dictionaries with enum keys that have non-String raw types:
1. Detect that the key is an enum with Int/other raw type
2. Generate an **array** schema instead of an object schema
3. Schema should validate alternating key-value pairs
4. Parse the array back into a dictionary

## Implementation Complexity

**High complexity** because:
1. Need to detect enum raw types (requires checking if key type is RawRepresentable)
2. Need to generate array schema with proper validation
3. Need custom parsing logic to convert array to dictionary
4. May require changes to JSONSchemaBuilder to support this pattern

## Possible Solutions

### Option 1: Array Schema with Custom Parser
Generate:
```swift
JSONArray()
  .custom parsing logic to validate pairs and build dictionary
```

### Option 2: Document Limitation
Accept that non-String dictionary keys aren't fully supported and document this limitation.

### Option 3: Recommend String Raw Values
Suggest users use String raw values for enums used as dictionary keys.

## Test File Created

- `Tests/JSONSchemaIntegrationTests/IntEnumKeysIntegrationTests.swift` - Integration tests showing the problem

## Recommendation

This is a **complex fix** requiring significant changes to the schema generation logic. Consider:
1. Documenting this as a known limitation
2. Recommending String-backed enums for dictionary keys
3. Or implementing full support as a future enhancement

## Next Steps

If proceeding with the fix:
1. Add detection for enum raw types in `SwiftSyntaxExtensions.swift`
2. Modify dictionary schema generation in `typeInformation()` to handle non-String keys
3. Implement array-based schema with proper validation
4. Add comprehensive tests
