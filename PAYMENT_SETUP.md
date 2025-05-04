# Setting Up Payments in Mend

This document outlines how to properly configure Apple Pay and Stripe for the Mend application.

## Prerequisites

1. An active Apple Developer Account
2. A Stripe account
3. A domain for your backend server (for domain verification)

## Apple Pay Configuration

### Step 1: Create a Merchant ID

1. Go to the [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list)
2. Click the "+" button to add a new identifier
3. Select "Merchant IDs" as the type
4. Enter a description (e.g., "Mend Payments")
5. Enter a unique identifier (e.g., "merchant.zacharyheggie")
6. Click "Continue" and then "Register"

### Step 2: Configure the Merchant ID

1. Select your newly created Merchant ID in the list
2. Click "Configure" next to Apple Pay
3. Add your domain name (e.g., "example.com") and click "Save"
4. Download the verification file and host it at `/.well-known/apple-developer-merchantid-domain-association` on your domain
5. Click "Verify" to confirm domain ownership

### Step 3: Create a Payment Processing Certificate

1. Still in the Merchant ID configuration page, click "Create Certificate" under "Payment Processing Certificate"
2. Follow the instructions to create a Certificate Signing Request (CSR) using Keychain Access
3. Upload the CSR file
4. Download your payment processing certificate

## Stripe Configuration

### Step 1: Create a Stripe Account

1. Sign up at [Stripe](https://stripe.com) if you don't have an account
2. Complete the account setup process

### Step 2: Configure Stripe for Apple Pay

1. In the Stripe Dashboard, go to "Settings" > "Payment methods"
2. Find Apple Pay and click "Set up"
3. Follow the instructions to upload your Apple Pay Payment Processing Certificate
4. Configure your domains for Apple Pay

### Step 3: Get API Keys

1. In the Stripe Dashboard, go to "Developers" > "API keys"
2. Note your publishable key (begins with `pk_`) and secret key (begins with `sk_`)
3. Use test keys for development and live keys for production

## App Configuration

### Step 1: Update Merchant ID

1. Open `StripePaymentService.swift`
2. Update the merchant identifier with your actual Merchant ID:
   ```swift
   let paymentRequest = StripeAPI.paymentRequest(withMerchantIdentifier: "merchant.zacharyheggie", country: "GB", currency: "GBP")
   ```

### Step 2: Update Stripe Keys

1. Open `StripePaymentService.swift` 
2. Replace the placeholder publishable key:
   ```swift
   private let stripePublishableKey = "pk_test_yourPublishableKeyHere"
   ```
3. Open `AppDelegate.swift`
4. Update the publishable key there as well:
   ```swift
   let publishableKey = "pk_test_yourPublishableKeyHere"
   ```

### Step 3: Update Backend URL

1. Open `StripePaymentService.swift`
2. Update the backend URL to point to your server:
   ```swift
   private let backendURL = URL(string: "https://your-backend-server.com/create-payment-intent")!
   ```

## Backend Server Configuration

### Step 1: Set Up Your Server

1. Install dependencies: 
   ```bash
   npm install express stripe
   ```
2. Update `server.js` with your Stripe secret key:
   ```javascript
   const stripe = require('stripe')('sk_test_yourStripeSecretKeyHere');
   ```
3. Set up a webhook secret for secure event handling:
   ```javascript
   const webhookSecret = 'whsec_yourWebhookSecretKey';
   ```
4. Deploy the server to a secure, HTTPS-enabled host

### Step 2: Configure Webhooks

1. In the Stripe Dashboard, go to "Developers" > "Webhooks"
2. Add an endpoint with the URL of your deployed server + "/webhook" path
3. Select events to listen for (at minimum: `payment_intent.succeeded`, `payment_intent.payment_failed`)
4. Note the signing secret and update your server code

## Testing

1. Use a real iOS device (Simulator does not support Apple Pay)
2. Add test cards to your Apple Wallet using the Stripe test card numbers
3. Process test payments to verify the integration works

## Going Live

Before going live, ensure that:

1. You've switched from test to live keys in both your app and server
2. Your Apple Pay merchant ID and payment certificate are properly configured
3. Your server is securely deployed with proper error handling
4. Your privacy policy is updated to reflect payment processing terms
5. You comply with all legal requirements for payment processing in your jurisdiction

## Troubleshooting

If you encounter issues:

1. Check Stripe Dashboard logs for any payment processing errors
2. Verify your Apple Developer account settings and certificates
3. Ensure your domain verification is still valid
4. Test with Stripe's testing tools to isolate the issue 