const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Simple test function first
exports.helloWorld = functions.https.onRequest((request, response) => {
  response.json({
    message: 'Hello from Firebase Functions!',
    timestamp: new Date().toISOString()
  });
});

// Simple scheme data function
exports.getSchemeData = functions.https.onRequest(async (request, response) => {
  try {
    // Return hardcoded scheme data for now
    const schemes = [
      {
        name: 'PM-KISAN Samman Nidhi',
        amount: '₹6,000 per year',
        category: 'Direct Benefit Transfer',
        description: 'Financial support to farmers'
      },
      {
        name: 'Pradhan Mantri Fasal Bima Yojana',
        amount: 'Up to ₹2,00,000',
        category: 'Crop Insurance',
        description: 'Crop insurance coverage for farmers'
      }
    ];
    
    response.json({
      success: true,
      schemes: schemes,
      totalSchemes: schemes.length
    });
  } catch (error) {
    console.error('Error:', error);
    response.status(500).json({
      success: false,
      error: error.message
    });
  }
});