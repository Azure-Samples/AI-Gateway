# PowerShell conversion of OpenAI API test

# Configuration parameters
$runs = 20
$sleepTimeMs = 100
$frontdoorEndpoint = "afd-kj24hxjjth5ho-hhgef4apefc5cvc5.b01.azurefd.net"  # Replace with your actual value or parameterize
$openaiDeploymentName = "gpt-4o-mini"  # Replace with your actual value or parameterize
$openaiApiVersion = "2024-02-01"  # Replace with your actual value or parameterize
$apimSubscriptionKey = "your-subscription-key"  # Replace with your actual value or parameterize

# Build the URL
$url = "https://$frontdoorEndpoint/openai/deployments/$openaiDeploymentName/chat/completions?api-version=$openaiApiVersion"
# Alternative URL using APIM directly
# $url = "$apimResourceGatewayURL/openai/deployments/$openaiDeploymentName/chat/completions?api-version=$openaiApiVersion"

# Define the payload
$messages = @{
    messages = @(
        @{
            role = "system"
            content = "You are a sarcastic, unhelpful assistant."
        },
        @{
            role = "user"
            content = "Can you tell me the time, please?"
        }
    )
}

# Convert messages to JSON
$body = $messages | ConvertTo-Json -Depth 10

# Headers for the request
$headers = @{
    'api-key' = $apimSubscriptionKey
    'Content-Type' = 'application/json'
}

# Collection to store run information
$apiRuns = @()

# Run the tests
for ($i = 0; $i -lt $runs; $i++) {
    Write-Host "▶️ Run $(($i+1))/$($runs):"
    
    # Measure request time
    $startTime = Get-Date
    
    try {
        # Make the request
        $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorVariable responseError
        
        # Calculate response time
        $responseTime = (Get-Date) - $startTime
        $responseTimeSeconds = $responseTime.TotalSeconds
        Write-Host "⌚ $($responseTimeSeconds.ToString("0.00")) seconds"
        
        # Get response headers using the -ResponseHeadersVariable parameter
        $responseHeaders = $response.Headers
        
        # Check for region header - note this works differently in PowerShell
        # To properly capture headers, you need to use Invoke-WebRequest instead
        $webRequest = Invoke-WebRequest -Uri $url -Method Post -Headers $headers -Body $body
        
        if ($webRequest.Headers["x-ms-region"]) {
            $region = $webRequest.Headers["x-ms-region"]
            Write-Host "x-ms-region: $region" -ForegroundColor Green
            $apiRuns += @{ResponseTime=$responseTimeSeconds; Region=$region}
        }
        
        # Display token usage
        $usage = $response.usage | ConvertTo-Json -Depth 4
        Write-Host "Token usage: $usage`n"
        
        # Display message content
        $content = $response.choices[0].message.content
        Write-Host "💬 $content`n"
    }
    catch {
        # Handle error
        Write-Host "Status code: $($_.Exception.Response.StatusCode.value__)" -ForegroundColor Red
        Write-Host "$($responseError.Message)`n"
    }
    
    # Sleep between requests
    Start-Sleep -Milliseconds $sleepTimeMs
}

# Display summary (optional)
Write-Host "API Runs Summary:" -ForegroundColor Cyan
$apiRuns | Format-Table -AutoSize
