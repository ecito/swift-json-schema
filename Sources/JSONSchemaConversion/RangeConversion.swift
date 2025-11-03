import Foundation
import JSONSchemaBuilder

/// A conversion for `Range<Int>` that matches Codable's array encoding.
///
/// Codable encodes `Range<Int>` as a 2-element array: `[lowerBound, upperBound]`.
/// This conversion provides a schema that validates this format and parses it back to a Range.
///
/// Example JSON: `[0, 10]` represents the range 0..<10
public struct RangeConversion: Schemable {
  public static var schema: some JSONSchemaComponent<Range<Int>> {
    JSONArray {
      JSONInteger()  // All items must be integers
    }
    .minItems(2)  // Exactly 2 items
    .maxItems(2)
    .description("A range encoded as [lowerBound, upperBound]")
    .compactMap { array -> Range<Int>? in
      guard array.count == 2,
        array[0] < array[1]
      else {
        return nil
      }
      return array[0]..<array[1]
    }
  }
}
