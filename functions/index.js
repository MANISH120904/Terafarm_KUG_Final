const functions = require('firebase-functions');
const admin = require('firebase-admin');
const pdfParse = require('pdf-parse');
const fetch = require('node-fetch');
const { GoogleAuth } = require('google-auth-library');

// Only initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Initialize Google Auth for Vertex AI
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform']
});

// Project configuration
const PROJECT_ID = 'terafarmsih'; // Replace with your actual project ID
const LOCATION = 'us-central1'; // Vertex AI location

// Your PDF URL
const PDF_URL = 'https://firebasestorage.googleapis.com/v0/b/terafarmsih.firebasestorage.app/o/Schemes_for_farmers%2FUltimate-Complete-Indian-Farmer-Schemes-Money-Revenue-Land-Crop-Based-2024-2025.pdf?alt=media&token=8d1f7165-7536-4225-9362-345b75785927';

// Function to download and parse PDF
async function downloadAndParsePDF(url) {
  try {
    console.log('📄 Downloading PDF from:', url);
    const response = await fetch(url);
    
    if (!response.ok) {
      throw new Error(`HTTP error! status: ${response.status}`);
    }
    
    const buffer = await response.buffer();
    console.log('📄 PDF downloaded, size:', buffer.length, 'bytes');
    
    const pdfData = await pdfParse(buffer);
    console.log('📄 PDF parsed, text length:', pdfData.text.length, 'characters');
    
    return pdfData.text;
  } catch (error) {
    console.error('❌ Error downloading/parsing PDF:', error);
    throw error;
  }
}

// Function to split text into chunks
function splitTextIntoChunks(text, chunkSize = 1000, overlap = 200) {
  const chunks = [];
  const words = text.split(/\s+/);
  
  for (let i = 0; i < words.length; i += chunkSize - overlap) {
    const chunk = words.slice(i, i + chunkSize).join(' ');
    if (chunk.trim().length > 0) {
      chunks.push({
        text: chunk.trim(),
        startIndex: i,
        endIndex: Math.min(i + chunkSize, words.length),
        id: `chunk_${i}`
      });
    }
  }
  
  console.log(`📝 Split text into ${chunks.length} chunks`);
  return chunks;
}

// Simple text similarity function (using word overlap)
function calculateTextSimilarity(text1, text2) {
  const words1 = text1.toLowerCase().split(/\s+/);
  const words2 = text2.toLowerCase().split(/\s+/);
  
  const set1 = new Set(words1);
  const set2 = new Set(words2);
  
  const intersection = new Set([...set1].filter(x => set2.has(x)));
  const union = new Set([...set1, ...set2]);
  
  return intersection.size / union.size; // Jaccard similarity
}

