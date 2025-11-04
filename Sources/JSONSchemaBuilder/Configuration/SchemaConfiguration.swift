import Foundation

/// Global configuration for schema generation behavior.
///
/// This singleton provides runtime configuration that can be scoped globally or per-module.
/// Configuration checked during schema parsing and generation.
///
/// Example usage:
/// ```swift
/// // Global configuration
/// SchemaConfiguration.shared.optionalNulls = true
/// SchemaConfiguration.shared.keyStrategy = .snakeCase
///
/// // Module-specific configuration
/// SchemaConfiguration.shared.configure(module: "MyApp") { config in
///   config.optionalNulls = false
///   config.keyStrategy = .camelCase
/// }
/// ```
///
/// Configuration priority (most to least specific):
/// 1. Property-level: `@SchemaOptions(.orNull(style: .type))`
/// 2. Type-level: `@Schemable(optionalNulls: true)`
/// 3. Module-level: `SchemaConfiguration.shared.configure(module:)`
/// 4. Global-level: `SchemaConfiguration.shared.optionalNulls`
public final class SchemaConfiguration: @unchecked Sendable {
  /// Shared singleton instance.
  public static let shared = SchemaConfiguration()

  private let lock = NSLock()
  private var _optionalNulls: Bool = false
  private var _keyStrategy: KeyEncodingStrategies = .identity
  private var _moduleConfigs: [String: ModuleConfig] = [:]

  private init() {}

  /// Global default: whether optional properties should accept explicit `null` values.
  ///
  /// When `true`, all optional properties will accept `null` unless overridden at module or type level.
  /// Default: `false`
  public var optionalNulls: Bool {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _optionalNulls
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _optionalNulls = newValue
    }
  }

  /// Global default key encoding strategy.
  ///
  /// Default: `.identity`
  public var keyStrategy: KeyEncodingStrategies {
    get {
      lock.lock()
      defer { lock.unlock() }
      return _keyStrategy
    }
    set {
      lock.lock()
      defer { lock.unlock() }
      _keyStrategy = newValue
    }
  }

  /// Configure schema generation for a specific module.
  ///
  /// Module-level configuration overrides global defaults but is overridden by type-level
  /// configuration.
  ///
  /// - Parameters:
  ///   - module: The module name (typically the target name in Package.swift)
  ///   - configure: Closure to configure the module settings
  public func configure(module: String, _ configure: (inout ModuleConfig) -> Void) {
    lock.lock()
    defer { lock.unlock() }

    var moduleConfig = _moduleConfigs[module] ?? ModuleConfig()
    configure(&moduleConfig)
    _moduleConfigs[module] = moduleConfig
  }

  /// Get the effective configuration for a module.
  ///
  /// Returns module-specific config if available, falls back to creating one with global defaults.
  internal func effectiveConfig(for module: String) -> ModuleConfig {
    lock.lock()
    defer { lock.unlock() }

    if let moduleConfig = _moduleConfigs[module] {
      return moduleConfig
    }

    // Return global defaults
    return ModuleConfig()
  }

  /// Get the resolved optional nulls setting for a module.
  ///
  /// Returns module override if set, otherwise global default.
  internal func resolvedOptionalNulls(for module: String) -> Bool {
    let config = effectiveConfig(for: module)
    return config.optionalNulls ?? optionalNulls
  }

  /// Get the resolved key strategy for a module.
  ///
  /// Returns module override if set, otherwise global default.
  internal func resolvedKeyStrategy(for module: String) -> KeyEncodingStrategies {
    let config = effectiveConfig(for: module)
    return config.keyStrategy ?? keyStrategy
  }

  /// Reset all configuration to defaults. Useful for testing.
  public func reset() {
    lock.lock()
    defer { lock.unlock() }

    _optionalNulls = false
    _keyStrategy = .identity
    _moduleConfigs = [:]
  }
}

/// Module-specific schema configuration.
///
/// Values are optional to allow falling back to global defaults.
public struct ModuleConfig: Sendable {
  /// Module-specific override for optional null handling.
  ///
  /// When `nil`, falls back to global `SchemaConfiguration.shared.optionalNulls`.
  public var optionalNulls: Bool?

  /// Module-specific override for key encoding strategy.
  ///
  /// When `nil`, falls back to global `SchemaConfiguration.shared.keyStrategy`.
  public var keyStrategy: KeyEncodingStrategies?

  public init() {}
}
