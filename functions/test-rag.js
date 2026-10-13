const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

// Simple test RAG function
exports.ragTest = functions.https.onRequest(async (req, res) => {
  try {
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { query } = req.body;

    if (!query) {
      return res.status(400).json({
        error: 'Query is required'
      });
    }

    return res.json({
      success: true,
      message: 'RAG system is working',
      query: query,
      answer: 'This is a test response from the RAG system. The system will process agricultural documents and provide contextual answers.',
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error in ragTest:', error);
    return res.status(500).json({
      error: 'Failed to process query',
      details: error.message
    });
  }
});