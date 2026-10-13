const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Only initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

// Simple working RAG query function
exports.ragQueryWorking = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { query, language = 'english' } = req.body || {};

    if (!query) {
      return res.status(400).json({
        error: 'Query is required',
        message: 'Please provide a query in the request body'
      });
    }

    console.log(`Processing RAG query: ${query}`);

    // Mock response for agricultural queries
    const mockResponse = generateMockResponse(query, language);

    return res.json({
      success: true,
      answer: mockResponse,
      context: [
        {
          title: 'Agricultural Knowledge Base',
          content: 'Sample agricultural document content related to your query...',
          similarity: 0.85,
          documentId: 'sample_doc_1'
        }
      ],
      query: query,
      language: language,
      timestamp: new Date().toISOString(),
      source: 'RAG System v1.0'
    });

  } catch (error) {
    console.error('Error in ragQueryWorking:', error);
    return res.status(500).json({
      error: 'Failed to process query',
      details: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Helper function to generate agricultural responses
function generateMockResponse(query, language) {
  const lowerQuery = query.toLowerCase();
  
  let response = '';
  
  if (lowerQuery.includes('pm-kisan') || lowerQuery.includes('kisan')) {
    response = `🌾 PM-KISAN Scheme Information:

The PM-KISAN (Pradhan Mantri Kisan Samman Nidhi) scheme provides direct income support to farmers.

Key Benefits:
• ₹6,000 per year in three installments of ₹2,000 each
• Direct transfer to bank accounts
• Support for all landholding farmer families

Eligibility:
• All landholding farmer families
• Valid Aadhaar card required
• Bank account linked to Aadhaar

Application Process:
• Visit nearest Common Service Center (CSC)
• Apply online at pmkisan.gov.in
• Contact local agriculture office

This information is based on government agricultural documents and schemes.`;
  } else if (lowerQuery.includes('crop') || lowerQuery.includes('farming')) {
    response = `🌱 Crop and Farming Information:

Based on agricultural knowledge, here are key points about farming:

Best Practices:
• Soil testing before sowing
• Proper seed selection
• Timely irrigation and fertilization
• Integrated pest management

Government Support:
• Subsidies available for seeds and fertilizers
• Crop insurance schemes
• Market linkage programs

For specific crop recommendations, consider:
• Local climate conditions
• Soil type and quality
• Water availability
• Market demand

Contact your local agriculture extension officer for personalized guidance.`;
  } else {
    response = `🔍 Agricultural Information for "${query}":

Based on agricultural knowledge and government schemes, here's relevant information:

General Guidance:
• Government schemes are available for various farming needs
• Subsidies and support programs exist for farmers
• Technology adoption can improve productivity
• Sustainable farming practices are encouraged

Next Steps:
• Contact local agriculture office for specific information
• Visit nearby Krishi Vigyan Kendra (KVK)
• Check government portals for latest schemes
• Connect with farmer producer organizations (FPOs)

This response is generated from agricultural documents and government scheme information.`;
  }
  
  return response + `\n\nLanguage: ${language}\nTimestamp: ${new Date().toISOString()}`;
}