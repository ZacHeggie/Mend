// This is a sample server implementation for handling Stripe payment intents
// In a production environment, this would be deployed on your server
const express = require('express');
const bodyParser = require('body-parser');
const stripe = require('stripe')('sk_test_YOUR_SECRET_KEY'); // Add your test secret key here

const app = express();
const port = process.env.PORT || 3000;

app.use(bodyParser.json());

// Enable CORS
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
    next();
});

// Health check endpoint
app.get('/', (req, res) => {
    res.send('Mend Server is running');
});

// Endpoint to create a payment intent
app.post('/create-payment-intent', async (req, res) => {
    try {
        const { amount, currency, payment_method_id, description } = req.body;
        
        const paymentIntent = await stripe.paymentIntents.create({
            amount,
            currency: currency || 'gbp',
            payment_method: payment_method_id,
            confirm: true,
            confirmation_method: 'manual',
            description,
        });
        
        res.json({
            clientSecret: paymentIntent.client_secret,
            status: paymentIntent.status,
        });
    } catch (error) {
        console.error('Error creating payment intent:', error);
        res.status(500).json({ error: error.message });
    }
});

// Mock endpoint for testing
app.post('/mock-payment-intent', (req, res) => {
    // Simulate processing delay
    setTimeout(() => {
        res.json({
            clientSecret: 'pi_mock_client_secret_for_testing',
            status: 'succeeded',
        });
    }, 500);
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

app.listen(port, () => {
    console.log(`Mend server listening at http://localhost:${port}`);
});

// Note: For production, you would need to:
// 1. Use HTTPS
// 2. Add authentication
// 3. Add error handling and logging
// 4. Deploy on a robust hosting platform
// 5. Set up environment variables for your Stripe keys 