// Enhanced Vertex AI embedding function
async function generateEmbedding(text, taskType = 'RETRIEVAL_DOCUMENT') {
  try {
    const authClient = await auth.getClient();
    const endpoint = `https://${LOCATION}-aiplatform.googleapis.com/v1/projects/${PROJECT_ID}/locations/${LOCATION}/publishers/google/models/gemini-embedding-001:predict`;
    
    const requestBody = {
      instances: [
        {
          task_type: taskType,
          content: text.substring(0, 2048) // Limit to model's context window
        }
      ]
    };

    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${await authClient.getAccessToken()}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(requestBody)
    });

    if (!response.ok) {
      const errorText = await response.text();
      throw new Error(`Vertex AI API error: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    return result.predictions[0].embeddings.values;
  } catch (error) {
    console.error('Error generating embedding:', error);
    throw error;
  }
}

// Calculate cosine similarity between two embedding vectors
function calculateCosineSimilarity(vecA, vecB) {
  if (vecA.length !== vecB.length) {
    throw new Error('Vectors must have the same length');
  }
  
  let dotProduct = 0;
  let normA = 0;
  let normB = 0;
  
  for (let i = 0; i < vecA.length; i++) {
    dotProduct += vecA[i] * vecB[i];
    normA += vecA[i] * vecA[i];
    normB += vecB[i] * vecB[i];
  }
  
  return dotProduct / (Math.sqrt(normA) * Math.sqrt(normB));
}

// Extract structured metadata from agricultural text
function extractSchemeMetadata(text) {
  const metadata = {
    locations: [],
    farmSizes: [],
    crops: [],
    incomeRanges: [],
    eligibilityCriteria: []
  };

  const textLower = text.toLowerCase();

  // Extract locations (states, regions)
  const locationKeywords = ['state', 'region', 'district', 'all india', 'pan-india', 'nationwide'];
  const indianStates = ['andhra pradesh', 'assam', 'bihar', 'chhattisgarh', 'goa', 'gujarat', 'haryana', 'himachal pradesh', 'jharkhand', 'karnataka', 'kerala', 'madhya pradesh', 'maharashtra', 'manipur', 'meghalaya', 'mizoram', 'nagaland', 'odisha', 'punjab', 'rajasthan', 'sikkim', 'tamil nadu', 'telangana', 'tripura', 'uttar pradesh', 'uttarakhand', 'west bengal'];
  
  indianStates.forEach(state => {
    if (textLower.includes(state)) {
      metadata.locations.push(state);
    }
  });

  // Extract farm size criteria
  const sizePatterns = [
    /small\s+and\s+marginal\s+farmers/g,
    /land\s+holding\s+up\s+to\s+(\d+)\s+hectares?/g,
    /marginal\s+farmers/g,
    /small\s+farmers/g,
    /medium\s+farmers/g,
    /large\s+farmers/g
  ];

  sizePatterns.forEach(pattern => {
    const matches = textLower.match(pattern);
    if (matches) {
      metadata.farmSizes.push(...matches);
    }
  });

  // Extract crop types
  const cropKeywords = ['rice', 'wheat', 'cotton', 'sugarcane', 'maize', 'soybean', 'groundnut', 'pulses', 'oilseeds', 'horticulture', 'fruits', 'vegetables', 'cereals', 'millets'];
  cropKeywords.forEach(crop => {
    if (textLower.includes(crop)) {
      metadata.crops.push(crop);
    }
  });

  // Extract income criteria
  const incomePatterns = [
    /annual\s+income\s+up\s+to\s+rs\.?\s*(\d+(?:,\d+)*)/g,
    /income\s+limit\s+rs\.?\s*(\d+(?:,\d+)*)/g,
    /below\s+poverty\s+line/g
  ];

  incomePatterns.forEach(pattern => {
    const matches = textLower.match(pattern);
    if (matches) {
      metadata.incomeRanges.push(...matches);
    }
  });

  return metadata;
}

// Enhanced PDF processing function with embeddings and metadata extraction
exports.processPDFForRAGEnhanced = functions.runWith({
  timeoutSeconds: 540,
  memory: '2GB'
}).https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    console.log('🚀 Starting enhanced PDF processing with Vertex AI embeddings');
    
    // Download and parse PDF
    const pdfText = await downloadAndParsePDF(PDF_URL);
    
    // Split into chunks
    const chunks = splitTextIntoChunks(pdfText, 800, 150);
    
    console.log(`📝 Processing ${chunks.length} chunks with embeddings and metadata`);
    
    const processedChunks = [];
    
    // Process chunks in smaller batches to avoid API rate limits
    const batchSize = 5; // Reduced batch size for embedding API
    for (let i = 0; i < chunks.length; i += batchSize) {
      const batch = chunks.slice(i, i + batchSize);
      
      console.log(`📊 Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(chunks.length/batchSize)} with embeddings`);
      
      const batchPromises = batch.map(async (chunk, index) => {
        try {
          // Generate embedding for the chunk
          console.log(`🧠 Generating embedding for chunk ${chunk.id}`);
          const embedding = await generateEmbedding(chunk.text, 'RETRIEVAL_DOCUMENT');
          
          // Extract structured metadata
          const metadata = extractSchemeMetadata(chunk.text);
          
          const chunkData = {
            id: chunk.id,
            text: chunk.text,
            embedding: embedding, // Store the embedding vector
            metadata: metadata, // Store extracted eligibility criteria
            startIndex: chunk.startIndex,
            endIndex: chunk.endIndex,
            length: chunk.text.length,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'Ultimate-Complete-Indian-Farmer-Schemes-2024-2025.pdf',
            processingVersion: '2.0-with-embeddings'
          };
          
          // Store in Firestore (enhanced collection)
          await db.collection('agricultural_documents_enhanced').doc(chunkData.id).set(chunkData);
          
          return {
            id: chunkData.id,
            text: chunk.text.substring(0, 100) + '...',
            length: chunk.text.length,
            hasEmbedding: true,
            metadata: metadata
          };
        } catch (error) {
          console.error(`❌ Error processing chunk ${chunk.id}:`, error);
          // Fallback: store without embedding
          const chunkData = {
            id: chunk.id,
            text: chunk.text,
            embedding: null,
            metadata: extractSchemeMetadata(chunk.text),
            startIndex: chunk.startIndex,
            endIndex: chunk.endIndex,
            length: chunk.text.length,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'Ultimate-Complete-Indian-Farmer-Schemes-2024-2025.pdf',
            processingVersion: '2.0-embedding-failed',
            error: error.message
          };
          
          await db.collection('agricultural_documents_enhanced').doc(chunkData.id).set(chunkData);
          
          return {
            id: chunkData.id,
            text: chunk.text.substring(0, 100) + '...',
            length: chunk.text.length,
            hasEmbedding: false,
            error: error.message
          };
        }
      });
      
      const batchResults = await Promise.all(batchPromises);
      processedChunks.push(...batchResults.filter(result => result !== null));
      
      // Add delay between batches to respect API rate limits
      if (i + batchSize < chunks.length) {
        console.log('⏳ Waiting 2 seconds before next batch...');
        await new Promise(resolve => setTimeout(resolve, 2000));
      }
    }
    
    const successfulEmbeddings = processedChunks.filter(chunk => chunk.hasEmbedding).length;
    console.log(`✅ Successfully processed ${processedChunks.length} chunks (${successfulEmbeddings} with embeddings)`);
    
    // Store enhanced metadata
    await db.collection('rag_metadata').doc('pdf_processing_enhanced').set({
      pdfUrl: PDF_URL,
      totalChunks: processedChunks.length,
      chunksWithEmbeddings: successfulEmbeddings,
      chunksWithoutEmbeddings: processedChunks.length - successfulEmbeddings,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed',
      textLength: pdfText.length,
      processingVersion: '2.0-with-embeddings'
    });
    
    return res.json({
      success: true,
      message: 'PDF processed successfully with Vertex AI embeddings',
      totalChunks: processedChunks.length,
      chunksWithEmbeddings: successfulEmbeddings,
      chunksWithoutEmbeddings: processedChunks.length - successfulEmbeddings,
      textLength: pdfText.length,
      processedChunks: processedChunks.slice(0, 3), // Return first 3 as sample
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error in enhanced PDF processing:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Original PDF processing function (backward compatibility)
exports.processPDFForRAG = functions.runWith({
  timeoutSeconds: 540,
  memory: '2GB'
}).https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    console.log('🚀 Starting PDF processing for RAG system');
    
    // Download and parse PDF
    const pdfText = await downloadAndParsePDF(PDF_URL);
    
    // Split into chunks
    const chunks = splitTextIntoChunks(pdfText, 800, 150);
    
    console.log(`📝 Processing ${chunks.length} chunks for storage`);
    
    const processedChunks = [];
    
    // Store chunks in batches
    const batchSize = 10;
    for (let i = 0; i < chunks.length; i += batchSize) {
      const batch = chunks.slice(i, i + batchSize);
      
      console.log(`📊 Processing batch ${Math.floor(i/batchSize) + 1}/${Math.ceil(chunks.length/batchSize)}`);
      
      const batchPromises = batch.map(async (chunk, index) => {
        try {
          const chunkData = {
            id: chunk.id,
            text: chunk.text,
            startIndex: chunk.startIndex,
            endIndex: chunk.endIndex,
            length: chunk.text.length,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            source: 'Ultimate-Complete-Indian-Farmer-Schemes-2024-2025.pdf'
          };
          
          // Store in Firestore
          await db.collection('agricultural_documents').doc(chunkData.id).set(chunkData);
          
          return {
            id: chunkData.id,
            text: chunk.text.substring(0, 100) + '...',
            length: chunk.text.length
          };
        } catch (error) {
          console.error(`❌ Error processing chunk ${chunk.id}:`, error);
          return null;
        }
      });
      
      const batchResults = await Promise.all(batchPromises);
      processedChunks.push(...batchResults.filter(result => result !== null));
      
      // Add small delay between batches
      if (i + batchSize < chunks.length) {
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    }
    
    console.log(`✅ Successfully processed ${processedChunks.length} chunks`);
    
    // Store metadata
    await db.collection('rag_metadata').doc('pdf_processing').set({
      pdfUrl: PDF_URL,
      totalChunks: processedChunks.length,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed',
      textLength: pdfText.length
    });
    
    return res.json({
      success: true,
      message: 'PDF processed successfully for RAG system',
      totalChunks: processedChunks.length,
      textLength: pdfText.length,
      processedChunks: processedChunks.slice(0, 5), // Return first 5 as sample
      timestamp: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ Error in PDF processing:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Enhanced personalized RAG query function with embeddings and profile filtering
exports.personalizedRAGQuery = functions.runWith({
  timeoutSeconds: 180,
  memory: '1GB'
}).https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { 
      query, 
      userProfile = {}, 
      language = 'english', 
      limit = 5 
    } = req.body || {};

    if (!query) {
      return res.status(400).json({
        error: 'Query is required',
        message: 'Please provide a query in the request body'
      });
    }

    console.log(`🔍 Processing personalized RAG query: ${query}`);
    console.log(`👤 User profile:`, userProfile);
    
    // Generate embedding for the user query
    console.log('🧠 Generating query embedding...');
    let queryEmbedding;
    try {
      queryEmbedding = await generateEmbedding(query, 'RETRIEVAL_QUERY');
    } catch (embeddingError) {
      console.warn('⚠️ Failed to generate query embedding, falling back to text similarity:', embeddingError.message);
      queryEmbedding = null;
    }
    
    // Retrieve documents with profile-based filtering
    console.log('📊 Retrieving documents with profile filtering...');
    let documentsQuery = db.collection('agricultural_documents_enhanced');
    
    // Apply profile-based filters (one at a time due to Firestore limitations)
    if (userProfile.location && userProfile.location !== 'any') {
      console.log(`🗺️ Filtering by location: ${userProfile.location}`);
      documentsQuery = documentsQuery.where('metadata.locations', 'array-contains', userProfile.location.toLowerCase());
    } else if (userProfile.crops && userProfile.crops.length > 0) {
      console.log(`🌾 Filtering by crops: ${userProfile.crops.join(', ')}`);
      // Use array-contains for the first crop only to avoid Firestore limitation
      const primaryCrop = userProfile.crops[0].toLowerCase();
      documentsQuery = documentsQuery.where('metadata.crops', 'array-contains', primaryCrop);
    }
    
    const documentsSnapshot = await documentsQuery.limit(50).get(); // Get more docs for better filtering
    
    if (documentsSnapshot.empty) {
      // Fallback to unfiltered search if no matches with profile
      console.log('📊 No profile matches found, searching all documents...');
      const allDocsSnapshot = await db.collection('agricultural_documents_enhanced').limit(20).get();
      
      if (allDocsSnapshot.empty) {
        return res.status(404).json({
          success: false,
          error: 'No processed documents found',
          message: 'Please process the PDF first using /processPDFForRAGEnhanced endpoint'
        });
      }
      
      documentsSnapshot = allDocsSnapshot;
    }
    
    // Calculate similarities (embedding-based or text-based)
    console.log('🔢 Calculating similarities...');
    const similarities = [];
    
    documentsSnapshot.forEach(doc => {
      const data = doc.data();
      try {
        let similarity = 0;
        
        if (queryEmbedding && data.embedding) {
          // Use embedding-based similarity (cosine similarity)
          similarity = calculateCosineSimilarity(queryEmbedding, data.embedding);
        } else {
          // Fallback to text-based similarity
          similarity = calculateTextSimilarity(query, data.text);
        }
        
        // Apply profile relevance boost
        let profileBoost = 1.0;
        if (userProfile.location && data.metadata.locations.includes(userProfile.location.toLowerCase())) {
          profileBoost += 0.2;
        }
        if (userProfile.crops && userProfile.crops.some(crop => data.metadata.crops.includes(crop.toLowerCase()))) {
          profileBoost += 0.3;
        }
        if (userProfile.farmSize && data.metadata.farmSizes.some(size => size.includes('small') || size.includes('marginal'))) {
          if (userProfile.farmSize === 'small' || userProfile.farmSize === 'marginal') {
            profileBoost += 0.2;
          }
        }
        
        similarities.push({
          id: data.id,
          text: data.text,
          similarity: similarity * profileBoost,
          originalSimilarity: similarity,
          profileBoost: profileBoost,
          metadata: data.metadata,
          source: data.source,
          hasEmbedding: !!data.embedding
        });
      } catch (error) {
        console.error(`❌ Error calculating similarity for ${doc.id}:`, error);
      }
    });
    
    // Sort by similarity and get top results
    similarities.sort((a, b) => b.similarity - a.similarity);
    const topResults = similarities.slice(0, limit);
    
    console.log(`📋 Found ${topResults.length} relevant chunks (${topResults.filter(r => r.hasEmbedding).length} with embeddings)`);
    
    // Generate personalized response
    const answer = generatePersonalizedResponse(query, topResults, language, userProfile);
    
    return res.json({
      success: true,
      answer: answer,
      context: topResults.map(result => ({
        text: result.text.substring(0, 300) + '...',
        similarity: Math.round(result.similarity * 100) / 100,
        originalSimilarity: Math.round(result.originalSimilarity * 100) / 100,
        profileBoost: Math.round(result.profileBoost * 100) / 100,
        metadata: result.metadata,
        source: result.source,
        hasEmbedding: result.hasEmbedding
      })),
      query: query,
      userProfile: userProfile,
      language: language,
      totalDocuments: documentsSnapshot.size,
      relevantChunks: topResults.length,
      embeddingUsed: !!queryEmbedding,
      timestamp: new Date().toISOString(),
      source: 'Personalized RAG System v2.0'
    });
    
  } catch (error) {
    console.error('❌ Error in personalized RAG query:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Text-based RAG query function (backward compatibility)
exports.ragQuery = functions.runWith({
  timeoutSeconds: 180,
  memory: '1GB'
}).https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { query, language = 'english', limit = 5 } = req.body || {};

    if (!query) {
      return res.status(400).json({
        error: 'Query is required',
        message: 'Please provide a query in the request body'
      });
    }

    console.log(`🔍 Processing text-based RAG query: ${query}`);
    
    // Retrieve all stored document chunks
    console.log('📊 Retrieving stored document chunks...');
    const documentsSnapshot = await db.collection('agricultural_documents').get();
    
    if (documentsSnapshot.empty) {
      return res.status(404).json({
        success: false,
        error: 'No processed documents found',
        message: 'Please process the PDF first using /processPDFForRAG endpoint'
      });
    }
    
    // Calculate text similarities
    console.log('🔢 Calculating text similarities...');
    const similarities = [];
    
    documentsSnapshot.forEach(doc => {
      const data = doc.data();
      try {
        const similarity = calculateTextSimilarity(query, data.text);
        similarities.push({
          id: data.id,
          text: data.text,
          similarity: similarity,
          source: data.source
        });
      } catch (error) {
        console.error(`❌ Error calculating similarity for ${doc.id}:`, error);
      }
    });
    
    // Sort by similarity and get top results
    similarities.sort((a, b) => b.similarity - a.similarity);
    const topResults = similarities.slice(0, limit);
    
    console.log(`📋 Found ${topResults.length} relevant chunks`);
    
    // Generate response using the context
    const answer = generateContextualResponse(query, topResults, language);
    
    return res.json({
      success: true,
      answer: answer,
      context: topResults.map(result => ({
        text: result.text.substring(0, 300) + '...',
        similarity: Math.round(result.similarity * 100) / 100,
        source: result.source
      })),
      query: query,
      language: language,
      totalDocuments: documentsSnapshot.size,
      relevantChunks: topResults.length,
      timestamp: new Date().toISOString(),
      source: 'Text-based RAG System'
    });
    
  } catch (error) {
    console.error('❌ Error in RAG query:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Enhanced personalized response generation
function generatePersonalizedResponse(query, contextChunks, language, userProfile) {
  const queryLower = query.toLowerCase();
  const hasProfile = userProfile && (userProfile.location || userProfile.crops || userProfile.farmSize || userProfile.incomeRange);
  
  let profileInfo = '';
  if (hasProfile) {
    profileInfo = `\n\n👤 Based on your profile:\n`;
    if (userProfile.location && userProfile.location !== 'any') {
      profileInfo += `• Location: ${userProfile.location}\n`;
    }
    if (userProfile.farmSize) {
      profileInfo += `• Farm Size: ${userProfile.farmSize} farmer\n`;
    }
    if (userProfile.crops && userProfile.crops.length > 0) {
      profileInfo += `• Crops: ${userProfile.crops.join(', ')}\n`;
    }
    if (userProfile.incomeRange) {
      profileInfo += `• Income Range: ${userProfile.incomeRange}\n`;
    }
  }
  
  // Use actual context from retrieved chunks if available
  if (contextChunks && contextChunks.length > 0 && contextChunks[0].similarity > 0.1) {
    const contextText = contextChunks.slice(0, 2).map(chunk => chunk.text).join('\n\n');
    const relevanceScore = Math.round(contextChunks[0]?.similarity * 100);
    const hasEmbeddings = contextChunks.some(chunk => chunk.hasEmbedding);
    
    let eligibilityInfo = '';
    const relevantMetadata = contextChunks[0].metadata;
    if (relevantMetadata && hasProfile) {
      eligibilityInfo = `\n\n✅ Eligibility Check:\n`;
      
      // Location eligibility
      if (userProfile.location && relevantMetadata.locations.length > 0) {
        const isLocationEligible = relevantMetadata.locations.includes(userProfile.location.toLowerCase()) || 
                                  relevantMetadata.locations.some(loc => loc.includes('all india') || loc.includes('nationwide'));
        eligibilityInfo += `• Location: ${isLocationEligible ? '✅ Eligible' : '❓ Check local availability'}\n`;
      }
      
      // Farm size eligibility  
      if (userProfile.farmSize && relevantMetadata.farmSizes.length > 0) {
        const isSizeEligible = relevantMetadata.farmSizes.some(size => 
          size.includes(userProfile.farmSize.toLowerCase()) || 
          (userProfile.farmSize === 'small' && size.includes('marginal'))
        );
        eligibilityInfo += `• Farm Size: ${isSizeEligible ? '✅ Eligible' : '❓ Check size criteria'}\n`;
      }
      
      // Crop eligibility
      if (userProfile.crops && userProfile.crops.length > 0 && relevantMetadata.crops.length > 0) {
        const eligibleCrops = userProfile.crops.filter(crop => 
          relevantMetadata.crops.includes(crop.toLowerCase())
        );
        if (eligibleCrops.length > 0) {
          eligibilityInfo += `• Crops: ✅ Eligible for ${eligibleCrops.join(', ')}\n`;
        }
      }
    }
    
    return `🔍 Personalized Agricultural Information:\n\n${contextText.substring(0, 1200)}${profileInfo}${eligibilityInfo}\n\nRelevance Score: ${relevanceScore}% ${hasEmbeddings ? '(AI Enhanced)' : '(Text Match)'}\n\n💡 Recommendation: Contact your local agriculture office or visit government portals for application procedures.\n\nThis information is extracted from the official Ultimate Complete Indian Farmer Schemes document with personalized filtering.`;
  }
  
  // Fallback to profile-aware general responses
  return generateProfileAwareResponse(query, language, userProfile);
}

// Profile-aware fallback response generation
function generateProfileAwareResponse(query, language, userProfile) {
  const queryLower = query.toLowerCase();
  const hasProfile = userProfile && (userProfile.location || userProfile.crops || userProfile.farmSize);
  
  let profileContext = '';
  if (hasProfile) {
    profileContext = `\n\n👤 For your profile (${userProfile.farmSize || 'general'} farmer`;
    if (userProfile.location && userProfile.location !== 'any') {
      profileContext += ` in ${userProfile.location}`;
    }
    if (userProfile.crops && userProfile.crops.length > 0) {
      profileContext += ` growing ${userProfile.crops.join(', ')}`;
    }
    profileContext += '):';
  }
  
  let response = '';
  
  if (queryLower.includes('pm kisan') || queryLower.includes('pm-kisan')) {
    response = `🌾 PM-KISAN Scheme - Personalized Information:\n\nThe PM-KISAN (Pradhan Mantri Kisan Samman Nidhi) scheme provides direct income support.\n\nKey Benefits:\n• ₹6,000 per year in three installments of ₹2,000 each\n• Direct transfer to bank accounts\n• Support for all landholding farmer families\n\nEligibility:\n• All landholding farmer families\n• Valid Aadhaar card required\n• Bank account linked to Aadhaar${profileContext}\n• ✅ You are likely eligible for PM-KISAN\n• Priority processing for small and marginal farmers\n• Additional state-specific benefits may apply`;
  } else if (queryLower.includes('crop insurance') || queryLower.includes('pmfby')) {
    response = `🛡️ Crop Insurance - Tailored Information:\n\nThe Pradhan Mantri Fasal Bima Yojana (PMFBY) provides comprehensive coverage.${profileContext}`;
    
    if (userProfile.crops && userProfile.crops.length > 0) {
      response += `\n• ✅ Coverage available for: ${userProfile.crops.join(', ')}\n• Premium rates vary by crop and season`;
    }
    
    response += `\n\nKey Features:\n• Coverage for all stages of crop cycle\n• Low premium rates (2% for Kharif, 1.5% for Rabi)\n• Quick claim settlement process\n• Natural disasters and pest coverage`;
  } else if (queryLower.includes('loan') || queryLower.includes('credit')) {
    response = `💰 Agricultural Credit - Customized Information:${profileContext}`;
    
    if (userProfile.farmSize === 'small' || userProfile.farmSize === 'marginal') {
      response += `\n• ✅ Priority lending for small/marginal farmers\n• Lower interest rates available\n• Simplified documentation process`;
    }
    
    response += `\n\nKisan Credit Card (KCC):\n• Flexible credit facility\n• Lower interest rate\n• No collateral for loans up to ₹1.6 lakh\n• Quick processing within 15 days`;
  } else {
    response = `🔍 Agricultural Information for "${query}":${profileContext}\n\nPersonalized Recommendations:\n• Multiple government schemes match your profile\n• Priority access to certain programs\n• State-specific additional benefits available\n\nNext Steps:\n• Contact local agriculture office\n• Visit nearest Krishi Vigyan Kendra (KVK)\n• Apply online through government portals`;
  }
  
  response += `\n\nThis personalized response considers your farmer profile and is based on official agricultural schemes documentation.`;
  
  return response;
}

// Function to generate contextual response (backward compatibility)
function generateContextualResponse(query, contextChunks, language) {
  const queryLower = query.toLowerCase();
  
  // Use actual context from retrieved chunks if available
  if (contextChunks && contextChunks.length > 0 && contextChunks[0].similarity > 0.1) {
    const contextText = contextChunks.slice(0, 2).map(chunk => chunk.text).join('\n\n');
    const relevanceScore = Math.round(contextChunks[0]?.similarity * 100);
    
    return `🔍 Information from Agricultural Documents:\n\nBased on the retrieved content from Indian farmer schemes documentation:\n\n${contextText.substring(0, 1000)}\n\nRelevance Score: ${relevanceScore}%\n\nFor more specific information, please contact your local agriculture office or visit government portals.\n\nThis information is extracted from the official Ultimate Complete Indian Farmer Schemes document.`;
  }
  
  // Fallback response patterns for common queries
  let response = '';
  
  if (queryLower.includes('pm kisan') || queryLower.includes('pm-kisan')) {
    response = `🌾 PM-KISAN Scheme Information:\n\nBased on the agricultural schemes document, the PM-KISAN (Pradhan Mantri Kisan Samman Nidhi) scheme provides direct income support to farmers.\n\nKey Benefits:\n• ₹6,000 per year in three installments of ₹2,000 each\n• Direct transfer to bank accounts\n• Support for all landholding farmer families\n\nEligibility:\n• All landholding farmer families\n• Valid Aadhaar card required\n• Bank account linked to Aadhaar\n\nApplication Process:\n• Visit nearest Common Service Center (CSC)\n• Apply online at pmkisan.gov.in\n• Contact local agriculture office`;
  } else if (queryLower.includes('crop insurance') || queryLower.includes('pmfby')) {
    response = `🛡️ Crop Insurance Information:\n\nThe Pradhan Mantri Fasal Bima Yojana (PMFBY) provides comprehensive crop insurance coverage.\n\nKey Features:\n• Coverage for all stages of crop cycle\n• Low premium rates (2% for Kharif, 1.5% for Rabi)\n• Quick claim settlement process\n• Coverage for natural disasters and pest attacks\n\nApplication:\n• Apply through your bank\n• Must be done before sowing season\n• Required documents: Land records, bank account details`;
  } else if (queryLower.includes('loan') || queryLower.includes('credit')) {
    response = `💰 Agricultural Credit Information:\n\nMultiple loan schemes are available for farmers:\n\nKisan Credit Card (KCC):\n• Flexible credit facility\n• Lower interest rates\n• No collateral for loans up to ₹1.6 lakh\n\nApplication Process:\n• Visit nearest bank branch\n• Submit land documents and identity proof\n• Quick processing within 15 days`;
  } else {
    response = `🔍 Agricultural Information for "${query}":\n\nBased on the comprehensive Indian farmer schemes document, here's relevant information:\n\nGeneral Guidance:\n• Multiple government schemes are available for farmers\n• Subsidies and support programs exist for various farming needs\n• Technology adoption initiatives are being promoted\n• Direct benefit transfer mechanisms are in place\n\nRecommendation:\n• Contact your local agriculture office for specific guidance\n• Visit nearest Krishi Vigyan Kendra (KVK) for technical support\n• Check government portals for latest scheme updates`;
  }
  
  response += `\n\nThis information is extracted from the official Ultimate Complete Indian Farmer Schemes document.`;
  
  return response;
}

