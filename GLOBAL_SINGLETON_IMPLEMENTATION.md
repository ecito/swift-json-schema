# Global Singleton Configuration - Implementation Summary

## Branch: `feature/global-singleton-config`

## Overview

This branch implements a **runtime global configuration singleton** that allows controlling schema behavior (like `optionalNulls`) at the application level or per-module level, while maintaining backward compatibility with the existing type-scoped configuration.

## Key Changes

### 1. SchemaConfiguration Singleton

**File**: `Sources/JSONSchemaBuilder/Configuration/SchemaConfiguration.swift` (NEW)

A thread-safe singleton that provides:
- Global default configuration (`SchemaConfiguration.shared.optionalNulls`)
- Module-specific overrides (`SchemaConfiguration.shared.configure(module:)`)
- Runtime configuration checks during schema parsing and generation

```swift
// Global configuration
SchemaConfiguration.shared.optionalNulls = true

// Module-specific configuration
SchemaConfiguration.shared.configure(module: "MyApp") { config in
  config.optionalNulls = false
}
```

### 2. ConditionalOrNull Component

**File**: `Sources/JSONSchemaBuilder/JSONComponent/Modifier/ConditionalOrNull.swift` (NEW)

A schema component that conditionally accepts `null` based on runtime configuration:
- Checks global config at parse/schema generation time
- Automatically selects `.type` or `.union` style based on scalar vs complex types
- Type signature always returns optional (`Output?`) for consistency

```swift
extension JSONSchemaComponent {
  public func orNullIfConfigured(
    module: String,
    isScalar: Bool
  ) -> JSONComponents.AnySchemaComponent<Output?>
}
```

### 3. Macro API Changes

**File**: `Sources/JSONSchemaBuilder/Macros/Schemable.swift`

Updated `@Schemable` macro with new parameters:

```swift
@Schemable(
  keyStrategy: KeyEncodingStrategies? = nil,
  optionalNulls: Bool = false,               // Explicit type-level config
  module: String? = nil,                      // Module name for config lookup
  useGlobalConfig: Bool = false               // Opt-in to runtime config
)
```

### 4. Configuration Priority Hierarchy

From most to least specific:

1. **Property-level**: `@SchemaOptions(.orNull(style: .type))`
   - Explicit per-property annotation
   - Always takes precedence

2. **Type-level**: `@Schemable(optionalNulls: true)`
   - Explicit type-level configuration
   - Applies to all properties in the type

3. **Runtime config**: `@Schemable(useGlobalConfig: true)`
   - Checks `SchemaConfiguration.shared` at runtime
   - Falls back to module config, then global config

4. **Default**: No null acceptance
   - Backward compatible behavior
   - Optional properties only accept missing values

## Usage Examples

### Example 1: Global Configuration

```swift
// In app initialization
SchemaConfiguration.shared.optionalNulls = true

// All types with useGlobalConfig will accept null for optional properties
@Schemable(useGlobalConfig: true)
struct User {
  let name: String
  let email: String?  // Accepts null (global config)
}
```

### Example 2: Module-Specific Configuration

```swift
// Configure different behavior per module
SchemaConfiguration.shared.configure(module: "API") { config in
  config.optionalNulls = true
}

SchemaConfiguration.shared.configure(module: "Database") { config in
  config.optionalNulls = false
}

// In API module
@Schemable(useGlobalConfig: true, module: "API")
struct APIResponse {
  let data: String?  // Accepts null (module config)
}

// In Database module
@Schemable(useGlobalConfig: true, module: "Database")
struct DBRecord {
  let value: String?  // Does NOT accept null (module config overrides)
}
```

### Example 3: Explicit Type-Level Override

```swift
// Global config says true
SchemaConfiguration.shared.optionalNulls = true

// But this type explicitly says false
@Schemable(optionalNulls: false)
struct StrictModel {
  let field: String?  // Does NOT accept null (explicit override)
}

// This type uses global config
@Schemable(useGlobalConfig: true)
struct FlexibleModel {
  let field: String?  // Accepts null (global config)
}
```

