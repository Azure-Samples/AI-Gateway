curl -X POST "https://apim-nrzp5vaasb57o.azure-api.net/openai/deployments/gpt-4o-mini/chat/completions?api-version=2024-02-01" \
  -H "Content-Type: application/json" \
  -H "api-key: c866b266032040a499e77433094caaa5" \
  -d '{"messages": [ 
        {"role": "system", "content": "You are a helpful assistant."}, 
        {"role": "user", "content": "What are 3 things to visit in Seattle?"} 
      ]}'