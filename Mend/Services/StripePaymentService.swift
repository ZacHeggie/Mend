import Foundation
import PassKit
import Stripe
import StripeApplePay

class StripePaymentService: NSObject, PKPaymentAuthorizationControllerDelegate, STPApplePayContextDelegate {
    static let shared = StripePaymentService()
    
    // Your merchant identifier
    private let merchantIdentifier = "merchant.zacharyheggie"
    
    // Your Stripe publishable key
    private let publishableKey = "pk_test_51RL0lnRxXxmdcCQQ9pMvbicL7kpTVDU37QEFrWyja1FiPcO1VkgrVyrmNO3VxYSnQd3tsv9Fn0CBHoVCKjLDd4F800tEZVrPnj"
    
    // Backend URL
    private let backendURL = "https://mend-backend-render.onrender.com"
    
    // Available tip amounts in GBP
    let tipAmounts: [NSDecimalNumber] = [
        NSDecimalNumber(string: "0.99"),
        NSDecimalNumber(string: "2.99"),
        NSDecimalNumber(string: "4.99"),
        NSDecimalNumber(string: "9.99")
    ]
    
    // Callbacks
    var onPaymentSuccess: (() -> Void)?
    var onPaymentFailure: ((Error?) -> Void)?
    
    // Keep track of the selected tip index
    private var selectedTipIndex: Int = 0
    
    // Initialize Stripe
    func initialize() {
        StripeAPI.defaultPublishableKey = publishableKey
    }
    
    // Check if Apple Pay is available
    func isApplePayAvailable() -> Bool {
        return StripeAPI.deviceSupportsApplePay() && PKPaymentAuthorizationController.canMakePayments()
    }
    
    // Present Apple Pay with the selected amount
    func presentApplePay(amount: NSDecimalNumber, completion: @escaping (Bool, Error?) -> Void) {
        guard isApplePayAvailable() else {
            completion(false, NSError(domain: "com.mend.applepay", code: 0, userInfo: [NSLocalizedDescriptionKey: "Apple Pay is not available on this device"]))
            return
        }
        
        // Find the index of the selected amount
        if let index = tipAmounts.firstIndex(of: amount) {
            selectedTipIndex = index
        } else {
            selectedTipIndex = 0 // Default to first amount if not found
        }
        
        // Create a payment request
        let paymentRequest = StripeAPI.paymentRequest(withMerchantIdentifier: merchantIdentifier, country: "GB", currency: "GBP")
        
        // Configure the payment request
        paymentRequest.paymentSummaryItems = [
            PKPaymentSummaryItem(label: "Mend Health Tip", amount: amount)
        ]
        
        // Create an Apple Pay context
        do {
            let applePayContext = STPApplePayContext(paymentRequest: paymentRequest, delegate: self)
            applePayContext?.presentApplePay(completion: {})
        } catch let error {
            completion(false, error)
        }
    }
    
    // MARK: - PKPaymentAuthorizationControllerDelegate
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss(completion: nil)
    }
    
    // Required by the protocol
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        // This won't be called since we're using STPApplePayContext
        completion(PKPaymentAuthorizationResult(status: .success, errors: nil))
    }
    
    // MARK: - STPApplePayContextDelegate
    
    func applePayContext(_ context: STPApplePayContext, didCreatePaymentMethod paymentMethod: STPPaymentMethod, paymentInformation: PKPayment, completion: @escaping STPIntentClientSecretCompletionBlock) {
        // Convert the amount from NSDecimalNumber to cents (pence) for Stripe
        let selectedAmount = tipAmounts[selectedTipIndex]
        let amountInPence = Int(selectedAmount.doubleValue * 100)
        
        // Call our backend to create a payment intent and get a client secret
        createPaymentIntent(amount: amountInPence, paymentMethodID: paymentMethod.stripeId) { result in
            switch result {
            case .success(let clientSecret):
                // Pass the client secret back to the Apple Pay context
                completion(clientSecret, nil)
            case .failure(let error):
                // Pass any errors back to the Apple Pay context
                completion(nil, error)
            }
        }
    }
    
    func applePayContext(_ context: STPApplePayContext, didCompleteWith status: STPPaymentStatus, error: Error?) {
        switch status {
        case .success:
            onPaymentSuccess?()
        case .error:
            onPaymentFailure?(error)
        case .userCancellation:
            onPaymentFailure?(nil)
        @unknown default:
            onPaymentFailure?(error)
        }
    }
    
    // Create a payment intent on your server
    private func createPaymentIntent(amount: Int, paymentMethodID: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard let url = URL(string: "\(backendURL)/api/payments/create-payment-intent") else {
            completion(.failure(NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": amount,
            "currency": "gbp",
            "payment_method_id": paymentMethodID,
            "description": "Support Mend - Tip"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let clientSecret = json["clientSecret"] as? String else {
                    completion(.failure(NSError(domain: "com.mend.payment", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])))
                    return
                }
                
                completion(.success(clientSecret))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
} 
