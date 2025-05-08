import Foundation
import StoreKit

class PaymentService: NSObject {
    static let shared = PaymentService()
    
    // Use the StoreKitService for in-app purchases
    private let storeKitService = StoreKitService.shared
    
    // Check if payments are available
    func canMakePayments() -> Bool {
        return !storeKitService.availableProducts.isEmpty
    }
    
    // Process a tip payment with the given amount index
    func processTip(at index: Int, completion: @escaping (Bool) -> Void) {
        guard index >= 0 && index < storeKitService.availableProducts.count else {
            completion(false)
            return
        }
        
        // Set up success and failure callbacks
        storeKitService.onPurchaseSuccess = {
            completion(true)
        }
        
        storeKitService.onPurchaseFailure = { _ in
            completion(false)
        }
        
        // Purchase the selected product
        let product = storeKitService.availableProducts[index]
        Task {
            await storeKitService.purchase(product)
        }
    }
} 
