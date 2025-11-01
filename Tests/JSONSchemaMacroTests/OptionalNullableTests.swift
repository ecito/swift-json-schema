import JSONSchemaMacro
import SwiftSyntaxMacros
import Testing

@Suite struct OptionalNullableTests {
  let testMacros: [String: Macro.Type] = ["Schemable": SchemableMacro.self]

  @Test func optionalPropertyWithNullableSchema() {
    assertMacroExpansion(
      """
      @Schemable
      struct Weather {
        let temperature: Double
        let humidity: Int?
      }
      """,
      expandedSource: """
        struct Weather {
          let temperature: Double
          let humidity: Int?

          static var schema: some JSONSchemaComponent<Weather> {
            JSONSchema(Weather.init) {
              JSONObject {
                JSONProperty(key: "temperature") {
                  JSONNumber()
                }
                .required()
                JSONProperty(key: "humidity") {
                  JSONComposition.AnyOf(into: Int?.self) {
                    JSONInteger()
                      .map { $0 }
                    JSONNull()
                      .map { nil }
                  }
                }
              }
            }
          }
        }

        extension Weather: Schemable {
        }
        """,
      macros: testMacros
    )
  }
}