### Example 4: Cascading to Nested Types

```swift
// Parent uses global config
@Schemable(useGlobalConfig: true)
struct Parent {
  let child: Child
}

// Child must also opt-in to global config
@Schemable(useGlobalConfig: true)
struct Child {
  let value: String?  // Only accepts null if Child opts in
}
```

**Important**: Global configuration does NOT cascade automatically. Each type must explicitly opt-in with `useGlobalConfig: true`.

## Non-Cascading Design

The global configuration is **non-cascading by design**, matching the existing `keyStrategy` pattern:

```swift
@Schemable(keyStrategy: .snakeCase, useGlobalConfig: true)
struct User {
  let firstName: String    // Uses snakeCase (type-level)
  let address: Address     // Address uses its OWN configuration
}

@Schemable  // No configuration
struct Address {
  let streetName: String  // Uses identity (default)
  let zipCode: Int?       // Does NOT accept null (default)
}
```

Each type's schema is generated independently. When the macro encounters a nested `Schemable` type, it generates `Address.schema`, which is determined solely by `Address`'s own `@Schemable` parameters.

## Module Scoping Options

### Current Implementation: Manual Module Parameter

```swift
@Schemable(useGlobalConfig: true, module: "MyApp")
struct User { }
```

- Module name defaults to `"default"` if not specified
- Explicit control over module configuration lookup
- Simple implementation, no magic

### Future Enhancements (Not Implemented)

1. **Automatic module detection**: Detect module from file path or package structure
2. **Environment variables**: `SWIFT_JSON_SCHEMA_MODULE`
3. **Build-time configuration**: Read from `.swift-json-schema.yml` file

## Key Design Decisions

### 1. Opt-In Runtime Configuration

**Decision**: Require explicit `useGlobalConfig: true` to check runtime configuration.

**Rationale**:
- Backward compatible (default behavior unchanged)
- Type signature changes are opt-in
- Performance impact only for types that need it
- Clear intent at usage site

### 2. Type Signature Always Optional

**Decision**: `.orNullIfConfigured()` always returns `Output?`, even when config is false.

**Rationale**:
- Swift's type system doesn't support conditional types based on runtime values
- Consistent type signature regardless of config state
- Parsing behavior varies, but type signature is stable

### 3. Non-Cascading Configuration

**Decision**: Each type must explicitly opt-in to global configuration.

**Rationale**:
- Matches existing `keyStrategy` pattern
- Explicit > implicit
- Predictable behavior
- No hidden configuration inheritance

### 4. Separate `useGlobalConfig` Flag

**Decision**: Use `useGlobalConfig: Bool` instead of three-state `optionalNulls: Bool?`.

**Rationale**:
- Clearer intent (`useGlobalConfig: true` vs `optionalNulls: nil`)
- Backward compatible (existing `optionalNulls: Bool` unchanged)
- Allows combining: `@Schemable(optionalNulls: true, useGlobalConfig: false)`

## Files Modified

### New Files
1. `Sources/JSONSchemaBuilder/Configuration/SchemaConfiguration.swift`
2. `Sources/JSONSchemaBuilder/JSONComponent/Modifier/ConditionalOrNull.swift`
3. `GLOBAL_SINGLETON_DESIGN.md`
4. `GLOBAL_SINGLETON_IMPLEMENTATION.md`

### Modified Files
1. `Sources/JSONSchemaBuilder/Macros/Schemable.swift`
   - Added `module` and `useGlobalConfig` parameters

2. `Sources/JSONSchemaBuilder/Utils/KeyEncodingStrategy.swift`
   - Added `@unchecked Sendable` conformance to `KeyEncodingStrategies`

3. `Sources/JSONSchemaMacro/Schemable/SchemableMacro.swift`
   - Parse new macro parameters
   - Pass to schema generators

