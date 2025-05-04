// This is a sample server implementation for handling Stripe payment intents
// In a production environment, this would be deployed on your server
const express = require('express');
const app = express();
const stripe = require('stripe')('sk_test_yourStripeSecretKeyHere');

// Parse JSON request body
app.use(express.json());

// Endpoint to create a payment intent
app.post('/create-payment-intent', async (req, res) => {
  try {
    // Extract payment information from request
    const { amount, currency } = req.body;
    
    // Validate the request
    if (!amount || !currency) {
      return res.status(400).json({ error: 'Missing required parameters' });
    }
    
    // Create a payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount, // amount in smallest currency unit (pennies for GBP)
      currency: currency.toLowerCase(),
      // In production, you might want to store additional metadata
      metadata: {
        integration_check: 'apple_pay',
        app_name: 'Mend',
      },
      payment_method_types: ['card'],
    });
    
    // Return the client secret to the client
    res.json({
      clientSecret: paymentIntent.client_secret,
    });
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).json({ error: 'Failed to create payment intent' });
  }
});

// Webhook to handle Stripe events
app.post('/webhook', express.raw({ type: 'application/json' }), async (req, res) => {
  const signature = req.headers['stripe-signature'];
  
  let event;
  
  try {
    // Verify the event came from Stripe using your webhook secret
    const webhookSecret = 'whsec_yourWebhookSecretKey';
    event = stripe.webhooks.constructEvent(req.body, signature, webhookSecret);
  } catch (error) {
    console.log(`Webhook signature verification failed: ${error.message}`);
    return res.status(400).send(`Webhook Error: ${error.message}`);
  }
  
  // Handle the event
  switch (event.type) {
    case 'payment_intent.succeeded':
      const paymentIntent = event.data.object;
      console.log(`PaymentIntent for ${paymentIntent.amount} ${paymentIntent.currency} was successful!`);
      // Then define and call a function to handle the successful payment
      // handlePaymentIntentSucceeded(paymentIntent);
      break;
    case 'payment_intent.payment_failed':
      // Handle failed payment
      break;
    default:
      // Unexpected event type
      console.log(`Unhandled event type ${event.type}.`);
  }
  
  // Return a 200 response to acknowledge receipt of the event
  res.json({ received: true });
});

// Start the server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

// Note: For production, you would need to:
// 1. Use HTTPS
// 2. Add authentication
// 3. Add error handling and logging
// 4. Deploy on a robust hosting platform
// 5. Set up environment variables for your Stripe keys 