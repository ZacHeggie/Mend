import Foundation
import Stripe
import StripeApplePay
import PassKit

class StripePaymentService: NSObject {
    static let shared = StripePaymentService()
    
    // Stripe publishable key - replace with your actual key
    private let stripePublishableKey = "pk_test_yourPublishableKeyHere"
    
    // Your backend URL for creating payment intents
    private let backendURL = URL(string: "https://your-backend-server.com/create-payment-intent")!
    
    // Available tip amounts in GBP
    let tipAmounts: [NSDecimalNumber] = [
        NSDecimalNumber(string: "0.99"),
        NSDecimalNumber(string: "2.99"),
        NSDecimalNumber(string: "4.99"),
        NSDecimalNumber(string: "9.99")
    ]
    
    // Setup Stripe when the service is initialized
    override init() {
        super.init()
        StripeAPI.defaultPublishableKey = stripePublishableKey
    }
    
    // Check if Apple Pay is available on this device
    func canMakePayments() -> Bool {
        return StripeAPI.deviceSupportsApplePay()
    }
    
    // Process a tip payment with Stripe through Apple Pay
    func processTip(at index: Int, completion: @escaping (Bool, Error?) -> Void) {
        guard index >= 0 && index < tipAmounts.count else {
            completion(false, NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid tip amount index"]))
            return
        }
        
        let amount = tipAmounts[index]
        let paymentRequest = createPaymentRequest(with: amount)
        
        // Create an Apple Pay context using the Stripe SDK
        guard let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self) else {
            let error = NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to create Apple Pay context"])
            completion(false, error)
            return
        }
        
        // Store completion handler for later use
        self.paymentCompletion = completion
        
        // Store the current context
        self.currentApplePayContext = applePayContext
    }
    
    // Present the Apple Pay sheet
    func presentApplePay(on viewController: UIViewController) {
        guard let applePayContext = currentApplePayContext else {
            if let completion = self.paymentCompletion {
                let error = NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "Apple Pay context not initialized"])
                completion(false, error)
            }
            return
        }
        
        applePayContext.presentApplePay(on: viewController)
    }
    
    // Create the Apple Pay payment request for the specified amount
    private func createPaymentRequest(with amount: NSDecimalNumber) -> PKPaymentRequest {
        // Use Stripe's helper method to create a payment request
        let paymentRequest = StripeAPI.paymentRequest(withMerchantIdentifier: "merchant.zacharyheggie", country: "GB", currency: "GBP")
        
        // Configure payment networks
        paymentRequest.supportedNetworks = [.visa, .masterCard, .amex]
        
        // Set merchant capabilities
        paymentRequest.merchantCapabilities = .capability3DS
        
        // Set payment summary items
        let tipItem = PKPaymentSummaryItem(label: "Support Mend", amount: amount, type: .final)
        let total = PKPaymentSummaryItem(label: "Mend Health", amount: amount, type: .final)
        
        paymentRequest.paymentSummaryItems = [tipItem, total]
        
        return paymentRequest
    }
    
    // Create a payment intent on your server
    private func createPaymentIntent(amount: NSDecimalNumber, currency: String, completion: @escaping (Result<String, Error>) -> Void) {
        // In a real app, you would send a request to your backend to create a payment intent
        // For this example, we'll simulate a successful response
        
        // Convert to pennies/cents (Stripe uses smallest currency unit)
        let amountInPennies = Int(amount.doubleValue * 100)
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let bodyData = try? JSONSerialization.data(withJSONObject: [
            "amount": amountInPennies,
            "currency": currency
        ])
        request.httpBody = bodyData
        
        // For this implementation, we'll simulate a successful response
        // In a real app, you would send this request to your server
        
        // Simulated client secret for testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            completion(.success("pi_simulated_client_secret"))
        }
    }
    
    // Callback to store payment result
    private var paymentCompletion: ((Bool, Error?) -> Void)?
    
    // Current Apple Pay context
    private var currentApplePayContext: STPApplePayContext?
}

// MARK: - STPApplePayContextDelegate
extension StripePaymentService: STPApplePayContextDelegate {
    // Payment was authorized by the user, confirm with Stripe
    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: STPPaymentMethod, paymentInformation: PKPayment, completion: @escaping STPIntentClientSecretCompletionBlock) {
        // Create a payment intent on your server
        let amount = context.paymentRequest.paymentSummaryItems.last?.amount ?? NSDecimalNumber(string: "0.00")
        let currency = context.paymentRequest.currencyCode.lowercased()
        
        createPaymentIntent(amount: amount, currency: currency) { result in
            switch result {
            case .success(let clientSecret):
                completion(clientSecret, nil)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    // Payment was completed
    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPPaymentStatus, error: Error?) {
        switch status {
        case .success:
            paymentCompletion?(true, nil)
        case .error:
            paymentCompletion?(false, error)
        case .userCancellation:
            paymentCompletion?(false, nil)
        @unknown default:
            paymentCompletion?(false, error)
        }
        
        // Reset state
        self.currentApplePayContext = nil
        self.paymentCompletion = nil
    }
} 