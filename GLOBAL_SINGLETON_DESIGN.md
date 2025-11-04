# Global Singleton Configuration Design

## The Challenge: Compile-Time vs Runtime

Macros execute at **compile time**, but singletons exist at **runtime**. This creates a fundamental tension:

```swift
// Macro expansion happens during compilation
@Schemable  // ← Macro runs NOW (compile time)
struct User {
  let age: Int?
}

// Singleton exists during execution
SchemaConfiguration.shared.optionalNulls = true  // ← Happens LATER (runtime)
```

## Two Possible Approaches

### Approach A: Runtime Configuration (Dynamic Schemas)

Schema generation happens at runtime by checking global config.

#### Implementation Strategy

```swift
// 1. Global configuration singleton
public final class SchemaConfiguration {
  public static let shared = SchemaConfiguration()

  public var optionalNulls: Bool = false
  public var keyStrategy: KeyEncodingStrategies = .identity

  // Module-specific overrides
  private var moduleConfigs: [String: ModuleConfig] = [:]

  public func configure(module: String, _ config: (inout ModuleConfig) -> Void) {
    var moduleConfig = moduleConfigs[module] ?? ModuleConfig()
    config(&moduleConfig)
    moduleConfigs[module] = moduleConfig
  }

  internal func config(for module: String) -> ModuleConfig {
    moduleConfigs[module] ?? ModuleConfig()
  }
}

public struct ModuleConfig {
  public var optionalNulls: Bool?
  public var keyStrategy: KeyEncodingStrategies?
}
```

#### Macro Changes

The macro would generate code that **checks the global config at runtime**:

```swift
// Current (static, type-scoped)
@Schemable(optionalNulls: true)
struct User {
  let age: Int?
}
// Generates:
static var schema: some JSONSchemaComponent<User> {
  JSONSchema(User.init) {
    JSONObject {
      JSONProperty(key: "age") { JSONInt().orNull(style: .type) }
    }
  }
}

// New (dynamic, checks global config)
@Schemable
struct User {
  let age: Int?
}
// Generates:
static var schema: some JSONSchemaComponent<User> {
  JSONSchema(User.init) {
    JSONObject {
      JSONProperty(key: "age") {
        if SchemaConfiguration.shared
            .config(for: "ModuleName")
            .optionalNulls
            ?? SchemaConfiguration.shared.optionalNulls {
          JSONInt().orNull(style: .type)
        } else {
          JSONInt()
        }
      }
    }
  }
}
```

**Problem**: This won't compile! The `if` statement isn't allowed in the result builder context.

#### Alternative: Conditional Modifier

```swift
// Helper that conditionally applies .orNull()
extension JSONSchemaComponent {
  func orNullIfConfigured(module: String) -> some JSONSchemaComponent<Output?> {
    let config = SchemaConfiguration.shared.config(for: module)
    let shouldOrNull = config.optionalNulls
                       ?? SchemaConfiguration.shared.optionalNulls
    if shouldOrNull {
      return self.orNull(style: /* determine style */)
    } else {
      // Problem: Can't return different types
    }
  }
}
```

**Problem**: Type system won't allow returning `Self` vs `OrNullComponent<Self>`.

#### Solution: Always Wrap, Conditionally Enable

```swift
extension JSONSchemaComponent {
  func orNullIfConfigured(
    module: String,
    primitive: SupportedPrimitive
  ) -> some JSONSchemaComponent<Output?> {
    ConditionalOrNull(
      wrapped: self,
      module: module,
      primitive: primitive
    )
  }
}

struct ConditionalOrNull<Wrapped: JSONSchemaComponent>: JSONSchemaComponent {
  let wrapped: Wrapped
  let module: String
  let primitive: SupportedPrimitive

  func parse(_ value: JSONValue) -> Parsed<Wrapped.Output?, ParseIssue> {
    // Check config at parse time
    let config = SchemaConfiguration.shared.config(for: module)
    let shouldAcceptNull = config.optionalNulls
                          ?? SchemaConfiguration.shared.optionalNulls

    if shouldAcceptNull && value == .null {
      return .valid(nil)
    }

    return wrapped.parse(value).map(Optional.some)
  }

  func schemaValue() -> JSONValue {
    let config = SchemaConfiguration.shared.config(for: module)
    let shouldAcceptNull = config.optionalNulls
                          ?? SchemaConfiguration.shared.optionalNulls

    if shouldAcceptNull {
      let style: OrNullStyle = primitive.isScalar ? .type : .union
      return wrapped.orNull(style: style).schemaValue()
    } else {
      return wrapped.schemaValue()
    }
  }
}
```

**Macro generates:**

```swift
static var schema: some JSONSchemaComponent<User> {
  JSONSchema(User.init) {
    JSONObject {
      JSONProperty(key: "age") {
        JSONInt().orNullIfConfigured(
          module: "MyModule",
          primitive: .int
        )
      }
    }
  }
}
```

#### Pros
✅ True global configuration
✅ Cascades automatically to nested types
✅ Can be configured at runtime
✅ Module-level scoping possible
✅ Can change config per test

