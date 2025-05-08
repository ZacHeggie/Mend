import Foundation
import StoreKit

class StoreKitService: ObservableObject {
    static let shared = StoreKitService()
    
    // Product IDs matching the ones in App Store Connect
    private let tipProductIDs = [
        "mend_tip_099",
        "mend_tip_299",
        "mend_tip_499",
        "mend_tip_999"
    ]
    
    // Readable names for the tip amounts
    let tipAmounts = ["£0.99", "£2.99", "£4.99", "£9.99"]
    
    // Track available products returned by StoreKit
    @Published var availableProducts: [Product] = []
    @Published var isLoading = false
    
    // Success and failure callbacks
    var onPurchaseSuccess: (() -> Void)?
    var onPurchaseFailure: ((Error?) -> Void)?
    
    // Store transaction listener
    private var updateListenerTask: Task<Void, Error>?
    
    init() {
        // Set up a transaction listener as soon as the app launches
        updateListenerTask = listenForTransactions()
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // Load available products from App Store Connect
    @MainActor
    func loadProducts() async {
        isLoading = true
        
        do {
            // Request products from App Store
            let storeProducts = try await Product.products(for: tipProductIDs)
            
            // Sort products by price
            availableProducts = storeProducts.sorted { $0.price < $1.price }
            
            isLoading = false
        } catch {
            print("Failed to load products: \(error)")
            isLoading = false
            self.availableProducts = []
        }
    }
    
    // Purchase a product
    @MainActor
    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            
            await handlePurchaseResult(result)
        } catch {
            print("Purchase failed: \(error)")
            onPurchaseFailure?(error)
        }
    }
    
    // Handle the purchase result
    @MainActor
    private func handlePurchaseResult(_ result: StoreKit.Product.PurchaseResult) async {
        switch result {
        case .success(let verification):
            // Check if the transaction is verified
            switch verification {
            case .verified(let transaction):
                // Handle successful purchase
                print("Purchase was successful!")
                
                // Finish the transaction
                await transaction.finish()
                
                // Call success callback
                onPurchaseSuccess?()
                
            case .unverified(_, let error):
                // Handle unverified transaction
                print("Transaction unverified: \(error)")
                onPurchaseFailure?(error)
            }
            
        case .userCancelled:
            print("User cancelled purchase")
            onPurchaseFailure?(nil)
            
        case .pending:
            print("Purchase pending")
            
        @unknown default:
            print("Unknown purchase result")
            onPurchaseFailure?(nil)
        }
    }
    
    // Listen for transactions
    private func listenForTransactions() -> Task<Void, Error> {
        return Task.detached {
            // Iterate through any transactions that don't come from direct purchases
            for await result in Transaction.updates {
                await self.handleTransaction(from: result)
            }
        }
    }
    
    // Handle a transaction
    @MainActor
    private func handleTransaction(from result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Handle successful purchase
            print("Transaction was verified: \(transaction.productID)")
            
            // Finish the transaction
            await transaction.finish()
            
            // Refresh available products
            await self.loadProducts()
            
        case .unverified(_, let error):
            // Handle unverified transaction
            print("Transaction unverified: \(error)")
        }
    }
    
    // Get a product by ID
    func product(for id: String) -> Product? {
        return availableProducts.first(where: { $0.id == id })
    }
} 