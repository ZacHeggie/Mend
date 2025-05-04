const express = require('express');
const router = express.Router();
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

/**
 * Create a payment intent for Apple Pay
 * This endpoint generates a client secret for the iOS app to use
 */
router.post('/create-payment-intent', async (req, res) => {
  try {
    const { amount, currency = 'gbp', payment_method_id, description } = req.body;
    
    if (!amount || amount < 1) {
      return res.status(400).json({ error: 'Valid amount is required' });
    }
    
    // Create payment intent with the provided details
    const paymentIntent = await stripe.paymentIntents.create({
      amount, // Amount should be in pence (e.g. £0.99 = 99)
      currency,
      payment_method_types: ['card'],
      payment_method: payment_method_id,
      description: description || 'Mend Health Tip',
      metadata: {
        source: 'ios_app',
        tipType: 'donation'
      }
    });
    
    // Return the client secret to the iOS app
    res.json({
      clientSecret: paymentIntent.client_secret,
      status: paymentIntent.status
    });
    
  } catch (error) {
    console.error('Error creating payment intent:', error);
    res.status(500).json({ 
      error: error.message,
      type: error.type 
    });
  }
});

/**
 * Endpoint for health checks 
 */
router.get('/health', (req, res) => {
  res.json({ status: 'up', timestamp: new Date().toISOString() });
});

module.exports = router; 