#### Cons
❌ Runtime overhead (checking config on every parse/schema generation)
❌ More complex implementation
❌ Harder to reason about (config not visible at type definition)
❌ Type signature becomes more complex
❌ Breaks static schema generation

---

### Approach B: Compile-Time Configuration File

Read configuration from a file during macro expansion.

#### Implementation Strategy

```swift
// .swift-json-schema.yml in project root
global:
  optionalNulls: false
  keyStrategy: identity

modules:
  MyApp:
    optionalNulls: true
    keyStrategy: snakeCase
  MyNetworking:
    optionalNulls: false
    keyStrategy: camelCase
```

```swift
// In macro implementation
struct SchemaCompileTimeConfig {
  let optionalNulls: Bool
  let keyStrategy: String

  static func load(for module: String) -> SchemaCompileTimeConfig {
    // Read .swift-json-schema.yml from source tree
    // Parse and extract config for module
    // Fall back to global config
  }
}
```

#### Macro Changes

```swift
// In SchemableMacro
func expansion(...) -> [DeclSyntax] {
  // Detect module name from context
  let moduleName = detectModuleName(from: context)

  // Load compile-time config
  let compileConfig = SchemaCompileTimeConfig.load(for: moduleName)

  // Use config if no explicit macro parameter
  let effectiveOptionalNulls = explicitOptionalNulls ?? compileConfig.optionalNulls
  let effectiveKeyStrategy = explicitKeyStrategy ?? compileConfig.keyStrategy

  // Generate schema with effective config
  let generator = SchemaGenerator(
    fromStruct: structDecl,
    keyStrategy: effectiveKeyStrategy,
    optionalNulls: effectiveOptionalNulls,
    accessLevel: accessLevel
  )

  return [generator.makeSchema()]
}
```

#### Pros
✅ No runtime overhead
✅ Config visible in project (checked into git)
✅ Consistent with other Swift tools (.swiftformat, .swiftlint.yml)
✅ Module-level scoping natural
✅ Type signatures unchanged
✅ Static schema generation preserved

#### Cons
❌ Not truly "runtime" configurable
❌ Requires macro to have file system access
❌ Config not visible at type definition site
❌ May have issues with macro sandbox permissions
❌ Harder to configure per-test

---

## Module Scoping Options

### Option 1: Module Detection via Context

```swift
// Macro detects module from declaration context
let moduleName = context.moduleName  // If available in SwiftSyntax
```

### Option 2: Explicit Module Parameter

```swift
@Schemable(module: "MyApp")
struct User {
  let age: Int?
}
```

### Option 3: Source File Path

```swift
// Detect module from file path
// File: Sources/MyApp/Models/User.swift
// Module: MyApp
let components = context.location.file.pathComponents
let moduleName = components[components.firstIndex(of: "Sources")! + 1]
```

### Option 4: Package Boundary Detection

```swift
// Use Package.swift to determine module boundaries
// Read nearest Package.swift and find which target the file belongs to
```

---

## Priority Hierarchy

When multiple configurations exist, what takes precedence?

### Recommended Hierarchy (Most to Least Specific)

1. **Property-level**: `@SchemaOptions(.orNull(style: .type))`
2. **Type-level**: `@Schemable(optionalNulls: true)`
3. **Module-level**: Module config in global singleton or config file
4. **Global-level**: Global default in singleton or config file

```swift
// Global config
SchemaConfiguration.shared.optionalNulls = true
SchemaConfiguration.shared.configure(module: "MyApp") { config in
  config.optionalNulls = false  // Override global for this module
}

// In MyApp module:
@Schemable(optionalNulls: true)  // Override module config
struct User {
  let name: String

  let age: Int?  // Accepts null (type-level = true)

  @SchemaOptions(.orNull(style: .union))
  let email: String?  // Uses .union style (property-level override)

  let address: Address  // Address uses its OWN config hierarchy
}
```

---

## Recommendation

I suggest **neither approach** fully solves the problem elegantly:

- **Approach A** (Runtime) adds complexity and overhead without clear benefit
- **Approach B** (Compile-time file) is unusual for Swift and may have sandbox issues

**Alternative**: Keep the current type-scoped approach, but add convenience:

```swift
// Define a type alias or base protocol with your preferred defaults
typealias MyAppModel = MyAppModelProtocol

protocol MyAppModelProtocol: Schemable {}

// Provide a code generation script or Sourcery template
// that adds @Schemable(optionalNulls: true) to all types in a module
```

This keeps the library simple while giving users tools to apply config broadly.

---

## Next Steps

If we proceed with implementation:

1. **Choose approach**: Runtime (A) or Compile-time (B)?
2. **Determine module detection**: How to know which module a type belongs to?
3. **Implement singleton/config**: Create the global configuration mechanism
4. **Update macro**: Integrate configuration checking
5. **Add tests**: Verify cascading behavior and priority hierarchy
6. **Document**: Clear guide on configuration scope and precedence

**My recommendation**: Implement Approach A (Runtime) as a **proof of concept** to see how it feels in practice, then decide if the added complexity is worth it.
