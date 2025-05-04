# Mend Apple Pay Integration Setup

This document explains how to set up and test the Apple Pay integration in Mend.

## Prerequisites

- Xcode 15 or later
- iOS 16.0+ device with Apple Pay configured
- Swift Package Manager
- A Stripe account

## Project Structure

The Apple Pay integration uses the following components:

1. `StripePaymentService`: Handles all payment processing functionality
2. `TipJarView`: The UI for the tip jar feature
3. Server backend: A simple Express server for handling payment intents

## Setting Up for Development

### 1. Configure Your Stripe Account

1. Create a Stripe account if you don't have one already
2. Get your publishable key from the Stripe Dashboard
3. Update `StripePaymentService.swift` with your publishable key:

```swift
private let publishableKey = "pk_test_YOUR_PUBLISHABLE_KEY"
```

### 2. Configure the Backend Server

1. Install server dependencies:

```bash
npm install express body-parser stripe
```

2. Update the server.js file with your Stripe secret key:

```javascript
const stripe = require('stripe')('sk_test_YOUR_SECRET_KEY');
```

3. Start the server:

```bash
node server.js
```

### 3. Configure Your Apple Pay Merchant ID

1. In your Apple Developer account, create a Merchant ID
2. Configure the Merchant ID with your domain
3. Update the merchant identifier in `StripePaymentService.swift`:

```swift
private let merchantIdentifier = "merchant.your.identifier"
```

## Testing

For testing purposes, the app uses a mock payment flow that doesn't require a backend server.

1. Run the app on a device with Apple Pay configured
2. Navigate to Settings > Tip Jar
3. Select a tip amount
4. Confirm the payment in the Apple Pay sheet

## Production Deployment

For production use, modify the `createPaymentIntent` method in `StripePaymentService.swift` to use your actual backend endpoint by uncommenting the production code and removing the mock implementation.

## Troubleshooting

### Common Issues

- **No such module 'Stripe'**: Ensure the Swift packages are properly linked in your Xcode project
- **Apple Pay sheet not appearing**: Check your device has Apple Pay set up with a valid payment card
- **Payment failure**: Verify your publishable key is correct

### Debug Logging

The app includes debug logging to help diagnose issues:

```swift
print("Stripe initialized with publishable key")
```

Review the console output for any errors related to Stripe or Apple Pay. 