import ShopCore
import SwiftUI
#if SAMPLESHOP_2
import Analytics
#endif

@main
struct SampleShopApp: App {
    var body: some Scene {
        WindowGroup {
            CatalogView(catalog: Catalog.load())
        }
    }
}

struct CatalogView: View {
    let catalog: Catalog
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                #if SAMPLESHOP_2
                Image("Banner")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .listRowInsets(EdgeInsets())
                #endif
                ForEach(catalog.products(matching: query).prefix(300)) { product in
                    NavigationLink(value: product) {
                        ProductRow(product: product)
                    }
                }
            }
            .navigationTitle(Text("catalog.title"))
            .navigationDestination(for: Product.self) { product in
                ProductDetail(product: product)
            }
            .searchable(text: $query)
        }
    }
}

struct ProductRow: View {
    let product: Product

    var body: some View {
        HStack(spacing: 12) {
            Image(product.image)
                .resizable()
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name).font(.headline)
                Text(PriceFormat.string(cents: product.priceCents)).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

struct ProductDetail: View {
    let product: Product

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(product.image)
                    .resizable()
                    .aspectRatio(1, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Text(product.name).font(.title.bold())
                Text(PriceFormat.string(cents: product.priceCents)).font(.title3)
                Text(product.description)
                Label(product.isInStock ? "In stock: \(product.stock)" : "Sold out", systemImage: "shippingbox")
            }
            .padding()
        }
        #if SAMPLESHOP_2
        .onAppear { Analytics.shared.track("product_viewed", ["id": String(product.id)]) }
        #endif
    }
}