4. `Sources/JSONSchemaMacro/Schemable/SchemaGenerator.swift`
   - Accept `useGlobalConfig` and `module` parameters
   - Pass to member schema generation

5. `Sources/JSONSchemaMacro/Schemable/SchemableMember.swift`
   - Generate `.orNullIfConfigured()` when `useGlobalConfig` is true
   - Updated priority logic for null handling

## Testing Strategy

### Unit Tests Needed

1. **SchemaConfiguration Tests**
   - Global configuration
   - Module-specific configuration
   - Priority resolution

2. **ConditionalOrNull Tests**
   - Runtime config checking
   - Style selection (scalar vs complex)
   - Parsing behavior

3. **Macro Integration Tests**
   - `useGlobalConfig: true` generates correct code
   - Module parameter passed correctly
   - Priority hierarchy works as expected

4. **Cascading Tests**
   - Nested types require explicit opt-in
   - Parent config doesn't affect child

### Example Test Case

```swift
func testModuleSpecificConfiguration() {
  // Configure
  SchemaConfiguration.shared.configure(module: "API") { config in
    config.optionalNulls = true
  }

  @Schemable(useGlobalConfig: true, module: "API")
  struct APIModel {
    let value: String?
  }

  // Test that null is accepted
  let result = APIModel.schema.parse(["value": .null])
  XCTAssertEqual(result.value, .valid(APIModel(value: nil)))
}
```

## Comparison with Original Implementation

### Original (`feature/optional-null-opt-in`)
- ✅ Type-scoped configuration only
- ✅ `@Schemable(optionalNulls: true)`
- ✅ `@SchemaOptions(.orNull(style:))`
- ❌ No runtime configuration
- ❌ No module-level configuration
- ❌ No cascading

### New (`feature/global-singleton-config`)
- ✅ Type-scoped configuration (same)
- ✅ `@Schemable(optionalNulls: true)` (same)
- ✅ `@SchemaOptions(.orNull(style:))` (same)
- ✅ Runtime global configuration (NEW)
- ✅ Module-level configuration (NEW)
- ✅ Still non-cascading (design choice)

## Performance Considerations

### Runtime Overhead

`.orNullIfConfigured()` adds minimal overhead:
- Config lookup: O(1) dictionary access
- Checked only during parse/schema generation
- No overhead for types not using `useGlobalConfig`

### Memory

- Single global singleton (small footprint)
- Module configs: HashMap with small number of entries
- Type signatures unchanged (no additional allocations)

## Migration Guide

### From Original Implementation

If you're currently using:
```swift
@Schemable(optionalNulls: true)
struct User {
  let email: String?
}
```

You can now use global config:
```swift
// In app init
SchemaConfiguration.shared.optionalNulls = true

// In your types
@Schemable(useGlobalConfig: true)
struct User {
  let email: String?
}
```

### Benefits of Migration

- Centralized configuration
- Easier to change behavior across multiple types
- Module-specific overrides
- Runtime configuration (useful for testing)

## Future Work

1. **Automatic Module Detection**
   - Use file path or package structure
   - Reduce boilerplate

2. **Configuration File Support**
   - `.swift-json-schema.yml`
   - Compile-time configuration

3. **Additional Global Options**
   - Key strategy defaults
   - Validation rules
   - Schema metadata

4. **Debug/Logging**
   - Trace which config is being used
   - Helpful for debugging priority issues

## Conclusion

This implementation provides a flexible, opt-in runtime configuration system that:
- ✅ Maintains backward compatibility
- ✅ Supports global and module-level configuration
- ✅ Follows Swift's explicit philosophy
- ✅ Matches existing patterns (`keyStrategy`)
- ✅ Minimal performance impact
- ✅ Clear priority hierarchy

The non-cascading design keeps the library simple and predictable, while the opt-in nature ensures no breaking changes to existing code.
