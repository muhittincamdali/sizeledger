import Foundation

/// One product in the bundled catalog.
public struct Product: Codable, Identifiable, Hashable, Sendable {
    public let id: Int
    public let name: String
    public let description: String
    public let priceCents: Int
    public let image: String
    public let stock: Int

    public var isInStock: Bool { stock > 0 }
}

/// The products in catalog.json, which ships inside the app bundle.
public struct Catalog: Codable, Sendable {
    public let version: String
    public let products: [Product]

    public static func load(from bundle: Bundle = .main) -> Catalog {
        guard let url = bundle.url(forResource: "catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(Catalog.self, from: data)
        else { return Catalog(version: "missing", products: []) }
        return catalog
    }

    public func products(matching query: String) -> [Product] {
        guard !query.isEmpty else { return products }
        return products.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
}

/// Formats prices stored in cents.
public enum PriceFormat {
    public static func string(cents: Int, currency: String = "EUR", locale: Locale = .current) -> String {
        let amount = Decimal(cents) / 100
        return amount.formatted(.currency(code: currency).locale(locale))
    }
}
