import Foundation
import PassKit

class PaymentService: NSObject {
    static let shared = PaymentService()
    
    // Available tip amounts
    let tipAmounts: [NSDecimalNumber] = [
        NSDecimalNumber(string: "0.99"),
        NSDecimalNumber(string: "2.99"),
        NSDecimalNumber(string: "4.99"),
        NSDecimalNumber(string: "9.99")
    ]
    
    // Check if Apple Pay is available on this device
    func canMakePayments() -> Bool {
        return PKPaymentAuthorizationController.canMakePayments()
    }
    
    // Process a tip payment with the given amount index
    func processTip(at index: Int, completion: @escaping (Bool) -> Void) {
        guard index >= 0 && index < tipAmounts.count else {
            completion(false)
            return
        }
        
        let amount = tipAmounts[index]
        let request = createPaymentRequest(with: amount)
        
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = self
        
        // Store completion handler for later use
        self.paymentCompletion = completion
        
        // Present the payment sheet
        controller.present { (presented: Bool) in
            if !presented {
                print("Failed to present payment controller")
                completion(false)
            }
        }
    }
    
    // Create the payment request for the specified amount
    private func createPaymentRequest(with amount: NSDecimalNumber) -> PKPaymentRequest {
        let request = PKPaymentRequest()
        
        // Set the merchant ID from your entitlements
        request.merchantIdentifier = "merchant.zacharyheggie"
        
        // Configure which payment networks are accepted
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        
        // Set the capabilities required - using threeDSecure (updated for iOS 17+)
        request.merchantCapabilities = .threeDSecure
        
        // Set the country and currency
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        // Create a payment summary item for the total
        let tipItem = PKPaymentSummaryItem(label: "Support Mend", amount: amount)
        let total = PKPaymentSummaryItem(label: "Mend Health", amount: amount)
        
        request.paymentSummaryItems = [tipItem, total]
        
        return request
    }
    
    // Callback to store payment result
    private var paymentCompletion: ((Bool) -> Void)?
}

// MARK: - PKPaymentAuthorizationControllerDelegate
extension PaymentService: PKPaymentAuthorizationControllerDelegate {
    // Payment was authorized by the user
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, 
                                        didAuthorizePayment payment: PKPayment, 
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // In a real-world scenario, you would send the payment token to your server
        // and process the payment with your payment processor
        
        // For this example, we'll simulate a successful payment
        print("Payment authorized")
        
        // Process payment with your backend service
        // processPaymentOnServer(token: payment.token) { result in
        //     if result.success {
        //         completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
        //     } else {
        //         completion(PKPaymentAuthorizationResult(status: .failure, errors: result.errors))
        //     }
        // }
        
        // For this example, just return success
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
    
    // Payment UI was dismissed
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        // Dismiss the payment sheet
        controller.dismiss {
            // Return result to the original caller
            if let completion = self.paymentCompletion {
                // In a real app, this would depend on the actual payment result
                completion(true)
            }
            self.paymentCompletion = nil
        }
    }
} 