import JSONSchemaBuilder

// Example 1: Basic CodingKeys usage
@Schemable
struct User {
  let firstName: String
  let lastName: String
  let emailAddress: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"
    case emailAddress = "email"
  }
}

// Example 2: Partial CodingKeys (some properties use default names)
@Schemable
struct Product {
  let name: String  // Will use "name" in schema
  let productId: Int
  let price: Double

  enum CodingKeys: String, CodingKey {
    case name
    case productId = "product_id"
    case price = "unit_price"
  }
}

// Example 3: CodingKeys with @SchemaOptions override
@Schemable
struct Customer {
  let firstName: String
  @SchemaOptions(.key("family_name"))  // Override takes priority
  let lastName: String

  enum CodingKeys: String, CodingKey {
    case firstName = "first_name"
    case lastName = "last_name"  // This will be overridden by @SchemaOptions
  }
}

// Example 4: CodingKeys with keyStrategy (CodingKeys takes priority)
@Schemable(keyStrategy: .snakeCase)
struct Employee {
  let firstName: String      // Uses CodingKeys: "given_name"
  let middleName: String     // Uses CodingKeys: "middleName" (no raw value)
  let lastName: String       // Uses CodingKeys: "family_name"

  enum CodingKeys: String, CodingKey {
    case firstName = "given_name"
    case middleName                    // No raw value = uses case name
    case lastName = "family_name"
  }
}

/*
 * Expected generated schemas:
 *
 * User schema will have properties: "first_name", "last_name", "email"
 * Product schema will have properties: "name", "product_id", "unit_price"
 * Customer schema will have properties: "first_name", "family_name" (not "last_name")
 * Employee schema will have properties: "given_name", "middleName", "family_name"
 */
