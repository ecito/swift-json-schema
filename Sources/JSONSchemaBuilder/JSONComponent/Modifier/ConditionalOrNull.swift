import JSONSchema

/// A component that conditionally accepts `null` based on global or module-level configuration.
///
/// This component checks `SchemaConfiguration.shared` at runtime to determine whether to accept
/// explicit `null` values. Used by the `@Schemable` macro when no explicit type-level
/// `optionalNulls` parameter is provided.
///
/// The actual null-acceptance behavior is determined at parse/schema generation time by checking:
/// 1. Module-specific config: `SchemaConfiguration.shared.configure(module:)`
/// 2. Global config: `SchemaConfiguration.shared.optionalNulls`
struct ConditionalOrNullComponent<WrappedValue, Wrapped: JSONSchemaComponent>: JSONSchemaComponent
where Wrapped.Output == WrappedValue {
  typealias Output = WrappedValue?

  let wrapped: Wrapped
  let module: String
  let isScalar: Bool

  var schemaValue: SchemaValue {
    get {
      let shouldAcceptNull = SchemaConfiguration.shared.resolvedOptionalNulls(for: module)

      if shouldAcceptNull {
        let style: OrNullStyle = isScalar ? .type : .union
        return wrapped.orNull(style: style).schemaValue
      } else {
        return wrapped.schemaValue
      }
    }
    set {}
  }

  public func parse(_ value: JSONValue) -> Parsed<WrappedValue?, ParseIssue> {
    let shouldAcceptNull = SchemaConfiguration.shared.resolvedOptionalNulls(for: module)

    if shouldAcceptNull && value == .null {
      return .valid(nil)
    }

    return wrapped.parse(value).map(Optional.some)
  }
}

extension JSONSchemaComponent {
  /// Conditionally accepts `null` based on global or module-level configuration.
  ///
  /// This method creates a component that checks `SchemaConfiguration.shared` at runtime to
  /// determine whether to accept explicit `null` values. Used by the `@Schemable` macro when
  /// no explicit type-level configuration is provided.
  ///
  /// - Parameters:
  ///   - module: The module name to check for configuration
  ///   - isScalar: Whether this is a scalar primitive type (uses `.type` style vs `.union`)
  /// - Returns: A component that conditionally accepts `null`
  public func orNullIfConfigured(
    module: String,
    isScalar: Bool
  ) -> JSONComponents.AnySchemaComponent<Output?> {
    ConditionalOrNullComponent<Output, Self>(
      wrapped: self,
      module: module,
      isScalar: isScalar
    ).eraseToAnySchemaComponent()
  }
}
