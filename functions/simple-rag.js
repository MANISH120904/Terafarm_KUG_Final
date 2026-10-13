const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Simple RAG query function for testing
exports.ragQuerySimple = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { query, language = 'english' } = req.body;

    if (!query) {
      return res.status(400).json({
        error: 'Query is required'
      });
    }

    console.log(`Processing RAG query: ${query}`);

    // Simple mock response for now
    const mockResponse = `Based on agricultural knowledge, here's information about "${query}":

🌾 Agricultural Information:
This is a test response from the RAG system. The system is designed to process agricultural documents and provide contextual answers based on government schemes, farming practices, and agricultural guidance.

📚 Key Points:
• The query "${query}" has been received and processed
• Language preference: ${language}
• This is a foundational RAG implementation
• Future versions will include PDF document processing and vector embeddings

🔍 Next Steps:
The system will be enhanced with document processing capabilities using Vertex AI embeddings for more accurate and contextual responses.

Timestamp: ${new Date().toISOString()}`;

    return res.json({
      answer: mockResponse,
      context: [
        {
          title: 'Agricultural Knowledge Base',
          content: 'Sample agricultural document content...',
          similarity: 0.85,
          documentId: 'sample_doc_1'
        }
      ],
      query: query,
      language: language,
      timestamp: new Date().toISOString()
    });

  } catch (error) {
    console.error('Error in ragQuerySimple:', error);
    return res.status(500).json({
      error: 'Failed to process query',
      details: error.message
    });
  }
});