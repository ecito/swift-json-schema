# Add Swift Package Traits for Global Configuration

## Description

This PR introduces Swift 6.1+ package traits support to enable global configuration of `@Schemable` behavior without requiring parameters on every type declaration. Three new traits are added:

1. **`OptionalNulls`** - Automatically enables null acceptance for all optional properties
2. **`SnakeCase`** - Automatically applies snake_case key encoding to all properties
3. **`KebabCase`** - Automatically applies kebab-case key encoding to all properties

### Key Features

**Trait-Based Configuration:**
Client packages can now enable traits when adding the dependency:

```swift
// In Package.swift
dependencies: [
  .package(url: "https://github.com/ajevans99/swift-json-schema.git", from: "0.15.0",
           traits: [
             .init(name: "OptionalNulls"),
             .init(name: "SnakeCase")
           ])
]
```

**Per-Type Overrides:**
Explicit parameters still work and override trait defaults:

```swift
// When OptionalNulls trait is enabled:
@Schemable(optionalNulls: false)  // Override to disable
struct StrictSchema { ... }

// When SnakeCase trait is enabled:
@Schemable(keyStrategy: .kebabCase)  // Override to use different strategy
struct CustomSchema { ... }
```

**Compile-Time Safety:**
The `SnakeCase` and `KebabCase` traits are mutually exclusive. Attempting to enable both simultaneously results in a clear compile-time error:

```swift
#error("Cannot enable both SnakeCase and KebabCase traits simultaneously. These traits are mutually exclusive.")
```

### Implementation Details

- **Package File**: Renamed `Package@swift-6.0.swift` to `Package@swift-6.1.swift` (traits require Swift 6.1+)
- **Macro Detection**: Uses preprocessor directives (`#if OptionalNulls`, `#if SnakeCase`, etc.) to detect enabled traits
- **Default Behavior**: When no trait is enabled and no explicit parameter is provided, existing default behavior is maintained
- **Priority**: Explicit parameters always take precedence over trait-based defaults

### Testing

Added comprehensive integration tests for all three traits:
- `OptionalNullsTraitTests.swift` - Tests trait-enabled and trait-disabled scenarios
- `KeyEncodingTraitTests.swift` - Tests both key encoding traits and trait-disabled scenarios
- All tests verify both default behavior and explicit overrides

### Documentation

Updated `Macros.md` with:
- Package-level opt-in examples for all traits
- Clear explanation of trait behavior and overrides
- Mutual exclusivity warning for key encoding traits

## Type of Change

- [x] New feature
- [x] Documentation update

## Additional Notes

### Benefits

1. **Cleaner Code**: Eliminates repetitive parameters across large codebases
2. **Project-Wide Consistency**: Enforces consistent configuration at the package level
3. **Backward Compatible**: Existing code works unchanged; traits are opt-in
4. **Type Safe**: Compile-time errors prevent invalid trait combinations

### Requires

- Swift 6.1+ (for trait support)
- Built on top of the existing `feature/optional-null-opt-in` branch

### Related Work

This PR builds upon:
- Existing `optionalNulls` parameter support (from `feature/optional-null-opt-in`)
- Existing `keyStrategy` parameter support
- Swift 6 support (from `swift-6-support` branch)

### Future Considerations

Additional traits could be added for other configuration options following this same pattern.