// Simple working RAG query function (backup)
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

    console.log(`Processing simple RAG query: ${query}`);

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
    console.error('Error in simple RAG query:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

// Farmer profile management function
exports.manageFarmerProfile = functions.https.onRequest(async (req, res) => {
  try {
    // Set CORS headers
    res.set('Access-Control-Allow-Origin', '*');
    res.set('Access-Control-Allow-Methods', 'GET, POST, PUT, OPTIONS');
    res.set('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }

    const { action, userId, profile } = req.body || {};

    if (!userId) {
      return res.status(400).json({
        error: 'User ID is required',
        message: 'Please provide a userId in the request body'
      });
    }

    switch (action) {
      case 'create':
      case 'update':
        if (!profile) {
          return res.status(400).json({
            error: 'Profile data is required',
            message: 'Please provide profile information'
          });
        }

        const profileData = {
          userId: userId,
          location: profile.location || 'any',
          farmSize: profile.farmSize || 'general', // small, marginal, medium, large
          crops: profile.crops || [], // array of crop names
          incomeRange: profile.incomeRange || 'not-specified',
          landArea: profile.landArea || null, // in hectares
          irrigationAccess: profile.irrigationAccess || false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          createdAt: action === 'create' ? admin.firestore.FieldValue.serverTimestamp() : null
        };

        // Remove null createdAt for updates
        if (action === 'update') {
          delete profileData.createdAt;
        }

        await db.collection('farmer_profiles').doc(userId).set(profileData, { merge: true });

        return res.json({
          success: true,
          message: `Profile ${action}d successfully`,
          profile: profileData,
          timestamp: new Date().toISOString()
        });

      case 'get':
        const profileDoc = await db.collection('farmer_profiles').doc(userId).get();
        
        if (!profileDoc.exists) {
          return res.status(404).json({
            success: false,
            error: 'Profile not found',
            message: 'No profile exists for this user ID'
          });
        }

        return res.json({
          success: true,
          profile: profileDoc.data(),
          timestamp: new Date().toISOString()
        });

      case 'delete':
        await db.collection('farmer_profiles').doc(userId).delete();
        
        return res.json({
          success: true,
          message: 'Profile deleted successfully',
          timestamp: new Date().toISOString()
        });

      default:
        return res.status(400).json({
          error: 'Invalid action',
          message: 'Action must be one of: create, update, get, delete'
        });
    }

  } catch (error) {
    console.error('Error managing farmer profile:', error);
    return res.status(500).json({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

function generateMockResponse(query, language) {
  const queryLower = query.toLowerCase();
  
  if (queryLower.includes('pm kisan') || queryLower.includes('pm-kisan')) {
    return `🌾 PM-KISAN Scheme Information:\n\nThe PM-KISAN (Pradhan Mantri Kisan Samman Nidhi) scheme provides direct income support to farmers.\n\nKey Benefits:\n• ₹6,000 per year in three installments of ₹2,000 each\n• Direct transfer to bank accounts\n• Support for all landholding farmer families\n\nEligibility:\n• All landholding farmer families\n• Valid Aadhaar card required\n• Bank account linked to Aadhaar\n\nApplication Process:\n• Visit nearest Common Service Center (CSC)\n• Apply online at pmkisan.gov.in\n• Contact local agriculture office\n\nThis information is based on government agricultural documents and schemes.\n\nLanguage: ${language}\nTimestamp: ${new Date().toISOString()}`;
  } else if (queryLower.includes('crop') || queryLower.includes('farming') || queryLower.includes('agriculture')) {
    return `🔍 Agricultural Information for "${query}":\n\nBased on agricultural knowledge and government schemes, here's relevant information:\n\nGeneral Guidance:\n• Government schemes are available for various farming needs\n• Subsidies and support programs exist for farmers\n• Technology adoption can improve productivity\n• Sustainable farming practices are encouraged\n\nNext Steps:\n• Contact local agriculture office for specific information\n• Visit nearby Krishi Vigyan Kendra (KVK)\n• Check government portals for latest schemes\n• Connect with farmer producer organizations (FPOs)\n\nThis response is generated from agricultural documents and government scheme information.\n\nLanguage: ${language}\nTimestamp: ${new Date().toISOString()}`;
  } else {
    return `🤖 Agricultural Assistant Response:\n\nI understand you're asking about: "${query}"\n\nWhile I have access to comprehensive agricultural schemes and farming information, I need more specific details to provide targeted guidance.\n\nHow I can help:\n• Information about government schemes (PM-KISAN, crop insurance, loans)\n• Farming best practices and techniques\n• Subsidies and financial support programs\n• Agricultural technology and innovation\n\nPlease ask me about specific schemes, crops, or farming challenges for detailed assistance.\n\nLanguage: ${language}\nTimestamp: ${new Date().toISOString()}`;
  }
}

// ====================================================================
// WEATHER NOTIFICATION FUNCTIONS
// ====================================================================

const axios = require('axios');

// Weather API Configuration
// IMPORTANT: Get your FREE OpenWeatherMap API key from: https://openweathermap.org/api
// Sign up for free at: https://home.openweathermap.org/users/sign_up
// Then replace 'YOUR_OPENWEATHERMAP_API_KEY' below with your actual API key
const WEATHER_API_KEY = process.env.OPENWEATHER_API_KEY || 'YOUR_OPENWEATHERMAP_API_KEY';
const DEFAULT_LOCATION = {
  lat: 28.6139, // Delhi, India (fallback if user has no location)
  lon: 77.2090,
  name: 'Delhi'
};

/**
 * Fetches current weather data from OpenWeatherMap API
 */
async function fetchWeatherData(lat, lon) {
  try {
    // Check if API key is configured
    if (WEATHER_API_KEY === 'YOUR_OPENWEATHERMAP_API_KEY') {
      console.warn('⚠️ Using demo weather data - Please configure OPENWEATHER_API_KEY');
      // Return demo data for testing
      return {
        temperature: 25.5,
        feelsLike: 26.0,
        condition: 'clear sky',
        humidity: 65,
        windSpeed: 3.5,
        location: DEFAULT_LOCATION.name,
        icon: 'clear',
        timestamp: new Date().toISOString(),
      };
    }

    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&appid=${WEATHER_API_KEY}&units=metric`;
    const response = await axios.get(url);
    
    const data = response.data;
    return {
      temperature: Math.round(data.main.temp * 10) / 10,
      feelsLike: Math.round(data.main.feels_like * 10) / 10,
      condition: data.weather[0].description,
      humidity: data.main.humidity,
      windSpeed: data.wind.speed,
      location: data.name,
      icon: data.weather[0].main.toLowerCase(),
      timestamp: new Date().toISOString(),
    };
  } catch (error) {
    console.error('Error fetching weather:', error.message);
    // Return demo data on error so function doesn't fail
    return {
      temperature: 25.0,
      feelsLike: 25.5,
      condition: 'weather data unavailable',
      humidity: 60,
      windSpeed: 2.0,
      location: 'Unknown',
      icon: 'clouds',
      timestamp: new Date().toISOString(),
    };
  }
}

/**
 * Fetches 5-day forecast data from OpenWeatherMap API
 * Returns tomorrow's weather forecast
 */
async function fetchTomorrowForecast(lat, lon) {
  try {
    if (WEATHER_API_KEY === 'YOUR_OPENWEATHERMAP_API_KEY') {
      console.warn('⚠️ Using demo forecast data - Please configure OPENWEATHER_API_KEY');
      return {
        temperature: 27.5,
        condition: 'partly cloudy',
        humidity: 60,
        windSpeed: 4.0,
        rainProbability: 20,
      };
    }

    const url = `https://api.openweathermap.org/data/2.5/forecast?lat=${lat}&lon=${lon}&appid=${WEATHER_API_KEY}&units=metric&cnt=16`;
    const response = await axios.get(url);
    
    // Get forecasts for tomorrow (skip first 8 items = 24 hours)
    const tomorrow = response.data.list.slice(8, 16);
    
    if (tomorrow.length === 0) {
      return null;
    }

    // Average tomorrow's data
    const avgTemp = tomorrow.reduce((sum, item) => sum + item.main.temp, 0) / tomorrow.length;
    const maxTemp = Math.max(...tomorrow.map(item => item.main.temp));
    const minTemp = Math.min(...tomorrow.map(item => item.main.temp));
    const avgHumidity = tomorrow.reduce((sum, item) => sum + item.main.humidity, 0) / tomorrow.length;
    const avgWind = tomorrow.reduce((sum, item) => sum + item.wind.speed, 0) / tomorrow.length;
    
    // Get most common weather condition
    const conditions = tomorrow.map(item => item.weather[0].description);
    const mostCommon = conditions.sort((a,b) =>
      conditions.filter(v => v === a).length - conditions.filter(v => v === b).length
    ).pop();

    // Calculate rain probability (percentage of forecasts with rain)
    const rainCount = tomorrow.filter(item => 
      item.weather[0].main.toLowerCase().includes('rain')
    ).length;
    const rainProbability = Math.round((rainCount / tomorrow.length) * 100);

    return {
      temperature: Math.round(avgTemp * 10) / 10,
      maxTemp: Math.round(maxTemp * 10) / 10,
      minTemp: Math.round(minTemp * 10) / 10,
      condition: mostCommon,
      humidity: Math.round(avgHumidity),
      windSpeed: Math.round(avgWind * 10) / 10,
      rainProbability: rainProbability,
    };
  } catch (error) {
    console.error('Error fetching forecast:', error.message);
    return null;
  }
}

/**
 * Gets all users with their FCM tokens and locations from Firestore
 */
async function getUsersWithLocations() {
  try {
    console.log('🔍 Fetching all users from Firestore...');
    
    // Fetch ALL users (Firestore doesn't support where('field', '!=', null))
    const usersSnapshot = await admin.firestore()
      .collection('users')
      .get();

    console.log(`📊 Total documents in users collection: ${usersSnapshot.size}`);

    const users = [];
    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      
      // Log first few users for debugging
      if (users.length < 3) {
        console.log(`👤 Sample user ${doc.id}:`, {
          hasFcmToken: !!userData.fcmToken,
          hasLocation: !!userData.location,
          fields: Object.keys(userData),
        });
      }
      
      // Filter for users with valid FCM token
      if (userData.fcmToken && typeof userData.fcmToken === 'string' && userData.fcmToken.length > 0) {
        users.push({
          userId: doc.id,
          token: userData.fcmToken,
          location: userData.location || null,
          name: userData.name || userData.displayName || 'User',
        });
      }
    });

    console.log(`📱 Found ${users.length} users with FCM tokens out of ${usersSnapshot.size} total users`);
    return users;
  } catch (error) {
    console.error('❌ Error fetching users:', error);
    console.error('❌ Stack trace:', error.stack);
    return [];
  }
}

/**
 * Determines if weather conditions warrant an alert
 */
function shouldAlert(weather) {
  return (
    weather.temperature > 35 || // Heat alert
    weather.temperature < 5 ||  // Cold alert
    weather.windSpeed > 15 ||   // High wind
    weather.icon.includes('rain') ||
    weather.icon.includes('thunderstorm') ||
    weather.icon.includes('snow')
  );
}

/**
 * Creates formatted weather message
 */
function createWeatherMessage(weather) {
  const emoji = getWeatherEmoji(weather.icon);
  
  let message = `${emoji} ${weather.temperature}°C (feels like ${weather.feelsLike}°C)\n`;
  message += `☁️ ${weather.condition.charAt(0).toUpperCase() + weather.condition.slice(1)}\n`;
  message += `💧 Humidity: ${weather.humidity}%\n`;
  message += `💨 Wind: ${weather.windSpeed} m/s`;
  
  return message;
}

/**
 * Creates personalized weather message with today + tomorrow forecast
 */
function createPersonalizedWeatherMessage(current, tomorrow, locationName) {
  const emoji = getWeatherEmoji(current.icon);
  
  let message = `${emoji} Weather for ${locationName}\n\n`;
  message += `📍 Today: ${current.temperature}°C (feels like ${current.feelsLike}°C)\n`;
  message += `   ${current.condition}\n`;
  message += `   💧 Humidity: ${current.humidity}%\n`;
  message += `   💨 Wind: ${current.windSpeed} m/s\n`;

  if (tomorrow) {
    message += `\n🔮 Tomorrow: ${tomorrow.temperature}°C (${tomorrow.minTemp}°C - ${tomorrow.maxTemp}°C)\n`;
    message += `   ${tomorrow.condition}\n`;
    if (tomorrow.rainProbability > 30) {
      message += `   🌧️ Rain chance: ${tomorrow.rainProbability}%\n`;
    }
  }

  return message;
}

/**
 * Gets appropriate emoji for weather condition
 */
function getWeatherEmoji(icon) {
  const emojiMap = {
    'clear': '☀️',
    'clouds': '☁️',
    'rain': '🌧️',
    'drizzle': '🌦️',
    'thunderstorm': '⛈️',
    'snow': '❄️',
    'mist': '🌫️',
    'fog': '🌫️',
    'haze': '🌫️',
  };
  
  for (const [key, emoji] of Object.entries(emojiMap)) {
    if (icon.includes(key)) return emoji;
  }
  return '🌡️';
}

/**
 * Creates alert message for severe weather
 */
function createAlertMessage(weather) {
  const alerts = [];
  
  if (weather.temperature > 35) {
    alerts.push('🔥 High Temperature Alert');
  }
  if (weather.temperature < 5) {
    alerts.push('❄️ Low Temperature Alert');
  }
  if (weather.windSpeed > 15) {
    alerts.push('💨 High Wind Alert');
  }
  if (weather.icon.includes('rain') || weather.icon.includes('thunderstorm')) {
    alerts.push('🌧️ Precipitation Alert');
  }
  
  return alerts.join(' | ');
}

/**
 * Logs notification to Firestore
 */
async function logNotificationToFirestore(weather, topic, messageId) {
  try {
    await admin.firestore().collection('weather_forecasts').add({
      topic: topic,
      temperature: weather.temperature,
      condition: weather.condition,
      location: weather.location,
      humidity: weather.humidity,
      windSpeed: weather.windSpeed,
      isAlert: shouldAlert(weather),
      messageId: messageId,
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: weather.timestamp,
    });
    console.log('✅ Logged to Firestore');
  } catch (error) {
    console.error('❌ Firestore log error:', error.message);
  }
}

/**
 * MAIN FUNCTION: Scheduled Weather Forecast Sender
 * 
 * Sends PERSONALIZED weather updates to each user based on their location
 * Includes both current weather AND tomorrow's forecast
 * 
 * Runs every 30 minutes and sends weather to all users with FCM tokens
 * 
 * IMPORTANT: Change schedule to match your needs:
 * - 'every 30 minutes' = 48 calls/day per user (recommended)
 * - 'every 1 hours' = 24 calls/day per user (production)
 * - '0 6,12,18 * * *' = 3 times daily at 6am, 12pm, 6pm (best for battery)
 * 
 * Deployed to: asia-south1 (Mumbai, India) for lower latency
 */
exports.scheduledWeatherForecast = functions
  .region('asia-south1') // Deploy to Mumbai, India region
  .pubsub
  .schedule('every 30 minutes') // Changed to 30 min for API efficiency
  .timeZone('Asia/Kolkata') // Change to your timezone
  .onRun(async (context) => {
    console.log('🌤️ Starting personalized weather forecast...');
    
    try {
      // Get all users with FCM tokens
      const users = await getUsersWithLocations();
      
      if (users.length === 0) {
        console.log('⚠️ No users found with FCM tokens');
        return null;
      }

      console.log(`� Sending forecasts to ${users.length} users...`);
      
      const notifications = [];
      let successCount = 0;
      let errorCount = 0;

      // Send personalized forecast to each user
      for (const user of users) {
        try {
          // Get user's location (use default if not set)
          const lat = user.location?.latitude || DEFAULT_LOCATION.lat;
          const lon = user.location?.longitude || DEFAULT_LOCATION.lon;
          const locationName = user.location?.name || user.location?.city || DEFAULT_LOCATION.name;

          // Fetch current weather
          const current = await fetchWeatherData(lat, lon);
          
          // Fetch tomorrow's forecast
          const tomorrow = await fetchTomorrowForecast(lat, lon);
          
          // Create personalized message
          const body = createPersonalizedWeatherMessage(current, tomorrow, locationName);
          
          // Determine if there's an alert
          const isAlert = shouldAlert(current);
          const title = isAlert 
            ? `⚠️ Weather Alert - ${locationName}`
            : `🌤️ Weather Update - ${locationName}`;

          // Build FCM message for this user
          const message = {
            token: user.token,
            notification: {
              title: title,
              body: body,
            },
            data: {
              userId: user.userId,
              currentTemp: current.temperature.toString(),
              currentCondition: current.condition,
              tomorrowTemp: tomorrow ? tomorrow.temperature.toString() : 'N/A',
              tomorrowCondition: tomorrow ? tomorrow.condition : 'N/A',
              rainChance: tomorrow ? tomorrow.rainProbability.toString() : '0',
              location: locationName,
              isAlert: isAlert.toString(),
              timestamp: new Date().toISOString(),
              type: 'personalized_forecast',
            },
            android: {
              priority: isAlert ? 'high' : 'normal',
              notification: {
                sound: isAlert ? 'default' : 'default',
                channelId: isAlert ? 'weather_alerts' : 'weather_forecast',
              }
            },
            apns: {
              payload: {
                aps: {
                  sound: isAlert ? 'default' : 'default',
                  badge: 1,
                }
              }
            }
          };

          notifications.push(message);
          
          // Log to Firestore for this user
          await admin.firestore().collection('weather_forecasts').add({
            userId: user.userId,
            userName: user.name,
            location: locationName,
            currentTemp: current.temperature,
            currentCondition: current.condition,
            tomorrowTemp: tomorrow ? tomorrow.temperature : null,
            tomorrowCondition: tomorrow ? tomorrow.condition : null,
            rainProbability: tomorrow ? tomorrow.rainProbability : 0,
            isAlert: isAlert,
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          successCount++;
          
        } catch (userError) {
          console.error(`❌ Error for user ${user.userId}:`, userError.message);
          errorCount++;
        }
      }

      // Send all notifications in batch
      if (notifications.length > 0) {
        console.log(`📤 Sending ${notifications.length} notifications...`);
        const batchResponse = await admin.messaging().sendEach(notifications);
        
        console.log(`✅ Successfully sent: ${batchResponse.successCount}/${notifications.length}`);
        if (batchResponse.failureCount > 0) {
          console.log(`❌ Failed: ${batchResponse.failureCount}`);
          batchResponse.responses.forEach((resp, idx) => {
            if (!resp.success) {
              console.error(`  - User ${users[idx].userId}: ${resp.error.message}`);
            }
          });
        }
      }

      return {
        success: true,
        totalUsers: users.length,
        sent: successCount,
        errors: errorCount,
        timestamp: new Date().toISOString(),
      };
      
    } catch (error) {
      console.error('❌ Scheduled forecast error:', error);
      throw error;
    }
  });

/**
 * MANUAL TRIGGER: Send Personalized Weather Forecasts (for testing)
 * 
 * Call this function manually to test personalized forecasts
 * 
 * Usage via HTTP:
 * curl https://asia-south1-terafarmsih.cloudfunctions.net/sendManualWeatherForecast
 * 
 * Optional query parameters:
 * ?userId=USER_ID - Send to specific user only
 * 
 * Deployed to: asia-south1 (Mumbai, India) for lower latency
 */
exports.sendManualWeatherForecast = functions
  .region('asia-south1') // Deploy to Mumbai, India region
  .https.onRequest(async (req, res) => {
  console.log('🧪 Manual personalized forecast triggered');
  
  try {
    const targetUserId = req.query.userId; // Optional: test specific user
    
    // Get users
    let users = await getUsersWithLocations();
    
    if (targetUserId) {
      users = users.filter(u => u.userId === targetUserId);
      console.log(`🎯 Testing for specific user: ${targetUserId}`);
    }
    
    if (users.length === 0) {
      return res.status(404).json({ 
        error: 'No users found',
        hint: 'Make sure users collection has documents with fcmToken field'
      });
    }

    const results = [];
    
    for (const user of users) {
      try {
        // Get location
        const lat = user.location?.latitude || DEFAULT_LOCATION.lat;
        const lon = user.location?.longitude || DEFAULT_LOCATION.lon;
        const locationName = user.location?.name || DEFAULT_LOCATION.name;

        // Fetch weather
        const current = await fetchWeatherData(lat, lon);
        const tomorrow = await fetchTomorrowForecast(lat, lon);
        
        const body = createPersonalizedWeatherMessage(current, tomorrow, locationName);
        const isAlert = shouldAlert(current);
        
        const message = {
          token: user.token,
          notification: {
            title: isAlert ? `⚠️ Weather Alert - ${locationName}` : `🌤️ Weather - ${locationName}`,
            body: body,
          },
          data: {
            userId: user.userId,
            currentTemp: current.temperature.toString(),
            tomorrowTemp: tomorrow ? tomorrow.temperature.toString() : 'N/A',
            location: locationName,
          },
        };
        
        const response = await admin.messaging().send(message);
        
        results.push({
          userId: user.userId,
          userName: user.name,
          location: locationName,
          messageId: response,
          currentWeather: `${current.temperature}°C, ${current.condition}`,
          tomorrowWeather: tomorrow ? `${tomorrow.temperature}°C, ${tomorrow.condition}` : 'N/A',
        });
        
      } catch (userError) {
        results.push({
          userId: user.userId,
          error: userError.message,
        });
      }
    }
    
    res.status(200).json({
      success: true,
      totalUsers: users.length,
      results: results,
      timestamp: new Date().toISOString(),
    });
    
  } catch (error) {
    console.error('❌ Manual forecast error:', error);
    res.status(500).json({ error: error.message });
  }
});

console.log('✅ TeraFarm Functions loaded successfully (including personalized weather notifications)');

/**
 * HTTP Function: Add test FCM tokens to all existing users  
 */
exports.addTestFCMTokens = functions
  .region('asia-south1')
  .https.onRequest(async (req, res) => {
    try {
      const usersSnapshot = await admin.firestore().collection('users').get();
      let updated = 0, skipped = 0;
      const results = [];
      for (const doc of usersSnapshot.docs) {
        const userData = doc.data();
        if (userData.fcmToken) { skipped++; continue; }
        const testToken = `cTEST_${doc.id}_${Date.now()}`; 
        await admin.firestore().collection('users').doc(doc.id).update({
          fcmToken: testToken,
          fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          weatherNotificationsEnabled: true,
        });
        updated++;
        results.push({ userId: doc.id, email: userData.email || 'N/A' });
      }
      res.json({ success: true, updated, skipped, total: usersSnapshot.size, results });
    } catch (error) {
      res.status(500).json({ error: error.message });
    }
  });
