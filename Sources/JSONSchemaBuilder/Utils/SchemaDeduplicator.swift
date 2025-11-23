import Foundation
import JSONSchema

/// Deduplicates schemas by extracting repeated object schemas into `$defs` and replacing them with `$ref`.
@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
struct SchemaDeduplicator {

  /// Deduplicates the schema by extracting repeated schemas to $defs
  /// - Parameter schemaValue: The root schema value to deduplicate
  /// - Returns: A new schema value with duplicates extracted to $defs
  static func deduplicate(_ schemaValue: JSONValue) -> JSONValue {
    // Step 1: Find all object schemas and count their occurrences
    var schemaOccurrences: [String: (schema: JSONValue, count: Int, paths: [String], suggestedName: String?)] = [:]

    func collectSchemas(at value: JSONValue, path: String) {
      guard case .object(let dict) = value else { return }

      // Only consider "real" object schemas (not $ref, $dynamicRef, etc.)
      guard dict[Keywords.Reference.name] == nil,
            dict[Keywords.DynamicReference.name] == nil else {
        return
      }

      // Check if this is a type:object schema with properties
      if case .string("object") = dict[Keywords.TypeKeyword.name],
         dict[Keywords.Properties.name] != nil {

        // Try to extract a suggested name from the schema
        let suggestedName = extractTypeName(from: dict)

        // Create a normalized key for this schema (excluding certain keywords)
        let key = normalizeSchema(dict) // Use stable normalized JSON as hash key

        if var existing = schemaOccurrences[key] {
          existing.count += 1
          existing.paths.append(path)
          // Keep the first suggested name we found
          schemaOccurrences[key] = existing
        } else {
          schemaOccurrences[key] = (schema: value, count: 1, paths: [path], suggestedName: suggestedName)
        }
      }

      // Recursively traverse the schema
      for (keyword, childValue) in dict {
        if keyword == Keywords.Properties.name, case .object(let props) = childValue {
          for (propName, propValue) in props {
            collectSchemas(at: propValue, path: "\(path)/properties/\(propName)")
          }
        } else if keyword == Keywords.Items.name {
          collectSchemas(at: childValue, path: "\(path)/items")
        } else if keyword == Keywords.AdditionalProperties.name, case .object = childValue {
          collectSchemas(at: childValue, path: "\(path)/additionalProperties")
        }
      }
    }

    collectSchemas(at: schemaValue, path: "#")

    // Step 2: Identify schemas that appear 2+ times
    let duplicates = schemaOccurrences.filter { $0.value.count >= 2 }

    // If no duplicates, return original
    guard !duplicates.isEmpty else {
      return schemaValue
    }

    // Step 3: Create $defs and replace duplicates with $ref
    var defs: [String: JSONValue] = [:]
    var usedDefNames: Set<String> = []
    var schemaToDefName: [String: String] = [:]

    for (key, value) in duplicates {
      // Generate a def name based on the suggested name or fall back to a generic name
      let defName = generateUniqueDefName(
        suggested: value.suggestedName,
        used: &usedDefNames
      )
      defs[defName] = value.schema
      schemaToDefName[key] = defName
    }

    // Step 4: Replace ALL occurrences of duplicates (including first one) with $ref in the main schema
    func replaceWithRefs(in value: JSONValue, isRoot: Bool = false) -> JSONValue {
      guard case .object(let dict) = value else { return value }

      // Skip if already a reference
      if dict[Keywords.Reference.name] != nil || dict[Keywords.DynamicReference.name] != nil {
        return value
      }

      // Check if this schema should be replaced with a $ref
      // Don't replace the root schema itself
      if !isRoot,
         case .string("object") = dict[Keywords.TypeKeyword.name],
         dict[Keywords.Properties.name] != nil {
        // Normalize before comparing to match how we detected duplicates
        let key = normalizeSchema(dict)

        if let defName = schemaToDefName[key] {
          return .object([Keywords.Reference.name: .string("#/$defs/\(defName)")])
        }
      }

      // Recursively process children
      var newDict = dict
      for (keyword, childValue) in dict {
        if keyword == Keywords.Properties.name, case .object(let props) = childValue {
          var newProps: [KeywordIdentifier: JSONValue] = [:]
          for (propName, propValue) in props {
            newProps[propName] = replaceWithRefs(in: propValue)
          }
          newDict[keyword] = .object(newProps)
        } else if keyword == Keywords.Items.name {
          newDict[keyword] = replaceWithRefs(in: childValue)
        } else if keyword == Keywords.AdditionalProperties.name, case .object = childValue {
          newDict[keyword] = replaceWithRefs(in: childValue)
        }
      }

      return .object(newDict)
    }

    let deduplicated = replaceWithRefs(in: schemaValue, isRoot: true)

    // Step 5: Add $defs to the root schema
    guard case .object(var rootDict) = deduplicated else {
      return schemaValue
    }

    rootDict[Keywords.Defs.name] = .object(defs)
    return .object(rootDict)
  }

  /// Normalizes a schema for comparison by removing metadata keywords and creating a stable representation
  private static func normalizeSchema(_ dict: [KeywordIdentifier: JSONValue]) -> String {
    var normalized = dict
    // Remove metadata that doesn't affect structural equality
    normalized.removeValue(forKey: Keywords.Title.name)
    normalized.removeValue(forKey: Keywords.Description.name)
    normalized.removeValue(forKey: Keywords.Examples.name)
    normalized.removeValue(forKey: Keywords.Default.name)
    normalized.removeValue(forKey: Keywords.DynamicAnchor.name) // Don't compare anchors

    // Create a stable JSON representation by encoding with sorted keys
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(normalized),
       let json = String(data: data, encoding: .utf8) {
      return json
    }

    // Fallback to description if encoding fails
    return JSONValue.object(normalized).description
  }

  /// Extracts a suggested type name from schema metadata
  private static func extractTypeName(from dict: [KeywordIdentifier: JSONValue]) -> String? {
    // Try to get name from title
    if case .string(let title) = dict[Keywords.Title.name] {
      return sanitizeDefName(title)
    }

    // Try to get name from $dynamicAnchor (e.g., "JSONSchemaIntegrationTests.TreeNode")
    if case .string(let anchor) = dict[Keywords.DynamicAnchor.name] {
      // Extract just the type name from the fully qualified name
      let components = anchor.split(separator: ".")
      if let typeName = components.last {
        return sanitizeDefName(String(typeName))
      }
    }

    return nil
  }

  /// Sanitizes a string to be a valid def name
  private static func sanitizeDefName(_ name: String) -> String {
    // Remove any characters that aren't valid in JSON keys
    // Keep alphanumeric, underscores, and hyphens
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    return name.unicodeScalars
      .filter { allowed.contains($0) }
      .map { String($0) }
      .joined()
  }

  /// Generates a unique def name, handling conflicts
  private static func generateUniqueDefName(
    suggested: String?,
    used: inout Set<String>
  ) -> String {
    // Start with suggested name or fallback
    let baseName = suggested ?? "Schema"

    // If the base name is unique, use it
    if !used.contains(baseName) {
      used.insert(baseName)
      return baseName
    }

    // Otherwise, append a number to make it unique
    var counter = 0
    var candidateName: String
    repeat {
      candidateName = "\(baseName)\(counter)"
      counter += 1
    } while used.contains(candidateName)

    used.insert(candidateName)
    return candidateName
  }
}
